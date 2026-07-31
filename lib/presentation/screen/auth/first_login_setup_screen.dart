import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/malaysia_locations.dart';
import '../../../models/emergency_escalation_target.dart';
import '../../../services/user_service.dart';
import '../../../utils/validators.dart';
import '../../widgets/country_phone_field.dart';
import '../../widgets/malaysia_address_fields.dart';
import '../../widgets/phone_otp_verification_card.dart';
import '../../../services/phone_verification_service.dart';
import '../legal/terms_and_conditions_screen.dart';

class FirstLoginSetupScreen extends StatefulWidget {
  const FirstLoginSetupScreen({
    super.key,
    required this.profile,
    required this.onComplete,
  });

  final Map<String, dynamic> profile;
  final VoidCallback onComplete;

  @override
  State<FirstLoginSetupScreen> createState() => _FirstLoginSetupScreenState();
}

class _FirstLoginSetupScreenState extends State<FirstLoginSetupScreen> {
  final formKey = GlobalKey<FormState>();
  final userService = UserService();
  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController addressController;
  late final TextEditingController thresholdController;
  String? selectedState;
  String? selectedRegion;
  String? selectedBloodType;
  String escalationTarget = EmergencyEscalationTarget.trustedContacts;
  late String phoneDialCode;
  String? verifiedPhone;
  bool acceptedTerms = false;
  bool termsReviewed = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(
      text: widget.profile['name']?.toString() ?? '',
    );
    final profilePhone = widget.profile['phone']?.toString() ?? '';
    phoneDialCode = AppValidators.detectPhoneCountry(profilePhone).dialCode;
    phoneController = TextEditingController(
      text: AppValidators.localPhoneForCountry(profilePhone, phoneDialCode),
    );
    addressController = TextEditingController(
      text: widget.profile['address']?.toString() ?? '',
    );
    selectedBloodType = _initialBloodType();
    thresholdController = TextEditingController(
      text: widget.profile['inactivity_threshold']?.toString() ?? '24',
    );
    escalationTarget = EmergencyEscalationTarget.normalize(
      widget.profile['emergency_escalation_target'],
    );
    selectedState = _initialState();
    selectedRegion = _initialRegion(selectedState);
    acceptedTerms =
        (widget.profile['terms_accepted_at']?.toString() ?? '').isNotEmpty;
    termsReviewed = acceptedTerms;
  }

  String? _initialState() {
    final value = widget.profile['address_state']?.toString();
    return MalaysiaLocations.states.contains(value) ? value : null;
  }

  String? _initialRegion(String? state) {
    final value = widget.profile['address_region']?.toString();
    final regions = MalaysiaLocations.regionsFor(state);
    return regions.any((location) => location.region == value) ? value : null;
  }

  String? _initialBloodType() {
    final value = widget.profile['blood_type']?.toString().toUpperCase();
    return AppValidators.bloodTypes.contains(value) ? value : null;
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    thresholdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (!acceptedTerms) {
      _showMessage('Please accept the Terms and Conditions to continue.');
      return;
    }
    final phone = _normalizedPhone();
    if (verifiedPhone != phone) {
      _showMessage('Please verify your phone number first.');
      return;
    }

    setState(() => saving = true);
    try {
      await userService.completeFirstLoginSetup({
        'name': AppValidators.normalizeSpaces(nameController.text),
        'phone': phone,
        'address': AppValidators.normalizeSpaces(addressController.text),
        'address_state': selectedState,
        'address_region': selectedRegion,
        'blood_type': selectedBloodType,
        'inactivity_threshold': int.parse(thresholdController.text.trim()),
        'emergency_escalation_target': escalationTarget,
      });
      if (mounted) widget.onComplete();
    } catch (error) {
      if (mounted) _showMessage(_setupErrorMessage(error));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _openTerms() async {
    final accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const TermsAndConditionsScreen(acceptanceMode: true),
      ),
    );
    if (!mounted || accepted != true) return;
    setState(() {
      termsReviewed = true;
      acceptedTerms = true;
    });
  }

  Future<void> _setTermsAccepted(bool? value) async {
    if (value == true && !termsReviewed) {
      await _openTerms();
      return;
    }
    setState(() => acceptedTerms = value ?? false);
  }

  String _normalizedPhone() {
    return AppValidators.normalizePhoneWithCountry(
      phoneController.text,
      phoneDialCode,
    );
  }

  String _setupErrorMessage(Object error) {
    final text = error.toString();
    if (text.contains('PGRST204') || text.contains('schema cache')) {
      return 'Supabase users table is missing profile columns. Run supabase/quick_fix_users_profile_columns.sql, then retry.';
    }
    if (text.toLowerCase().contains('verify your phone number')) {
      return 'Please send and enter the SMS verification code before saving your phone number.';
    }
    return 'Could not save setup: $error';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
          children: [
            const Text(
              'Complete Your Profile',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'EthernaCare needs these details before emergency, check-in, and reminder features can work properly.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 22),
            Form(
              key: formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: nameController,
                    maxLength: AppValidators.maxDisplayNameLength,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) =>
                        AppValidators.displayName(value ?? ''),
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  const SizedBox(height: 10),
                  CountryPhoneField(
                    controller: phoneController,
                    dialCode: phoneDialCode,
                    onDialCodeChanged: (value) =>
                        setState(() => phoneDialCode = value),
                    labelText: 'Phone',
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: phoneController,
                    builder: (context, value, child) {
                      return PhoneOtpVerificationCard(
                        phone: _normalizedPhone(),
                        purpose: PhoneVerificationPurpose.userPhone,
                        enabled: !saving,
                        onVerified: (phone) =>
                            setState(() => verifiedPhone = phone),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  MalaysiaAddressFields(
                    addressController: addressController,
                    selectedState: selectedState,
                    selectedRegion: selectedRegion,
                    addressRequired: true,
                    onStateChanged: (value) => setState(() {
                      selectedState = value;
                      selectedRegion = null;
                    }),
                    onRegionChanged: (value) =>
                        setState(() => selectedRegion = value),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedBloodType,
                    items: AppValidators.bloodTypes
                        .map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        )
                        .toList(),
                    onChanged: saving
                        ? null
                        : (value) => setState(() => selectedBloodType = value),
                    validator: (value) =>
                        AppValidators.bloodType(value ?? '', required: true),
                    decoration: const InputDecoration(labelText: 'Blood type'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: thresholdController,
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        AppValidators.inactivityThreshold(value ?? ''),
                    decoration: const InputDecoration(
                      labelText: 'Inactivity threshold (hours)',
                      helperText: '1-168 hours for each missed check-in',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: escalationTarget,
                    items: EmergencyEscalationTarget.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(EmergencyEscalationTarget.label(value)),
                          ),
                        )
                        .toList(),
                    onChanged: saving
                        ? null
                        : (value) => setState(
                            () => escalationTarget =
                                EmergencyEscalationTarget.normalize(value),
                          ),
                    decoration: const InputDecoration(
                      labelText: 'Inactivity escalation',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    EmergencyEscalationTarget.description(escalationTarget),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.policy_outlined, color: AppColors.primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Terms and Conditions',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Read how check-ins, alerts, trusted contacts, sensitive profile data, rewards, and Legacy Planning work before continuing.',
                      style: TextStyle(color: AppColors.muted, height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('read-setup-terms-button'),
                      onPressed: saving ? null : _openTerms,
                      icon: const Icon(Icons.menu_book_outlined),
                      label: Text(
                        termsReviewed
                            ? 'Review Terms and Conditions'
                            : 'Read Terms and Conditions',
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: acceptedTerms,
                      onChanged: saving ? null : _setTermsAccepted,
                      title: const Text(
                        'I agree to the Terms and Conditions, including the privacy and safety notices.',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: saving ? null : _save,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(saving ? 'Saving...' : 'Finish Setup'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: saving ? null : userService.signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
