import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/colors.dart';
import '../../../models/reward_model.dart';
import '../../widgets/premium_shell.dart';

class RewardDetailScreen extends StatelessWidget {
  const RewardDetailScreen({
    super.key,
    required this.reward,
    this.redemptionCode,
  });

  final RewardCatalogItem reward;
  final String? redemptionCode;

  Future<void> _copyCode(BuildContext context) async {
    final code = redemptionCode?.trim() ?? '';
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Redeem code copied.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final code = redemptionCode?.trim() ?? '';
    return PremiumScaffold(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
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
                    'Reward Details',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
              children: [
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: reward.isVoucher
                          ? AppColors.accent
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      reward.isVoucher
                          ? Icons.confirmation_number_outlined
                          : Icons.workspace_premium_outlined,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  reward.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  reward.isVoucher
                      ? 'Virtual voucher · ${reward.voucherValue ?? 'Special offer'}'
                      : 'Virtual badge',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                GlassPanel(
                  padding: const EdgeInsets.all(18),
                  color: AppColors.glassStrong,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(
                        icon: Icons.business_outlined,
                        label: 'Issued by',
                        value: reward.sponsor,
                      ),
                      const SizedBox(height: 15),
                      _DetailRow(
                        icon: Icons.flag_outlined,
                        label: 'Goal completed',
                        value: '${reward.milestoneDays}-day check-in streak',
                      ),
                      const SizedBox(height: 15),
                      _DetailRow(
                        icon: Icons.notes_outlined,
                        label: 'Reward',
                        value: reward.description,
                      ),
                    ],
                  ),
                ),
                if (reward.isVoucher) ...[
                  const SizedBox(height: 16),
                  GlassPanel(
                    padding: const EdgeInsets.all(18),
                    color: AppColors.warningSoft,
                    borderColor: AppColors.accent.withValues(alpha: .4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Personal redeem code',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: SelectableText(
                            code.isEmpty ? 'Code is being prepared' : code,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontFamily: 'monospace',
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: code.isEmpty
                              ? null
                              : () => _copyCode(context),
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('Copy Redeem Code'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primaryDark, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
