import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../models/reward_model.dart';
import '../../../services/dashboard_service.dart';
import '../../../services/reward_service.dart';
import '../../widgets/premium_shell.dart';
import 'reward_collection_screen.dart';
import 'reward_detail_screen.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen>
    with WidgetsBindingObserver {
  final rewardService = RewardService();
  final dashboardService = DashboardService();

  RewardSnapshot? rewards;
  DashboardSnapshot? dashboard;
  bool refreshing = true;
  String? error;
  Timer? catalogRefreshDebounce;
  bool catalogRefreshRunning = false;
  final Set<String> claimingBadgeCodes = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    rewardService.startCatalogRealtime(_queueCatalogRefresh);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _queueCatalogRefresh();
    }
  }

  void _queueCatalogRefresh() {
    catalogRefreshDebounce?.cancel();
    catalogRefreshDebounce = Timer(
      const Duration(milliseconds: 350),
      _refreshCatalog,
    );
  }

  Future<void> _refreshCatalog() async {
    if (!mounted || catalogRefreshRunning) return;
    catalogRefreshRunning = true;
    try {
      final fresh = await rewardService.synchronize(forceCatalogRefresh: true);
      if (!mounted) return;
      setState(() {
        rewards = fresh;
        error = null;
      });
    } finally {
      catalogRefreshRunning = false;
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => refreshing = true);
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
        setState(() => error = 'Showing your saved virtual collection.');
      }
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  Future<void> _openReward(
    RewardCatalogItem item,
    RewardSnapshot snapshot,
  ) async {
    if (item.isVoucher || snapshot.isBadgeClaimed(item.code)) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RewardDetailScreen(
            reward: item,
            redemptionCode: snapshot.redemptionCodeFor(item.code),
          ),
        ),
      );
      return;
    }

    if (claimingBadgeCodes.contains(item.code)) return;
    setState(() => claimingBadgeCodes.add(item.code));
    try {
      final fresh = await rewardService.claimBadge(item.code);
      if (!mounted) return;
      setState(() {
        rewards = fresh;
        error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.title} was added to Reward Collection.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not collect this badge. Refresh your rewards and try again.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => claimingBadgeCodes.remove(item.code));
      }
    }
  }

  Future<void> _openCollection(RewardSnapshot snapshot) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RewardCollectionScreen(snapshot: snapshot),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    catalogRefreshDebounce?.cancel();
    unawaited(rewardService.stopCatalogRealtime());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot =
        rewards ??
        RewardSnapshot(
          catalog: RewardService.fallbackCatalog,
          earnedCodes: const {},
          catalogVersion: RewardService.fallbackCatalogVersion,
          syncedAt: DateTime.fromMillisecondsSinceEpoch(0),
        );
    final streak = dashboard?.streak ?? 0;
    final totalCheckins = dashboard?.totalCheckins ?? 0;
    final collectionItems = snapshot.collectionItems;
    final goalItems = snapshot.goalItems;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          PremiumHeader(
            title: 'Rewards',
            subtitle: 'Your virtual milestone collection',
            orenAsset:
                'lib/assets/images/pixel/oren_pixel_token_transparent.png',
            orenSemanticLabel: 'Oren holding a virtual reward token',
            action: _RewardCollectionButton(
              count: collectionItems.length,
              syncing: refreshing,
              onPressed: () => _openCollection(snapshot),
            ),
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
                  icon: Icons.check_circle_outline,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  label: 'Unlocked',
                  value: '${snapshot.earnedCodes.length}',
                  icon: Icons.workspace_premium_outlined,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GlassPanel(
            padding: const EdgeInsets.all(15),
            color: AppColors.primarySoft,
            borderColor: AppColors.primary.withValues(alpha: .24),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome_outlined, color: AppColors.primaryDark),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Virtual rewards unlock with your check-in streak. Collect an earned badge to move it into Reward Collection. Earned vouchers are stored there with a personal redeem code.',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Reward Goals', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (goalItems.isEmpty)
            const _AllRewardsCollected()
          else
            ...goalItems.map(
              (item) => _VirtualRewardCard(
                item: item,
                streak: streak,
                unlocked: snapshot.earnedCodes.contains(item.code),
                claimed: snapshot.isBadgeClaimed(item.code),
                claiming: claimingBadgeCodes.contains(item.code),
                onCheck: snapshot.earnedCodes.contains(item.code)
                    ? () => _openReward(item, snapshot)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _RewardCollectionButton extends StatelessWidget {
  const _RewardCollectionButton({
    required this.count,
    required this.syncing,
    required this.onPressed,
  });

  final int count;
  final bool syncing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton.filledTonal(
            tooltip: 'Reward Collection',
            onPressed: onPressed,
            icon: const Icon(Icons.inventory_2_outlined),
          ),
          if (syncing)
            const Positioned(
              left: -2,
              bottom: -2,
              child: SizedBox.square(
                dimension: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}

class _AllRewardsCollected extends StatelessWidget {
  const _AllRewardsCollected();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      color: AppColors.primarySoft,
      borderColor: AppColors.primary.withValues(alpha: .24),
      child: const Row(
        children: [
          Icon(Icons.verified_outlined, color: AppColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'All available rewards are in your Reward Collection.',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
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
    return GlassPanel(
      padding: EdgeInsets.zero,
      color: color,
      borderColor: Colors.white.withValues(alpha: .24),
      child: SizedBox(
        height: 102,
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
      ),
    );
  }
}

class _VirtualRewardCard extends StatelessWidget {
  const _VirtualRewardCard({
    required this.item,
    required this.streak,
    required this.unlocked,
    required this.claimed,
    required this.claiming,
    required this.onCheck,
  });

  final RewardCatalogItem item;
  final int streak;
  final bool unlocked;
  final bool claimed;
  final bool claiming;
  final VoidCallback? onCheck;

  @override
  Widget build(BuildContext context) {
    final completedDays = streak.clamp(0, item.milestoneDays);
    final progress = item.milestoneDays == 0
        ? 0.0
        : (completedDays / item.milestoneDays).toDouble();
    final remaining = item.milestoneDays - completedDays;
    final style = _badgeStyle(item);

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: GlassPanel(
        color: unlocked ? style.softColor : AppColors.glassStrong,
        borderColor: unlocked
            ? style.color.withValues(alpha: .38)
            : AppColors.border,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: unlocked ? style.color : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                style.icon,
                color: unlocked ? Colors.white : AppColors.muted,
                size: 32,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RewardStatusLabel(
                        label: !unlocked
                            ? 'Locked'
                            : item.isVoucher
                            ? 'Ready'
                            : claimed
                            ? 'Collected'
                            : 'Earned',
                        active: unlocked,
                        color: style.color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.milestoneDays}-day check-in streak',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.description,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: unlocked ? 1 : progress,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(6),
                    color: style.color,
                    backgroundColor: AppColors.surface,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        unlocked
                            ? Icons.check_circle_outline
                            : Icons.lock_clock_outlined,
                        size: 17,
                        color: unlocked ? style.color : AppColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          unlocked
                              ? item.isVoucher
                                    ? 'Your personal redeem code is ready'
                                    : claimed
                                    ? 'Stored in My Badge List'
                                    : 'Goal complete. Collect this badge to store it'
                              : '$remaining more consecutive ${remaining == 1 ? 'day' : 'days'} to unlock',
                          style: TextStyle(
                            color: unlocked ? style.color : AppColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (unlocked) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: item.isVoucher || claimed
                          ? OutlinedButton.icon(
                              onPressed: onCheck,
                              icon: Icon(
                                item.isVoucher
                                    ? Icons.confirmation_number_outlined
                                    : Icons.workspace_premium_outlined,
                              ),
                              label: Text(
                                item.isVoucher ? 'Check Reward' : 'View Badge',
                              ),
                            )
                          : FilledButton.icon(
                              onPressed: claiming ? null : onCheck,
                              icon: claiming
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.add_circle_outline),
                              label: Text(
                                claiming ? 'Collecting...' : 'Collect Badge',
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardStatusLabel extends StatelessWidget {
  const _RewardStatusLabel({
    required this.label,
    required this.active,
    required this.color,
  });

  final String label;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: active ? color : AppColors.muted,
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

_BadgeStyle _badgeStyle(RewardCatalogItem item) {
  if (item.isVoucher) {
    return const _BadgeStyle(
      icon: Icons.confirmation_number_outlined,
      color: AppColors.accent,
      softColor: AppColors.warningSoft,
    );
  }
  final code = item.code;
  final milestoneDays = item.milestoneDays;
  if (code.contains('sprout') || milestoneDays <= 3) {
    return const _BadgeStyle(
      icon: Icons.eco_outlined,
      color: AppColors.primary,
      softColor: AppColors.primarySoft,
    );
  }
  if (code.contains('companion') || milestoneDays <= 7) {
    return const _BadgeStyle(
      icon: Icons.favorite_outline,
      color: AppColors.pink,
      softColor: Color(0xFFFFECF2),
    );
  }
  if (code.contains('safety') || milestoneDays <= 10) {
    return const _BadgeStyle(
      icon: Icons.shield_outlined,
      color: AppColors.blue,
      softColor: AppColors.sky,
    );
  }
  if (code.contains('guardian') || milestoneDays <= 14) {
    return const _BadgeStyle(
      icon: Icons.auto_awesome_outlined,
      color: AppColors.purple,
      softColor: Color(0xFFF0EEFF),
    );
  }
  return const _BadgeStyle(
    icon: Icons.workspace_premium_outlined,
    color: AppColors.accent,
    softColor: AppColors.warningSoft,
  );
}

class _BadgeStyle {
  const _BadgeStyle({
    required this.icon,
    required this.color,
    required this.softColor,
  });

  final IconData icon;
  final Color color;
  final Color softColor;
}
