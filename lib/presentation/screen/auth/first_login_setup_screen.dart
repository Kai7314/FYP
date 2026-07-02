import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/malaysia_locations.dart';
import '../../../services/user_service.dart';
import '../../../utils/validators.dart';
import '../../widgets/country_phone_field.dart';
import '../../widgets/malaysia_address_fields.dart';

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
  late final TextEditingController ageController;
  late final TextEditingController bloodTypeController;
  late final TextEditingController thresholdController;
  String? selectedState;
  String? selectedRegion;
  late String phoneDialCode;
  bool acceptedTerms = false;
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
    ageController = TextEditingController(
      text: widget.profile['age']?.toString() ?? '',
    );
    bloodTypeController = TextEditingController(
      text: widget.profile['blood_type']?.toString() ?? '',
    );
    thresholdController = TextEditingController(
      text: widget.profile['inactivity_threshold']?.toString() ?? '24',
    );
    selectedState = _initialState();
    selectedRegion = _initialRegion(selectedState);
    acceptedTerms =
        (widget.profile['terms_accepted_at']?.toString() ?? '').isNotEmpty;
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

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    ageController.dispose();
    bloodTypeController.dispose();
    thresholdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (!acceptedTerms) {
      _showMessage('Please accept the Terms and Conditions to continue.');
      return;
    }

    setState(() => saving = true);
    try {
      await userService.completeFirstLoginSetup({
        'name': AppValidators.normalizeSpaces(nameController.text),
        'phone': AppValidators.normalizePhoneWithCountry(
          phoneController.text,
          phoneDialCode,
        ),
        'address': AppValidators.normalizeSpaces(addressController.text),
        'address_state': selectedState,
        'address_region': selectedRegion,
        'age': int.parse(ageController.text.trim()),
        'blood_type': bloodTypeController.text.trim().toUpperCase(),
        'inactivity_threshold': int.parse(thresholdController.text.trim()),
      });
      if (mounted) widget.onComplete();
    } catch (error) {
      if (mounted) _showMessage(_setupErrorMessage(error));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _setupErrorMessage(Object error) {
    final text = error.toString();
    if (text.contains('PGRST204') || text.contains('schema cache')) {
      return 'Supabase users table is missing profile columns. Run supabase/quick_fix_users_profile_columns.sql, then retry.';
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
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: ageController,
                          keyboardType: TextInputType.number,
                          validator: (value) =>
                              AppValidators.age(value ?? '', required: true),
                          decoration: const InputDecoration(labelText: 'Age'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: bloodTypeController,
                          textCapitalization: TextCapitalization.characters,
                          validator: (value) => AppValidators.bloodType(
                            value ?? '',
                            required: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Blood type',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: thresholdController,
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        AppValidators.inactivityThreshold(value ?? ''),
                    decoration: const InputDecoration(
                      labelText: 'Inactivity threshold (hours)',
                      helperText: 'Between 1 and 168 hours',
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
                      'By continuing, you agree that EthernaCare stores your profile, check-ins, location-based emergency records, trusted contacts, rewards, and legacy-planning data to provide app features. Emergency alerts support user follow-up, but they do not replace official emergency services. For immediate danger in Malaysia, call 999.',
                      style: TextStyle(color: AppColors.muted, height: 1.35),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: acceptedTerms,
                      onChanged: saving
                          ? null
                          : (value) =>
                                setState(() => acceptedTerms = value ?? false),
                      title: const Text('I accept the Terms and Conditions'),
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
