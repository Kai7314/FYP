import 'package:supabase_flutter/supabase_flutter.dart';

class CheckinService {
  final supabase = Supabase.instance.client;

  Future<bool> addCheckin() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to check in.');
    }

    final startOfDay = DateTime.now();
    final today = DateTime(startOfDay.year, startOfDay.month, startOfDay.day);
    final tomorrow = today.add(const Duration(days: 1));
    final existing = await supabase
        .from('checkins')
        .select('checkin_time')
        .eq('user_id', user.id)
        .gte('checkin_time', today.toUtc().toIso8601String())
        .lt('checkin_time', tomorrow.toUtc().toIso8601String())
        .limit(1);

    if (existing.isNotEmpty) return false;

    await supabase.from('checkins').insert({
      'user_id': user.id,
      'checkin_time': DateTime.now().toIso8601String(),
      'status': 'active',
    });
    return true;
  }
}
