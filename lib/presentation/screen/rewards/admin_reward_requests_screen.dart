import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/colors.dart';
import '../../../models/reward_request_model.dart';
import '../../../services/reward_request_service.dart';
import '../../widgets/error_dialog.dart';
import '../../widgets/premium_shell.dart';

class AdminRewardRequestsScreen extends StatefulWidget {
  const AdminRewardRequestsScreen({super.key});

  @override
  State<AdminRewardRequestsScreen> createState() =>
      _AdminRewardRequestsScreenState();
}

class _AdminRewardRequestsScreenState extends State<AdminRewardRequestsScreen> {
  final requestService = RewardRequestService();
  final dateFormat = DateFormat('d MMM yyyy, h:mm a');

  List<RewardRequest> requests = const [];
  String filter = 'all';
  bool loading = true;
  String? error;
  String? updatingRequestId;

  List<RewardRequest> get filteredRequests => switch (filter) {
    'pending' => requests.where((request) => request.isPending).toList(),
    'fulfillment' =>
      requests.where((request) => request.isInFulfillment).toList(),
    'completed' => requests.where((request) => request.isComplete).toList(),
    _ => requests,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final fresh = await requestService.getAdminRequests();
      if (!mounted) return;
      setState(() => requests = fresh);
    } catch (caught) {
      if (!mounted) return;
      setState(() => error = AppErrorDialog.friendlyMessage(caught));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _editRequest(RewardRequest request) async {
    final update = await showModalBottomSheet<_AdminRewardUpdate>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _FulfillmentUpdateSheet(request: request),
    );
    if (update == null || !mounted) return;

    setState(() => updatingRequestId = request.id);
    try {
      final updated = await requestService.updateAdminRequest(
        requestId: request.id,
        status: update.status,
        trackingReference: update.trackingReference,
        adminNotes: update.adminNotes,
      );
      if (!mounted) return;
      setState(() {
        requests = [
          for (final item in requests)
            if (item.id == updated.id) updated else item,
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${updated.rewardTitle} is now ${updated.statusLabel}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (caught) {
      if (!mounted) return;
      await AppErrorDialog.show(
        context,
        title: 'Could not update request',
        error: caught,
      );
    } finally {
      if (mounted) setState(() => updatingRequestId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = requests.where((request) => request.isPending).length;
    final fulfillment = requests
        .where((request) => request.isInFulfillment)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reward Requests'),
        actions: [
          IconButton(
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh requests',
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.appGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
              children: [
                const PremiumHeader(
                  title: 'Fulfillment Queue',
                  subtitle: 'Review and update every reward request',
                  orenAsset:
                      'lib/assets/images/pixel/oren_pixel_token_transparent.png',
                  orenSemanticLabel: 'Oren managing reward requests',
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _AdminMetric(
                        label: 'Total',
                        value: requests.length,
                        icon: Icons.receipt_long_outlined,
                        color: AppColors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _AdminMetric(
                        label: 'Pending',
                        value: pending,
                        icon: Icons.schedule_outlined,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _AdminMetric(
                        label: 'In delivery',
                        value: fulfillment,
                        icon: Icons.local_shipping_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: filter,
                  decoration: const InputDecoration(
                    labelText: 'Show requests',
                    prefixIcon: Icon(Icons.filter_list),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All requests')),
                    DropdownMenuItem(
                      value: 'pending',
                      child: Text('Pending review'),
                    ),
                    DropdownMenuItem(
                      value: 'fulfillment',
                      child: Text('Preparing or shipped'),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Delivered or rejected'),
                    ),
                  ],
                  onChanged: (value) => setState(() => filter = value ?? 'all'),
                ),
                const SizedBox(height: 16),
                if (loading && requests.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (error != null)
                  _AdminEmptyState(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Admin requests unavailable',
                    message: error!,
                  )
                else if (filteredRequests.isEmpty)
                  const _AdminEmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No requests here',
                    message:
                        'Reward requests matching this filter will appear here.',
                  )
                else
                  for (final request in filteredRequests)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AdminRequestCard(
                        request: request,
                        requestedAt: dateFormat.format(
                          request.requestedAt.toLocal(),
                        ),
                        updating: updatingRequestId == request.id,
                        onUpdate: () => _editRequest(request),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminMetric extends StatelessWidget {
  const _AdminMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      color: color.withValues(alpha: .1),
      borderColor: color.withValues(alpha: .2),
      child: SizedBox(
        height: 62,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: color),
                const SizedBox(width: 5),
                Text(
                  '$value',
                  style: TextStyle(
                    color: color,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminRequestCard extends StatelessWidget {
  const _AdminRequestCard({
    required this.request,
    required this.requestedAt,
    required this.updating,
    required this.onUpdate,
  });

  final RewardRequest request;
  final String requestedAt;
  final bool updating;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(request.status);
    return GlassPanel(
      color: AppColors.glassStrong,
      borderColor: statusColor.withValues(alpha: .25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  request.isPhysical
                      ? Icons.inventory_2_outlined
                      : Icons.confirmation_number_outlined,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.rewardTitle,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${request.rewardSponsor} - $requestedAt',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RequestStatusBadge(
                label: request.statusLabel,
                color: statusColor,
              ),
            ],
          ),
          const Divider(height: 24),
          _DetailLine(
            icon: Icons.person_outline,
            value:
                '${request.userName ?? request.recipientName}'
                '${request.userEmail == null ? '' : ' (${request.userEmail})'}',
          ),
          _DetailLine(
            icon: Icons.call_outlined,
            value: '${request.recipientName} - ${request.contactPhone}',
          ),
          _DetailLine(
            icon: Icons.location_on_outlined,
            value: request.deliveryAddressLabel,
          ),
          if (request.trackingReference != null)
            _DetailLine(
              icon: Icons.local_shipping_outlined,
              value: 'Tracking: ${request.trackingReference}',
            ),
          if (request.adminNotes != null)
            _DetailLine(icon: Icons.notes_outlined, value: request.adminNotes!),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: updating ? null : onUpdate,
              icon: updating
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.edit_outlined),
              label: Text(updating ? 'Updating...' : 'Update'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestStatusBadge extends StatelessWidget {
  const _RequestStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AdminEmptyState extends StatelessWidget {
  const _AdminEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 42, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _FulfillmentUpdateSheet extends StatefulWidget {
  const _FulfillmentUpdateSheet({required this.request});

  final RewardRequest request;

  @override
  State<_FulfillmentUpdateSheet> createState() =>
      _FulfillmentUpdateSheetState();
}

class _FulfillmentUpdateSheetState extends State<_FulfillmentUpdateSheet> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController trackingController;
  late final TextEditingController notesController;
  late String status;

  @override
  void initState() {
    super.initState();
    status = widget.request.status;
    trackingController = TextEditingController(
      text: widget.request.trackingReference ?? '',
    );
    notesController = TextEditingController(
      text: widget.request.adminNotes ?? '',
    );
  }

  @override
  void dispose() {
    trackingController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _AdminRewardUpdate(
        status: status,
        trackingReference: _nullable(trackingController.text),
        adminNotes: _nullable(notesController.text),
      ),
    );
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Update Fulfillment',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.request.rewardTitle,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.fact_check_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(
                    value: 'preparing',
                    child: Text('Preparing'),
                  ),
                  DropdownMenuItem(value: 'shipped', child: Text('Shipped')),
                  DropdownMenuItem(
                    value: 'delivered',
                    child: Text('Delivered'),
                  ),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                ],
                onChanged: (value) => setState(() => status = value ?? status),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: trackingController,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Tracking reference',
                  hintText: 'Courier tracking number',
                  prefixIcon: Icon(Icons.local_shipping_outlined),
                ),
                validator: (value) {
                  final length = value?.trim().length ?? 0;
                  if (length == 1) {
                    return 'Tracking reference is too short.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: notesController,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Admin notes',
                  hintText: 'Optional fulfillment notes',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Update'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminRewardUpdate {
  const _AdminRewardUpdate({
    required this.status,
    this.trackingReference,
    this.adminNotes,
  });

  final String status;
  final String? trackingReference;
  final String? adminNotes;
}

Color _statusColor(String status) => switch (status) {
  'preparing' => AppColors.purple,
  'shipped' => AppColors.blue,
  'delivered' => AppColors.primary,
  'rejected' => AppColors.danger,
  _ => AppColors.accent,
};
