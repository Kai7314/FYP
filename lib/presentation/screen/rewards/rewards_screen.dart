import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../models/reward_model.dart';
import '../../../services/dashboard_service.dart';
import '../../../services/reward_service.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final rewardService = RewardService();
  final dashboardService = DashboardService();

  RewardSnapshot? rewards;
  DashboardSnapshot? dashboard;
  bool refreshing = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = await Future.wait([
      rewardService.loadCached(),
      dashboardService.loadCached(),
    ]);
    if (!mounted) return;
    setState(() {
      rewards = cached[0] as RewardSnapshot?;
      dashboard = cached[1] as DashboardSnapshot?;
    });

    try {
      final fresh = await Future.wait([
        rewardService.synchronize(),
        dashboardService.refresh(),
      ]);
      if (!mounted) return;
      setState(() {
        rewards = fresh[0] as RewardSnapshot;
        dashboard = fresh[1] as DashboardSnapshot;
        error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Showing locally saved rewards.');
      }
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot =
        rewards ??
        RewardSnapshot(
          catalog: RewardService.fallbackCatalog,
          earnedCodes: const {},
          catalogVersion: 1,
          syncedAt: DateTime.fromMillisecondsSinceEpoch(0),
        );
    final streak = dashboard?.streak ?? 0;
    final totalCheckins = dashboard?.totalCheckins ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rewards',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Physical gifts and virtual vouchers',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (refreshing)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (error != null) ...[
            Text(error!, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Streak',
                  value: '$streak',
                  icon: Icons.local_fire_department_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  label: 'Check-Ins',
                  value: '$totalCheckins',
                  icon: Icons.star_outline,
                  color: AppColors.purple,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  label: 'Earned',
                  value: '${snapshot.earnedCodes.length}',
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
            child: Text(
              'Catalog version ${snapshot.catalogVersion}. Cached rewards open instantly; the server is checked for new items and earned status when online.',
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 18),
          ...snapshot.catalog.map(
            (item) => _RewardCard(
              item: item,
              streak: streak,
              earned: snapshot.earnedCodes.contains(item.code),
            ),
          ),
        ],
      ),
    );
  }
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
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
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
    required this.item,
    required this.streak,
    required this.earned,
  });

  final RewardCatalogItem item;
  final int streak;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final progress = (streak.clamp(0, item.milestoneDays) / item.milestoneDays)
        .toDouble();
    final remaining = item.milestoneDays - streak.clamp(0, item.milestoneDays);
    final voucher = item.rewardKind == 'voucher';

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
                  color: voucher
                      ? AppColors.warningSoft
                      : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  voucher
                      ? Icons.confirmation_number_outlined
                      : Icons.inventory_2_outlined,
                  color: voucher ? AppColors.accent : AppColors.primary,
                  size: 30,
                ),
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
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          earned ? 'Earned' : '$remaining left',
                          style: TextStyle(
                            color: earned ? AppColors.primary : AppColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${item.sponsor} - ${item.milestoneDays}-day streak',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.voucherValue == null
                          ? item.description
                          : '${item.description} Value: ${item.voucherValue}',
                      maxLines: 2,
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
                      color: voucher ? AppColors.accent : AppColors.primary,
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
