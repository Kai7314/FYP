import 'package:supabase_flutter/supabase_flutter.dart';

class RewardService {
  final supabase = Supabase.instance.client;

  Future<void> checkReward() async {
    final user = supabase.auth.currentUser;

    final data = await supabase
        .from('checkins')
        .select()
        .eq('user_id', user!.id);

    int streak = data.length;

    if (streak >= 7) {
      await supabase.from('rewards').insert({
        'user_id': user.id,
        'streak_days': streak,
        'reward_type': 'Milo',
      });
    }
  }
}
