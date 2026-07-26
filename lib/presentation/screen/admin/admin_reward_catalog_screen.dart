import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../models/reward_model.dart';
import '../../../services/reward_admin_service.dart';
import '../../widgets/premium_shell.dart';
import 'admin_reward_editor_screen.dart';

class AdminRewardCatalogScreen extends StatefulWidget {
  const AdminRewardCatalogScreen({
    super.key,
    required this.adminService,
    required this.adminEmail,
  });

  final RewardAdminService adminService;
  final String adminEmail;

  @override
  State<AdminRewardCatalogScreen> createState() =>
      _AdminRewardCatalogScreenState();
}

class _AdminRewardCatalogScreenState
    extends State<AdminRewardCatalogScreen> {
  late Future<List<RewardCatalogItem>> catalogFuture = _loadCatalog();
  final Set<String> selectedCodes = {};
  bool deleting = false;
  bool refreshingCatalog = false;
  Timer? catalogRefreshDebounce;

  @override
  void initState() {
    super.initState();
    widget.adminService.startCatalogRealtime(_queueCatalogRefresh);
  }

  Future<List<RewardCatalogItem>> _loadCatalog() {
    return widget.adminService.getCatalog().timeout(
      const Duration(seconds: 18),
    );
  }

  Future<void> _refresh() async {
    if (!mounted || refreshingCatalog) return;
    final future = _loadCatalog();
    setState(() {
      refreshingCatalog = true;
      catalogFuture = future;
    });
    try {
      await future;
    } catch (_) {
      // FutureBuilder renders the retry state for the same failed future.
    } finally {
      if (mounted) setState(() => refreshingCatalog = false);
    }
  }

  void _queueCatalogRefresh() {
    catalogRefreshDebounce?.cancel();
    catalogRefreshDebounce = Timer(
      const Duration(milliseconds: 350),
      _refresh,
    );
  }

  Future<void> _openEditor([RewardCatalogItem? item]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminRewardEditorScreen(
          adminService: widget.adminService,
          reward: item,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _refresh();
    }
  }

  Future<void> _signOut() async {
    await widget.adminService.signOut();
  }

  @override
  void dispose() {
    catalogRefreshDebounce?.cancel();
    unawaited(widget.adminService.stopCatalogRealtime());
    super.dispose();
  }

  Future<void> _deleteSelected() async {
    if (selectedCodes.isEmpty || deleting) return;
    final count = selectedCodes.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
        title: Text('Delete $count ${count == 1 ? 'reward' : 'rewards'}?'),
        content: const Text(
          'This permanently removes the selected virtual rewards. Rewards already earned by a user cannot be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => deleting = true);
    try {
      final deleted = await widget.adminService.deleteRewards(selectedCodes);
      if (!mounted) return;
      setState(() => selectedCodes.clear());
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$deleted virtual ${deleted == 1 ? 'reward' : 'rewards'} deleted.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_deleteErrorMessage(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }

  String _deleteErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('already been earned')) {
      return 'An earned reward cannot be deleted. Edit it and turn off "Available to users" instead.';
    }
    return 'Could not delete the selected rewards.';
  }

  void _setSelected(String code, bool selected) {
    setState(() {
      if (selected) {
        selectedCodes.add(code);
      } else {
        selectedCodes.remove(code);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.workspace_premium_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Virtual Reward Catalog',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.adminEmail,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Add virtual reward',
                  onPressed: deleting || refreshingCatalog
                      ? null
                      : () => _openEditor(),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                IconButton(
                  tooltip: 'Refresh catalog',
                  onPressed: deleting || refreshingCatalog ? null : _refresh,
                  icon: refreshingCatalog
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: selectedCodes.isEmpty
                      ? 'Select rewards to delete'
                      : 'Delete selected rewards',
                  onPressed: selectedCodes.isEmpty || deleting
                      ? null
                      : _deleteSelected,
                  color: AppColors.danger,
                  icon: deleting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Badge(
                          isLabelVisible: selectedCodes.isNotEmpty,
                          label: Text('${selectedCodes.length}'),
                          child: const Icon(Icons.delete_outline),
                        ),
                ),
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: deleting ? null : _signOut,
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<RewardCatalogItem>>(
              future: catalogFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _CatalogError(onRetry: _refresh);
                }

                final items = snapshot.data ?? const <RewardCatalogItem>[];
                if (items.isEmpty) {
                  return _EmptyCatalog(onAdd: () => _openEditor());
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _CatalogRow(
                        item: item,
                        selected: selectedCodes.contains(item.code),
                        onSelected: (selected) =>
                            _setSelected(item.code, selected),
                        onEdit: () => _openEditor(item),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogRow extends StatelessWidget {
  const _CatalogRow({
    required this.item,
    required this.selected,
    required this.onSelected,
    required this.onEdit,
  });

  final RewardCatalogItem item;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: selected,
                onChanged: (value) => onSelected(value ?? false),
                semanticLabel: 'Select ${item.title}',
              ),
              const SizedBox(width: 4),
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.active
                      ? AppColors.primarySoft
                      : AppColors.border.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item.milestoneDays}d',
                  style: TextStyle(
                    color: item.active
                        ? AppColors.primaryDark
                        : AppColors.muted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ActiveLabel(active: item.active),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: const TextStyle(
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          item.isVoucher
                              ? Icons.confirmation_number_outlined
                              : Icons.workspace_premium_outlined,
                          size: 14,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          item.isVoucher
                              ? 'Voucher${item.voucherValue == null ? '' : ' · ${item.voucherValue}'}'
                              : 'Badge',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.code,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Edit reward',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveLabel extends StatelessWidget {
  const _ActiveLabel({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primaryDark : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: 12),
            const Text(
              'Could not load the reward catalog.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium_outlined, size: 44),
            const SizedBox(height: 12),
            const Text(
              'No virtual rewards yet.',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add Reward'),
            ),
          ],
        ),
      ),
    );
  }
}
