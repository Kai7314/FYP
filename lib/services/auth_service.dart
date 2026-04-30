import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final supabase = Supabase.instance.client;

  Future<void> handleUserProfile() async {
    final user = supabase.auth.currentUser;

    if (user == null) return;

    final existing = await supabase.from('users').select().eq('id', user.id);

    if (existing.isEmpty) {
      await supabase.from('users').insert({'id': user.id, 'name': user.email});
    }
  }
}
