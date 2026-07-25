import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../models/reward_model.dart';
import '../../../models/reward_request_model.dart';
import '../../../services/dashboard_service.dart';
import '../../../services/reward_request_service.dart';
import '../../../services/reward_service.dart';
import '../../widgets/premium_shell.dart';
import 'admin_reward_requests_screen.dart';
import 'reward_request_screen.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final rewardService = RewardService();
  final dashboardService = DashboardService();
  final requestService = RewardRequestService();

  RewardSnapshot? rewards;
  DashboardSnapshot? dashboard;
  List<RewardRequest> requests = const [];
  bool isAdmin = false;
  bool refreshing = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
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
        setState(() => error = 'Showing locally saved rewards.');
      }
    }

    try {
      final results = await Future.wait([
        requestService.getOwnRequests(),
        requestService.isCurrentUserAdmin(),
      ]);
      if (!mounted) return;
      setState(() {
        requests = results[0] as List<RewardRequest>;
        isAdmin = results[1] as bool;
      });
    } catch (_) {
      // The reward catalog remains usable while the fulfillment schema deploys.
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  Future<void> _requestReward(RewardCatalogItem item) async {
    final request = await Navigator.of(context).push<RewardRequest>(
      MaterialPageRoute(builder: (_) => RewardRequestScreen(item: item)),
    );
    if (request == null || !mounted) return;
    setState(() {
      requests = [
        request,
        ...requests.where((existing) => existing.id != request.id),
      ];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reward request submitted for admin review.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openAdminRequests() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const AdminRewardRequestsScreen()),
    );
    if (mounted) await _load();
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
    final requestByCode = {
      for (final request in requests) request.rewardCode: request,
    };

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          PremiumHeader(
            title: 'Rewards',
            subtitle: 'Physical gifts and virtual vouchers',
            orenAsset:
                'lib/assets/images/pixel/oren_pixel_token_transparent.png',
            orenSemanticLabel: 'Oren holding a reward token',
            action: isAdmin
                ? IconButton.filledTonal(
                    onPressed: _openAdminRequests,
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    tooltip: 'Open reward requests',
                  )
                : refreshing
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const PremiumStatusPill(
                    icon: Icons.offline_bolt_outlined,
                    label: 'Synced',
                    color: AppColors.primary,
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
          GlassPanel(
            padding: const EdgeInsets.all(15),
            color: AppColors.primarySoft,
            borderColor: AppColors.primary.withValues(alpha: .24),
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
              request: requestByCode[item.code],
              onRequest: () => _requestReward(item),
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
      child: Container(
        height: 102,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
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
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.item,
    required this.streak,
    required this.earned,
    required this.request,
    required this.onRequest,
  });

  final RewardCatalogItem item;
  final int streak;
  final bool earned;
  final RewardRequest? request;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final progress = (streak.clamp(0, item.milestoneDays) / item.milestoneDays)
        .toDouble();
    final remaining = item.milestoneDays - streak.clamp(0, item.milestoneDays);
    final voucher = item.rewardKind == 'voucher';

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: GlassPanel(
        color: earned ? AppColors.primarySoft : AppColors.glassStrong,
        borderColor: earned
            ? AppColors.primary.withValues(alpha: .34)
            : AppColors.border,
        padding: const EdgeInsets.all(13),
        child: Padding(
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: voucher
                      ? AppColors.warningSoft
                      : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
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
                    if (request != null) ...[
                      const SizedBox(height: 9),
                      _UserRequestStatus(request: request!),
                    ] else if (earned) ...[
                      const SizedBox(height: 9),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onRequest,
                          icon: Icon(
                            voucher
                                ? Icons.confirmation_number_outlined
                                : Icons.local_shipping_outlined,
                            size: 18,
                          ),
                          label: Text(
                            voucher ? 'Request Voucher' : 'Request Delivery',
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
      ),
    );
  }
}

class _UserRequestStatus extends StatelessWidget {
  const _UserRequestStatus({required this.request});

  final RewardRequest request;

  @override
  Widget build(BuildContext context) {
    final color = _requestStatusColor(request.status);
    return Row(
      children: [
        Icon(_requestStatusIcon(request.status), size: 17, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Request: ${request.statusLabel}',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (request.trackingReference != null)
          Tooltip(
            message: 'Tracking: ${request.trackingReference}',
            child: Icon(Icons.local_shipping_outlined, size: 18, color: color),
          ),
      ],
    );
  }
}

Color _requestStatusColor(String status) => switch (status) {
  'preparing' => AppColors.purple,
  'shipped' => AppColors.blue,
  'delivered' => AppColors.primary,
  'rejected' => AppColors.danger,
  _ => AppColors.accent,
};

IconData _requestStatusIcon(String status) => switch (status) {
  'preparing' => Icons.inventory_2_outlined,
  'shipped' => Icons.local_shipping_outlined,
  'delivered' => Icons.check_circle_outline,
  'rejected' => Icons.cancel_outlined,
  _ => Icons.schedule_outlined,
};
