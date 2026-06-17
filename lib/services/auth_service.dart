import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final supabase = Supabase.instance.client;

  Future<void> handleUserProfile() async {
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      await supabase.from('users').upsert({
        'id': user.id,
        'name': user.email ?? 'EthernaCare User',
      });
    } catch (_) {
      // Authentication should still succeed even if the optional profile row
      // cannot be created because of database policy/schema setup.
    }
  }
}
