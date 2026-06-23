import 'package:supabase_flutter/supabase_flutter.dart';

class ContactRepository {
  ContactRepository({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  static const maxContacts = 5;
  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> getContacts(String userId) async {
    final rows = await client
        .from('contacts')
        .select()
        .eq('user_id', userId)
        .order('name', ascending: true);
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
    final rows = await client
        .from('contacts')
        .select('name,phone')
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> addContact({
    required String userId,
    required String name,
    required String relationship,
    required String phone,
    String? address,
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

    final payload = {
      'user_id': userId,
      'name': name,
      'relationship': relationship,
      'phone': phone,
    };
    try {
      await client.from('contacts').insert({
        ...payload,
        if (address != null && address.isNotEmpty) 'address': address,
      });
    } on PostgrestException catch (error) {
      if (!error.message.toLowerCase().contains('address')) rethrow;
      await client.from('contacts').insert(payload);
    }
  }

  Future<void> deleteContact(Map<String, dynamic> row) async {
    final id = row['id'] ?? row['contact_id'];
    if (id == null) throw StateError('Contact identifier is missing.');
    final idColumn = row.containsKey('id') ? 'id' : 'contact_id';
    await client.from('contacts').delete().eq(idColumn, id);
  }

  String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');
}
