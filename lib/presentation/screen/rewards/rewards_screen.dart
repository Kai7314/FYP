import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/colors.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  Future<_RewardStats> _loadStats() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const _RewardStats(streak: 0, totalCheckins: 0, earnedGifts: 0);
    }

    final checkins = await Supabase.instance.client
        .from('checkins')
        .select()
        .eq('user_id', user.id)
        .order('checkin_time', ascending: false);

    final rewards = await Supabase.instance.client
        .from('rewards')
        .select()
        .eq('user_id', user.id);

    final times = checkins
        .map<DateTime?>(
          (row) => DateTime.tryParse(row['checkin_time'].toString()),
        )
        .whereType<DateTime>()
        .toList();

    return _RewardStats(
      streak: _calculateStreak(times),
      totalCheckins: times.length,
      earnedGifts: rewards.length,
    );
  }

  int _calculateStreak(List<DateTime> times) {
    final days =
        times
            .map((date) => DateTime(date.year, date.month, date.day))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    if (days.isEmpty) return 0;

    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    var count = 0;

    for (final day in days) {
      if (day == cursor) {
        count++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else if (count == 0 &&
          day == cursor.subtract(const Duration(days: 1))) {
        count++;
        cursor = day.subtract(const Duration(days: 1));
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_RewardStats>(
      future: _loadStats(),
      builder: (context, snapshot) {
        final stats =
            snapshot.data ??
            const _RewardStats(streak: 0, totalCheckins: 0, earnedGifts: 0);

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Rewards',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text('Daily safety habits become simple household gifts.'),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(label: 'Streak', value: '${stats.streak}'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    label: 'Check-ins',
                    value: '${stats.totalCheckins}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    label: 'Gifts',
                    value: '${stats.earnedGifts}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'How rewards work: keep petting the cat daily. Each milestone unlocks a sponsored household item.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            _RewardCard(
              title: 'Milo',
              milestone: 7,
              streak: stats.streak,
              icon: Icons.local_drink,
            ),
            const SizedBox(height: 10),
            _RewardCard(
              title: 'Tissues',
              milestone: 14,
              streak: stats.streak,
              icon: Icons.inventory_2,
            ),
            const SizedBox(height: 10),
            _RewardCard(
              title: 'Green Tea',
              milestone: 30,
              streak: stats.streak,
              icon: Icons.emoji_food_beverage,
            ),
          ],
        );
      },
    );
  }
}

class _RewardStats {
  const _RewardStats({
    required this.streak,
    required this.totalCheckins,
    required this.earnedGifts,
  });

  final int streak;
  final int totalCheckins;
  final int earnedGifts;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.title,
    required this.milestone,
    required this.streak,
    required this.icon,
  });

  final String title;
  final int milestone;
  final int streak;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final progress = (streak.clamp(0, milestone) / milestone).toDouble();
    final unlocked = streak >= milestone;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: unlocked
                  ? AppColors.primary
                  : const Color(0xFFFFF6DF),
              child: Icon(
                icon,
                color: unlocked ? Colors.white : AppColors.accent,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    unlocked
                        ? 'Unlocked'
                        : '${milestone - streak.clamp(0, milestone)} days remaining',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$milestone days',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
