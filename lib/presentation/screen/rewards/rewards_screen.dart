import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/colors.dart';
import '../../../services/reward_service.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  Future<_RewardStats> _loadStats() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const _RewardStats(streak: 0, totalCheckins: 0, earnedTypes: {});
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
      streak: RewardService.calculateStreak(times),
      totalCheckins: times.length,
      earnedTypes: rewards
          .map((row) => row['reward_type']?.toString())
          .whereType<String>()
          .toSet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_RewardStats>(
      future: _loadStats(),
      builder: (context, snapshot) {
        final stats =
            snapshot.data ??
            const _RewardStats(streak: 0, totalCheckins: 0, earnedTypes: {});
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            const Text(
              'Rewards',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Check in daily to earn free gifts from sponsors',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            if (snapshot.hasError) ...[
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Unable to load reward progress. Please try again later.',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Streak',
                    value: '${stats.streak}',
                    icon: Icons.local_fire_department_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    label: 'Check-Ins',
                    value: '${stats.totalCheckins}',
                    icon: Icons.star_outline,
                    color: AppColors.purple,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricCard(
                    label: 'Gifts',
                    value: '${stats.earnedTypes.length}',
                    icon: Icons.card_giftcard,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: .25),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎁 How Rewards Work',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'Maintain your daily check-in streak to unlock free sponsored products. Each milestone rewards you with a real gift delivered to your home.',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(Icons.adjust_outlined, size: 16, color: AppColors.muted),
                SizedBox(width: 7),
                Text(
                  'SPONSORED REWARDS',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            _RewardCard(
              title: 'Milo Chocolate Drink',
              sponsor: 'Nestlé',
              description: '1x Milo 400g tin — energy-boosting chocolate malt',
              milestone: 7,
              streak: stats.streak,
              earned: stats.earnedTypes.contains('Milo Chocolate Drink'),
              icon: Icons.local_drink_outlined,
            ),
            _RewardCard(
              title: 'Premium Tissue Bundle',
              sponsor: 'Kleenex',
              description:
                  '3x premium soft tissue boxes — home essentials pack',
              milestone: 14,
              streak: stats.streak,
              earned: stats.earnedTypes.contains('Premium Tissue Bundle'),
              icon: Icons.inventory_2_outlined,
            ),
            _RewardCard(
              title: 'Green Tea Collection',
              sponsor: 'TWG Tea',
              description: 'A calming premium tea collection',
              milestone: 30,
              streak: stats.streak,
              earned: stats.earnedTypes.contains('Green Tea Collection'),
              icon: Icons.emoji_food_beverage_outlined,
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
    required this.earnedTypes,
  });

  final int streak;
  final int totalCheckins;
  final Set<String> earnedTypes;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 102,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .25),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.title,
    required this.sponsor,
    required this.description,
    required this.milestone,
    required this.streak,
    required this.earned,
    required this.icon,
  });

  final String title;
  final String sponsor;
  final String description;
  final int milestone;
  final int streak;
  final bool earned;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final progress = (streak.clamp(0, milestone) / milestone).toDouble();
    final remaining = milestone - streak.clamp(0, milestone);
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.muted, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            earned ? 'Earned' : '🔒 $remaining left',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'by $sponsor • $milestone-day streak',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 9),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(6),
                      color: AppColors.purple,
                      backgroundColor: AppColors.surface,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
