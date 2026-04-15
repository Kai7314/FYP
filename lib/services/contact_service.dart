import 'package:supabase_flutter/supabase_flutter.dart';

class ContactService {
  final supabase = Supabase.instance.client;

  Future<void> addContact(String name, String phone) async {
    final user = supabase.auth.currentUser;

    await supabase.from('contacts').insert({
      'user_id': user!.id,
      'name': name,
      'phone': phone,
      'relationship': 'family',
    });
  }
}
