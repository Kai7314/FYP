import 'package:supabase_flutter/supabase_flutter.dart';

class CheckinService {
  final supabase = Supabase.instance.client;

  Future<void> addCheckin() async {
    final user = supabase.auth.currentUser;

    await supabase.from('checkins').insert({
      'user_id': user!.id,
      'checkin_time': DateTime.now().toIso8601String(),
      'status': 'active',
    });
  }
}
