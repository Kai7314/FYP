import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/malaysia_locations.dart';
import '../../../models/reward_model.dart';
import '../../../models/reward_request_model.dart';
import '../../../services/reward_request_service.dart';
import '../../../services/user_service.dart';
import '../../../utils/validators.dart';
import '../../widgets/country_phone_field.dart';
import '../../widgets/error_dialog.dart';
import '../../widgets/malaysia_address_fields.dart';
import '../../widgets/premium_shell.dart';

class RewardRequestScreen extends StatefulWidget {
  const RewardRequestScreen({super.key, required this.item});

  final RewardCatalogItem item;

  @override
  State<RewardRequestScreen> createState() => _RewardRequestScreenState();
}

class _RewardRequestScreenState extends State<RewardRequestScreen> {
  final formKey = GlobalKey<FormState>();
  final userService = UserService();
  final requestService = RewardRequestService();
  final recipientController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();

  String phoneDialCode = AppValidators.defaultPhoneCountry.dialCode;
  String? selectedState;
  String? selectedRegion;
  bool loadingProfile = true;
  bool submitting = false;
  String? profileError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    recipientController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await userService.getCurrentProfile(forceRefresh: true);
      final phone = profile['phone']?.toString() ?? '';
      final country = AppValidators.detectPhoneCountry(phone);
      recipientController.text = profile['name']?.toString() ?? '';
      phoneDialCode = country.dialCode;
      phoneController.text = AppValidators.localPhoneForCountry(
        phone,
        phoneDialCode,
      );
      addressController.text = profile['address']?.toString() ?? '';
      selectedState = _availableState(profile['address_state']?.toString());
      selectedRegion = _availableRegion(
        selectedState,
        profile['address_region']?.toString(),
      );
    } catch (_) {
      profileError =
          'Profile details could not be loaded. Enter the delivery details below.';
    } finally {
      if (mounted) setState(() => loadingProfile = false);
    }
  }

  String? _availableState(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return MalaysiaLocations.states.contains(value) ? value : null;
  }

  String? _availableRegion(String? state, String? value) {
    if (state == null || value == null || value.trim().isEmpty) return null;
    return MalaysiaLocations.regionsFor(
          state,
        ).any((location) => location.region == value)
        ? value
        : null;
  }

  Future<void> _submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final state = selectedState;
    final region = selectedRegion;
    if (state == null || region == null) return;

    setState(() => submitting = true);
    try {
      final request = await requestService.requestReward(
        rewardCode: widget.item.code,
        delivery: RewardDeliveryDetails(
          recipientName: AppValidators.normalizeSpaces(
            recipientController.text,
          ),
          contactPhone: AppValidators.normalizePhoneWithCountry(
            phoneController.text,
            phoneDialCode,
          ),
          address: AppValidators.normalizeSpaces(addressController.text),
          state: state,
          region: region,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(request);
    } catch (error) {
      if (!mounted) return;
      await AppErrorDialog.show(
        context,
        title: 'Could not request reward',
        error: error,
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Reward')),
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
          child: loadingProfile
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                    children: [
                      _RewardSummary(item: widget.item),
                      const SizedBox(height: 20),
                      const Text(
                        'Delivery details',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.item.rewardKind == 'voucher'
                            ? 'Confirm your details for voucher fulfillment.'
                            : 'Confirm where this reward should be delivered.',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      if (profileError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          profileError!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _FieldShell(
                        label: 'Recipient name',
                        child: TextFormField(
                          controller: recipientController,
                          maxLength: 80,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) =>
                              AppValidators.displayName(value ?? ''),
                          decoration: const InputDecoration(
                            hintText: 'Full name',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      CountryPhoneField(
                        controller: phoneController,
                        dialCode: phoneDialCode,
                        onDialCodeChanged: (value) =>
                            setState(() => phoneDialCode = value),
                        labelText: 'Delivery phone',
                        externalLabels: true,
                      ),
                      const SizedBox(height: 16),
                      MalaysiaAddressFields(
                        addressController: addressController,
                        selectedState: selectedState,
                        selectedRegion: selectedRegion,
                        addressRequired: true,
                        externalLabels: true,
                        addressLabel: 'Delivery address',
                        addressHelperText: null,
                        stateLabel: 'State',
                        regionLabel: 'Region / district',
                        regionHelperText: null,
                        onStateChanged: (value) => setState(() {
                          selectedState = value;
                          selectedRegion = null;
                        }),
                        onRegionChanged: (value) =>
                            setState(() => selectedRegion = value),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: submitting ? null : _submit,
                        icon: submitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                widget.item.rewardKind == 'voucher'
                                    ? Icons.confirmation_number_outlined
                                    : Icons.local_shipping_outlined,
                              ),
                        label: Text(
                          submitting ? 'Submitting...' : 'Submit Request',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
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

class _RewardSummary extends StatelessWidget {
  const _RewardSummary({required this.item});

  final RewardCatalogItem item;

  @override
  Widget build(BuildContext context) {
    final voucher = item.rewardKind == 'voucher';
    return GlassPanel(
      color: voucher ? AppColors.warningSoft : AppColors.primarySoft,
      borderColor: (voucher ? AppColors.accent : AppColors.primary).withValues(
        alpha: .28,
      ),
      child: Row(
        children: [
          Icon(
            voucher
                ? Icons.confirmation_number_outlined
                : Icons.inventory_2_outlined,
            color: voucher ? AppColors.accent : AppColors.primary,
            size: 34,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${item.sponsor} - earned at ${item.milestoneDays} days',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldShell extends StatelessWidget {
  const _FieldShell({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
