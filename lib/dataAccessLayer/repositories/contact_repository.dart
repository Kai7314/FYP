import 'package:supabase_flutter/supabase_flutter.dart';

class ContactRepository {
  ContactRepository({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  static const maxContacts = 5;
  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> getContacts(String userId) async {
    dynamic rows;
    try {
      rows = await client
          .from('contacts')
          .select()
          .eq('user_id', userId)
          .order('is_primary', ascending: false)
          .order('name', ascending: true);
    } on PostgrestException catch (error) {
      if (!error.message.toLowerCase().contains('is_primary')) rethrow;
      rows = await client
          .from('contacts')
          .select()
          .eq('user_id', userId)
          .order('name', ascending: true);
    }
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<bool> hasAnyContact(String userId) async {
    final rows = await client
        .from('contacts')
        .select('user_id')
        .eq('user_id', userId)
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getAlertRecipients(String userId) async {
    dynamic rows;
    try {
      rows = await client
          .from('contacts')
          .select('name,phone,is_primary')
          .eq('user_id', userId)
          .order('is_primary', ascending: false)
          .order('name', ascending: true);
    } on PostgrestException catch (error) {
      if (!error.message.toLowerCase().contains('is_primary')) rethrow;
      rows = await client
          .from('contacts')
          .select('name,phone')
          .eq('user_id', userId)
          .order('name', ascending: true);
    }
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> addContact({
    required String userId,
    required String name,
    required String relationship,
    required String phone,
    String? address,
    bool isPrimary = false,
  }) async {
    final existing = await client
        .from('contacts')
        .select('phone')
        .eq('user_id', userId);
    if (existing.length >= maxContacts) {
      throw StateError('You can add up to $maxContacts emergency contacts.');
    }

    final normalizedPhone = _digits(phone);
    final duplicate = existing.any(
      (row) => _digits(row['phone']?.toString() ?? '') == normalizedPhone,
    );
    if (duplicate) {
      throw StateError('This phone number is already an emergency contact.');
    }

    final shouldBePrimary = isPrimary || existing.isEmpty;
    if (shouldBePrimary && existing.isNotEmpty) {
      try {
        await client
            .from('contacts')
            .update({'is_primary': false})
            .eq('user_id', userId);
      } on PostgrestException catch (error) {
        if (!error.message.toLowerCase().contains('is_primary')) rethrow;
      }
    }

    final payload = <String, dynamic>{
      'user_id': userId,
      'name': name,
      'relationship': relationship,
      'phone': phone,
      'is_primary': shouldBePrimary,
    };
    if (address != null && address.isNotEmpty) payload['address'] = address;
    await _insertWithColumnFallback(payload, {'address', 'is_primary'});
  }

  Future<void> deleteContact({
    required String userId,
    required Map<String, dynamic> row,
  }) async {
    final id = row['id'] ?? row['contact_id'];
    if (id != null) {
      final idColumn = row.containsKey('id') ? 'id' : 'contact_id';
      if (await _deleteByColumn(
        userId: userId,
        column: idColumn,
        value: id,
      )) {
        await _ensurePrimaryContact(userId);
        return;
      }
    }

    final phone = row['phone']?.toString();
    if (phone != null && phone.trim().isNotEmpty) {
      if (await _deleteByColumn(
        userId: userId,
        column: 'phone',
        value: phone,
      )) {
        await _ensurePrimaryContact(userId);
        return;
      }
    }

    final name = row['name']?.toString();
    if (name != null && name.trim().isNotEmpty && phone != null) {
      if (await _deleteByNameAndPhone(
        userId: userId,
        name: name,
        phone: phone,
      )) {
        await _ensurePrimaryContact(userId);
        return;
      }
    }

    throw StateError(
      'Contact could not be deleted. Run supabase/quick_fix_contacts_delete_policy.sql, then retry.',
    );
  }

  Future<void> setPrimaryContact({
    required String userId,
    required Map<String, dynamic> row,
  }) async {
    final id = row['id'] ?? row['contact_id'];
    try {
      await client
          .from('contacts')
          .update({'is_primary': false})
          .eq('user_id', userId);

      var query = client
          .from('contacts')
          .update({'is_primary': true})
          .eq('user_id', userId);

      if (id != null) {
        final idColumn = row.containsKey('id') ? 'id' : 'contact_id';
        await query.eq(idColumn, id);
        return;
      }

      final phone = row['phone']?.toString();
      if (phone == null || phone.trim().isEmpty) {
        throw StateError('Contact identifier is missing.');
      }
      await query.eq('phone', phone);
    } on PostgrestException catch (error) {
      if (error.message.toLowerCase().contains('is_primary')) {
        throw StateError(
          'Supabase contacts table is missing is_primary. Run supabase/quick_fix_contacts_columns.sql.',
        );
      }
      rethrow;
    }
  }

  Future<void> _insertWithColumnFallback(
    Map<String, dynamic> payload,
    Set<String> optionalColumns,
  ) async {
    final compatiblePayload = {...payload};
    while (true) {
      try {
        await client.from('contacts').insert(compatiblePayload);
        return;
      } on PostgrestException catch (error) {
        final message = error.message.toLowerCase();
        String? missingColumn;
        for (final column in optionalColumns) {
          if (compatiblePayload.containsKey(column) &&
              message.contains(column.toLowerCase())) {
            missingColumn = column;
            break;
          }
        }
        if (missingColumn == null) rethrow;
        compatiblePayload.remove(missingColumn);
      }
    }
  }

  Future<bool> _deleteByColumn({
    required String userId,
    required String column,
    required Object value,
  }) async {
    try {
      final rows = await client
          .from('contacts')
          .delete()
          .eq('user_id', userId)
          .eq(column, value)
          .select('user_id');
      return rows.isNotEmpty;
    } on PostgrestException catch (error) {
      _throwHelpfulDeleteError(error);
    }
  }

  Future<bool> _deleteByNameAndPhone({
    required String userId,
    required String name,
    required String phone,
  }) async {
    try {
      final rows = await client
          .from('contacts')
          .delete()
          .eq('user_id', userId)
          .eq('name', name)
          .eq('phone', phone)
          .select('user_id');
      return rows.isNotEmpty;
    } on PostgrestException catch (error) {
      _throwHelpfulDeleteError(error);
    }
  }

  Future<void> _ensurePrimaryContact(String userId) async {
    try {
      final primary = await client
          .from('contacts')
          .select('user_id')
          .eq('user_id', userId)
          .eq('is_primary', true)
          .limit(1);
      if (primary.isNotEmpty) return;

      final remaining = await client
          .from('contacts')
          .select()
          .eq('user_id', userId)
          .order('name', ascending: true)
          .limit(1);
      if (remaining.isEmpty) return;
      await setPrimaryContact(
        userId: userId,
        row: Map<String, dynamic>.from(remaining.first),
      );
    } on PostgrestException catch (error) {
      if (!error.message.toLowerCase().contains('is_primary')) rethrow;
    }
  }

  Never _throwHelpfulDeleteError(PostgrestException error) {
    final message = error.message.toLowerCase();
    if (message.contains('permission') ||
        message.contains('policy') ||
        message.contains('row-level security') ||
        error.code == '42501') {
      throw StateError(
        'Supabase contacts delete policy is missing. Run supabase/quick_fix_contacts_delete_policy.sql.',
      );
    }
    throw error;
  }

  String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');
}
