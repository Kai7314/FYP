import 'package:supabase_flutter/supabase_flutter.dart';

class RewardService {
  final supabase = Supabase.instance.client;

  static const milestones = <int, String>{
    7: 'Milo Chocolate Drink',
    14: 'Premium Tissue Bundle',
    30: 'Green Tea Collection',
  };

  Future<void> checkReward() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final checkins = await supabase
        .from('checkins')
        .select('checkin_time')
        .eq('user_id', user.id)
        .order('checkin_time', ascending: false);
    final streak = calculateStreak(
      checkins
          .map<DateTime?>(
            (row) => DateTime.tryParse(row['checkin_time'].toString()),
          )
          .whereType<DateTime>()
          .toList(),
    );

    final earnedRows = await supabase
        .from('rewards')
        .select('reward_type')
        .eq('user_id', user.id);
    final earnedTypes = earnedRows
        .map((row) => row['reward_type']?.toString())
        .whereType<String>()
        .toSet();

    for (final entry in milestones.entries) {
      if (streak >= entry.key && !earnedTypes.contains(entry.value)) {
        await supabase.from('rewards').insert({
          'user_id': user.id,
          'streak_days': entry.key,
          'reward_type': entry.value,
        });
      }
    }
  }

  static int calculateStreak(List<DateTime> times) {
    final days =
        times
            .map((date) => DateTime(date.year, date.month, date.day))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    if (days.isEmpty) return 0;

    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    var count = 0;
    for (final day in days) {
      if (day == cursor) {
        count++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else if (count == 0 &&
          day == cursor.subtract(const Duration(days: 1))) {
        count++;
        cursor = day.subtract(const Duration(days: 1));
      } else if (day.isBefore(cursor)) {
        break;
      }
    }
    return count;
  }
}
