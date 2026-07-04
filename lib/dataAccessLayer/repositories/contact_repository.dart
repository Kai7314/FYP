import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/contact_model.dart';

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

  Future<List<ContactModel>> getContactModels(String userId) async {
    final rows = await getContacts(userId);
    return rows.map(ContactModel.fromJson).toList();
  }

  Future<bool> hasAnyContact(String userId) async {
    final rows = await client
        .from('contacts')
        .select('user_id')
        .eq('user_id', userId)
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<bool> hasPrimaryContact(String userId) async {
    try {
      final rows = await client
          .from('contacts')
          .select('user_id')
          .eq('user_id', userId)
          .eq('is_primary', true)
          .limit(1);
      return rows.isNotEmpty;
    } on PostgrestException catch (error) {
      if (error.message.toLowerCase().contains('is_primary')) {
        return hasAnyContact(userId);
      }
      rethrow;
    }
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

  Future<Map<String, dynamic>?> getPrimaryContact(String userId) async {
    try {
      final rows = await client
          .from('contacts')
          .select('name,phone,is_primary')
          .eq('user_id', userId)
          .eq('is_primary', true)
          .limit(1);
      if (rows.isNotEmpty) return Map<String, dynamic>.from(rows.first);
    } on PostgrestException catch (error) {
      if (!error.message.toLowerCase().contains('is_primary')) rethrow;
    }

    final rows = await client
        .from('contacts')
        .select('name,phone')
        .eq('user_id', userId)
        .order('name', ascending: true)
        .limit(1);
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  Future<void> addContact({
    required String userId,
    required String name,
    required String relationship,
    required String phone,
    String? address,
    String? addressState,
    String? addressRegion,
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
    final insertAsPrimary = existing.isEmpty;
    final cleanAddress = address?.trim() ?? '';
    final cleanAddressState = addressState?.trim() ?? '';
    final cleanAddressRegion = addressRegion?.trim() ?? '';

    if (cleanAddress.isEmpty) {
      throw StateError('Contact address is required.');
    }
    if (cleanAddress.length > 200) {
      throw StateError('Contact address must not exceed 200 characters.');
    }

    final payload = <String, dynamic>{
      'user_id': userId,
      'name': name,
      'relationship': relationship,
      'phone': phone,
      'address': cleanAddress,
      'is_primary': insertAsPrimary,
    };
    if (cleanAddressState.isNotEmpty) {
      payload['address_state'] = cleanAddressState;
    }
    if (cleanAddressRegion.isNotEmpty) {
      payload['address_region'] = cleanAddressRegion;
    }

    Map<String, dynamic> inserted;
    try {
      inserted = await _insertWithColumnFallback(payload, {
        'address_state',
        'address_region',
        'is_primary',
      });
    } on PostgrestException catch (error) {
      if (_isPrimaryConflict(error) &&
          shouldBePrimary &&
          await _phoneBelongsToPrimaryContact(userId: userId, phone: phone)) {
        return;
      }
      rethrow;
    }

    if (shouldBePrimary && existing.isNotEmpty) {
      try {
        await setPrimaryContact(userId: userId, row: inserted);
      } on Object {
        try {
          if (await _phoneBelongsToPrimaryContact(
            userId: userId,
            phone: phone,
          )) {
            return;
          }
        } catch (_) {}
        // The contact was inserted successfully. Do not surface a false add
        // failure just because primary promotion lagged or hit an RLS/schema
        // edge case; the user can retry Set Primary from the contact list.
      }
    }
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
        await _ensurePrimaryContactBestEffort(userId);
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
        await _ensurePrimaryContactBestEffort(userId);
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
        await _ensurePrimaryContactBestEffort(userId);
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
    if (id != null &&
        _looksLikeUuid(id.toString()) &&
        await _trySetPrimaryWithRpc(id)) {
      return;
    }

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
      if (_isPrimaryConflict(error) &&
          await _rowIsPrimaryContact(userId: userId, row: row)) {
        return;
      }
      if (error.message.toLowerCase().contains('is_primary')) {
        throw StateError(
          'Supabase contacts table is missing is_primary. Run supabase/quick_fix_contacts_columns.sql.',
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _insertWithColumnFallback(
    Map<String, dynamic> payload,
    Set<String> optionalColumns,
  ) async {
    final compatiblePayload = {...payload};
    while (true) {
      try {
        await client.from('contacts').insert(compatiblePayload);
        final userId = compatiblePayload['user_id']?.toString();
        final phone = compatiblePayload['phone']?.toString();
        if (userId != null && phone != null) {
          final inserted = await _findContactByPhone(
            userId: userId,
            phone: phone,
          );
          if (inserted != null) return inserted;
        }
        return Map<String, dynamic>.from(compatiblePayload);
      } on PostgrestException catch (error) {
        String? missingColumn;
        if (_isMissingColumnError(error)) {
          for (final column in optionalColumns) {
            if (compatiblePayload.containsKey(column) &&
                _errorMentionsColumn(error, column)) {
              missingColumn = column;
              break;
            }
          }
        }
        if (missingColumn == null) rethrow;
        compatiblePayload.remove(missingColumn);
      }
    }
  }

  Future<bool> _trySetPrimaryWithRpc(Object id) async {
    try {
      await client.rpc('set_primary_contact', params: {'p_contact_id': id});
      return true;
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (error.code == 'PGRST202' ||
          error.code == '42883' ||
          message.contains('set_primary_contact') ||
          message.contains('function')) {
        return false;
      }
      rethrow;
    }
  }

  Future<bool> _deleteByColumn({
    required String userId,
    required String column,
    required Object value,
  }) async {
    try {
      final existed = await _existsByColumn(
        userId: userId,
        column: column,
        value: value,
      );
      if (!existed) return false;

      await client
          .from('contacts')
          .delete()
          .eq('user_id', userId)
          .eq(column, value);

      final stillExists = await _existsByColumn(
        userId: userId,
        column: column,
        value: value,
      );
      return !stillExists;
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
      final existed = await _existsByNameAndPhone(
        userId: userId,
        name: name,
        phone: phone,
      );
      if (!existed) return false;

      await client
          .from('contacts')
          .delete()
          .eq('user_id', userId)
          .eq('name', name)
          .eq('phone', phone);

      final stillExists = await _existsByNameAndPhone(
        userId: userId,
        name: name,
        phone: phone,
      );
      return !stillExists;
    } on PostgrestException catch (error) {
      _throwHelpfulDeleteError(error);
    }
  }

  Future<bool> _existsByColumn({
    required String userId,
    required String column,
    required Object value,
  }) async {
    final rows = await client
        .from('contacts')
        .select('user_id')
        .eq('user_id', userId)
        .eq(column, value)
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<bool> _existsByNameAndPhone({
    required String userId,
    required String name,
    required String phone,
  }) async {
    final rows = await client
        .from('contacts')
        .select('user_id')
        .eq('user_id', userId)
        .eq('name', name)
        .eq('phone', phone)
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<void> _ensurePrimaryContactBestEffort(String userId) async {
    try {
      await _ensurePrimaryContact(userId);
    } catch (_) {
      // Deletion already succeeded. A future add/set-primary action can repair
      // primary status if the optional primary-contact columns/RPC lag behind.
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

  Future<bool> _phoneBelongsToPrimaryContact({
    required String userId,
    required String phone,
  }) async {
    final contact = await _findContactByPhone(userId: userId, phone: phone);
    return contact?['is_primary'] == true;
  }

  Future<bool> _rowIsPrimaryContact({
    required String userId,
    required Map<String, dynamic> row,
  }) async {
    final id = row['id'] ?? row['contact_id'];
    if (id != null) {
      final rows = await client
          .from('contacts')
          .select('is_primary')
          .eq('user_id', userId)
          .eq(row.containsKey('id') ? 'id' : 'contact_id', id)
          .limit(1);
      return rows.isNotEmpty && rows.first['is_primary'] == true;
    }

    final phone = row['phone']?.toString();
    if (phone == null || phone.trim().isEmpty) return false;
    return _phoneBelongsToPrimaryContact(userId: userId, phone: phone);
  }

  Future<Map<String, dynamic>?> _findContactByPhone({
    required String userId,
    required String phone,
  }) async {
    final normalizedPhone = _digits(phone);
    final rows = await client.from('contacts').select().eq('user_id', userId);
    for (final row in rows) {
      final contact = Map<String, dynamic>.from(row);
      if (_digits(contact['phone']?.toString() ?? '') == normalizedPhone) {
        return contact;
      }
    }
    return null;
  }

  bool _isPrimaryConflict(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == '23505' &&
        (message.contains('contacts_one_primary_per_user') ||
            message.contains('is_primary') ||
            message.contains('duplicate key'));
  }

  bool _isMissingColumnError(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == 'PGRST204' ||
        (message.contains('could not find') &&
            (message.contains('schema cache') || message.contains('column')));
  }

  bool _errorMentionsColumn(PostgrestException error, String column) {
    final text =
        '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
            .toLowerCase();
    final escaped = RegExp.escape(column.toLowerCase());
    return RegExp("['\"]$escaped['\"]").hasMatch(text) ||
        RegExp('(?:^|[^a-z0-9_])$escaped(?:[^a-z0-9_]|\\z)').hasMatch(text);
  }

  bool _looksLikeUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');
}
