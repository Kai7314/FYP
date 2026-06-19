import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final supabase = Supabase.instance.client;

  Future<void> handleUserProfile() async {
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      final rows = await supabase
          .from('users')
          .select('id')
          .eq('id', user.id)
          .limit(1);
      if (rows.isEmpty) {
        await supabase.from('users').insert({
          'id': user.id,
          'name':
              user.userMetadata?['full_name']?.toString().trim().isNotEmpty ==
                  true
              ? user.userMetadata!['full_name'].toString()
              : (user.email?.split('@').first ?? 'EthernaCare User'),
        });
      }
    } catch (_) {
      // Authentication should still succeed even if the optional profile row
      // cannot be created because of database policy/schema setup.
    }
  }
}
