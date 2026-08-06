import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../models/reward_model.dart';
import '../../widgets/premium_shell.dart';
import 'reward_detail_screen.dart';

class RewardCollectionScreen extends StatelessWidget {
  const RewardCollectionScreen({super.key, required this.snapshot});

  final RewardSnapshot snapshot;

  Future<void> _openReward(
    BuildContext context,
    RewardCatalogItem reward,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RewardDetailScreen(
          reward: reward,
          redemptionCode: snapshot.redemptionCodeFor(reward.code),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final collection = snapshot.collectionItems;
    final badges = collection.where((item) => !item.isVoucher).toList();
    final vouchers = collection.where((item) => item.isVoucher).toList();

    return PremiumScaffold(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Reward Collection',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                PremiumStatusPill(
                  icon: Icons.inventory_2_outlined,
                  label: '${collection.length}',
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const PremiumHeader(
                          title: 'Your Collection',
                          subtitle:
                              'Open a reward to view its details and redeem code.',
                          orenAsset:
                              'lib/assets/images/pixel/oren_pixel_token_transparent.png',
                          orenSemanticLabel:
                              'Oren presenting the reward collection',
                        ),
                        const SizedBox(height: 18),
                        if (collection.isEmpty)
                          const _EmptyCollection()
                        else ...[
                          if (vouchers.isNotEmpty) ...[
                            _CollectionSection(
                              title: 'Vouchers',
                              count: vouchers.length,
                              children: vouchers
                                  .map(
                                    (reward) => _CollectionRewardTile(
                                      reward: reward,
                                      redemptionCode: snapshot
                                          .redemptionCodeFor(reward.code),
                                      onTap: () => _openReward(context, reward),
                                    ),
                                  )
                                  .toList(),
                            ),
                            if (badges.isNotEmpty)
                              const SizedBox(height: 20),
                          ],
                          if (badges.isNotEmpty)
                            _CollectionSection(
                              title: 'Badges',
                              count: badges.length,
                              children: badges
                                  .map(
                                    (reward) => _CollectionRewardTile(
                                      reward: reward,
                                      onTap: () => _openReward(context, reward),
                                    ),
                                  )
                                  .toList(),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionSection extends StatelessWidget {
  const _CollectionSection({
    required this.title,
    required this.count,
    required this.children,
  });

  final String title;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            Text(
              '$count collected',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }
}

class _CollectionRewardTile extends StatelessWidget {
  const _CollectionRewardTile({
    required this.reward,
    required this.onTap,
    this.redemptionCode,
  });

  final RewardCatalogItem reward;
  final String? redemptionCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final voucher = reward.isVoucher;
    final color = voucher ? AppColors.accent : AppColors.primary;
    final codeReady = redemptionCode?.trim().isNotEmpty == true;
    final detail = voucher
        ? codeReady
              ? '${reward.voucherValue ?? 'Virtual voucher'} - redeem code ready'
              : 'Virtual voucher - redeem code is being prepared'
        : '${reward.milestoneDays}-day milestone badge';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        color: Colors.white.withValues(alpha: .82),
        borderColor: color.withValues(alpha: .28),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                voucher
                    ? Icons.confirmation_number_outlined
                    : Icons.workspace_premium_outlined,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reward.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }
}

class _EmptyCollection extends StatelessWidget {
  const _EmptyCollection();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      color: AppColors.glassStrong,
      child: Column(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 42,
            color: AppColors.muted,
          ),
          const SizedBox(height: 12),
          Text(
            'Your collection is empty',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 5),
          const Text(
            'Complete a reward goal and collect it to store it here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.35),
          ),
        ],
      ),
    );
  }
}
