import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/colors.dart';
import '../../../models/reward_model.dart';
import '../../../services/reward_admin_service.dart';
import '../../widgets/premium_shell.dart';

class AdminRewardEditorScreen extends StatefulWidget {
  const AdminRewardEditorScreen({
    super.key,
    required this.adminService,
    this.reward,
  });

  final RewardAdminService adminService;
  final RewardCatalogItem? reward;

  bool get editing => reward != null;

  @override
  State<AdminRewardEditorScreen> createState() =>
      _AdminRewardEditorScreenState();
}

class _AdminRewardEditorScreenState
    extends State<AdminRewardEditorScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController codeController;
  late final TextEditingController titleController;
  late final TextEditingController descriptionController;
  late final TextEditingController milestoneController;
  late final TextEditingController voucherValueController;
  late String rewardKind;
  late bool active;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final reward = widget.reward;
    codeController = TextEditingController(text: reward?.code ?? '');
    titleController = TextEditingController(text: reward?.title ?? '');
    descriptionController = TextEditingController(
      text: reward?.description ?? '',
    );
    milestoneController = TextEditingController(
      text: reward?.milestoneDays.toString() ?? '',
    );
    voucherValueController = TextEditingController(
      text: reward?.voucherValue ?? '',
    );
    rewardKind = reward?.rewardKind == 'voucher' ? 'voucher' : 'virtual';
    active = reward?.active ?? true;
  }

  String? _validateCode(String? value) {
    final code = value?.trim().toLowerCase() ?? '';
    if (!RegExp(r'^[a-z][a-z0-9_]{2,49}$').hasMatch(code)) {
      return 'Use 3-50 lowercase letters, numbers, or underscores.';
    }
    return null;
  }

  String? _validateTitle(String? value) {
    final length = value?.trim().length ?? 0;
    if (length < 2 || length > 80) {
      return 'Title must contain 2-80 characters.';
    }
    return null;
  }

  String? _validateDescription(String? value) {
    final length = value?.trim().length ?? 0;
    if (length < 5 || length > 240) {
      return 'Description must contain 5-240 characters.';
    }
    return null;
  }

  String? _validateMilestone(String? value) {
    final days = int.tryParse(value?.trim() ?? '');
    if (days == null || days < 1 || days > 365) {
      return 'Enter a milestone from 1 to 365 days.';
    }
    return null;
  }

  String? _validateVoucherValue(String? value) {
    if (rewardKind != 'voucher') return null;
    final length = value?.trim().length ?? 0;
    if (length < 2 || length > 80) {
      return 'Voucher value must contain 2-80 characters.';
    }
    return null;
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await widget.adminService.saveReward(
        code: codeController.text.trim().toLowerCase(),
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        milestoneDays: int.parse(milestoneController.text.trim()),
        active: active,
        rewardKind: rewardKind,
        voucherValue: rewardKind == 'voucher'
            ? voucherValueController.text.trim()
            : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save reward: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    titleController.dispose();
    descriptionController.dispose();
    milestoneController.dispose();
    voucherValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.editing ? 'Edit Virtual Reward' : 'New Virtual Reward',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: codeController,
                          enabled: !widget.editing && !saving,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9_]'),
                            ),
                            LengthLimitingTextInputFormatter(50),
                          ],
                          validator: _validateCode,
                          decoration: const InputDecoration(
                            labelText: 'Reward code',
                            prefixIcon: Icon(Icons.tag),
                            helperText: 'Example: oren_kindness_badge',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: titleController,
                          enabled: !saving,
                          maxLength: 80,
                          validator: _validateTitle,
                          decoration: const InputDecoration(
                            labelText: 'Reward title',
                            prefixIcon: Icon(Icons.workspace_premium_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'virtual',
                              icon: Icon(Icons.workspace_premium_outlined),
                              label: Text('Badge'),
                            ),
                            ButtonSegment(
                              value: 'voucher',
                              icon: Icon(Icons.confirmation_number_outlined),
                              label: Text('Voucher'),
                            ),
                          ],
                          selected: {rewardKind},
                          onSelectionChanged: saving
                              ? null
                              : (selection) => setState(
                                  () => rewardKind = selection.first,
                                ),
                        ),
                        if (rewardKind == 'voucher') ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: voucherValueController,
                            enabled: !saving,
                            maxLength: 80,
                            validator: _validateVoucherValue,
                            decoration: const InputDecoration(
                              labelText: 'Voucher value or offer',
                              hintText: 'Example: RM5 or One free drink',
                              prefixIcon: Icon(
                                Icons.local_offer_outlined,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: descriptionController,
                          enabled: !saving,
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 240,
                          validator: _validateDescription,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: milestoneController,
                          enabled: !saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          validator: _validateMilestone,
                          decoration: const InputDecoration(
                            labelText: 'Check-in streak milestone',
                            suffixText: 'days',
                            prefixIcon: Icon(Icons.flag_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          value: active,
                          onChanged: saving
                              ? null
                              : (value) => setState(() => active = value),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          tileColor: Colors.white.withValues(alpha: .82),
                          secondary: Icon(
                            active
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: active
                                ? AppColors.primaryDark
                                : AppColors.muted,
                          ),
                          title: const Text(
                            'Available to users',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            active
                                ? 'Users can earn this virtual reward.'
                                : 'This reward is hidden and cannot be newly earned.',
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: saving ? null : _save,
                          icon: saving
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            saving
                                ? 'Saving...'
                                : widget.editing
                                ? 'Save Changes'
                                : 'Create Reward',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
