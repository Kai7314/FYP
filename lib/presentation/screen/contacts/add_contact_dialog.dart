import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../utils/validators.dart';
import '../../widgets/country_phone_field.dart';
import '../../widgets/malaysia_address_fields.dart';
import '../../widgets/phone_otp_verification_card.dart';
import '../../../services/phone_verification_service.dart';

class AddContactPage extends StatefulWidget {
  const AddContactPage({
    super.key,
    this.requirePhoneVerification = true,
    this.initialContact,
  });

  final bool requirePhoneVerification;
  final Map<String, dynamic>? initialContact;

  @override
  State<AddContactPage> createState() => _AddContactPageState();
}

class AddContactDialog extends AddContactPage {
  const AddContactDialog({super.key}) : super(requirePhoneVerification: false);
}

class _AddContactPageState extends State<AddContactPage> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final relationshipController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();
  String phoneDialCode = AppValidators.defaultPhoneCountry.dialCode;
  String? selectedState = 'Kuala Lumpur';
  String? selectedRegion = 'Kuala Lumpur';
  String? verifiedPhone;
  bool isPrimary = false;

  bool get isEditing => widget.initialContact != null;

  @override
  void initState() {
    super.initState();
    final contact = widget.initialContact;
    if (contact == null) return;

    nameController.text = contact['name']?.toString() ?? '';
    relationshipController.text = contact['relationship']?.toString() ?? '';
    emailController.text = contact['email']?.toString() ?? '';
    addressController.text = contact['address']?.toString() ?? '';
    selectedState = contact['address_state']?.toString();
    selectedRegion = contact['address_region']?.toString();
    isPrimary = contact['is_primary'] == true;

    final phone = contact['phone']?.toString() ?? '';
    final country = AppValidators.detectPhoneCountry(phone);
    phoneDialCode = country.dialCode;
    phoneController.text = AppValidators.localPhoneForCountry(
      phone,
      phoneDialCode,
    );
    if (contact['phone_verified_at'] != null) {
      verifiedPhone = AppValidators.normalizePhoneWithCountry(
        phone,
        phoneDialCode,
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    relationshipController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    super.dispose();
  }

  String _normalizedPhone() {
    return AppValidators.normalizePhoneWithCountry(
      phoneController.text,
      phoneDialCode,
    );
  }

  void _submit() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final phone = _normalizedPhone();
    if (widget.requirePhoneVerification && verifiedPhone != phone) {
      _showMessage('Please verify this contact phone number first.');
      return;
    }

    Navigator.of(context).pop({
      'name': AppValidators.normalizeSpaces(nameController.text),
      'relationship': AppValidators.normalizeSpaces(relationshipController.text),
      'phone': phone,
      'email': emailController.text.trim().toLowerCase(),
      'address': AppValidators.normalizeSpaces(addressController.text),
      'address_state': selectedState,
      'address_region': selectedRegion,
      'is_primary': isPrimary,
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Contact' : 'Add Contact')),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(
                isEditing ? 'Contact details' : 'Emergency contact',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Add someone who should receive your emergency alerts.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 22),
              _ContactFieldShell(
                label: 'Name',
                child: TextFormField(
                  controller: nameController,
                  maxLength: AppValidators.maxDisplayNameLength,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => AppValidators.displayName(value ?? ''),
                  decoration: const InputDecoration(hintText: 'Full name'),
                ),
              ),
              const SizedBox(height: 12),
              _ContactFieldShell(
                label: 'Relationship',
                child: TextFormField(
                  controller: relationshipController,
                  maxLength: 30,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      AppValidators.relationship(value ?? '', required: true),
                  decoration: const InputDecoration(
                    hintText: 'Family, friend, caregiver',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              CountryPhoneField(
                controller: phoneController,
                dialCode: phoneDialCode,
                onDialCodeChanged: (value) =>
                    setState(() => phoneDialCode = value),
                labelText: 'Phone',
                externalLabels: true,
              ),
              const SizedBox(height: 6),
              const Text(
                'Maximum 5 contacts. Duplicate phone numbers are not allowed.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              if (widget.requirePhoneVerification)
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: phoneController,
                  builder: (context, value, child) {
                    return PhoneOtpVerificationCard(
                      phone: _normalizedPhone(),
                      purpose: PhoneVerificationPurpose.contactPhone,
                      onVerified: (phone) =>
                          setState(() => verifiedPhone = phone),
                    );
                  },
                ),
              const SizedBox(height: 16),
              _ContactFieldShell(
                label: 'Email',
                child: TextFormField(
                  key: const Key('contact-email-field'),
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  validator: (value) => AppValidators.email(value ?? ''),
                  decoration: const InputDecoration(
                    hintText: 'trusted.contact@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              MalaysiaAddressFields(
                addressController: addressController,
                selectedState: selectedState,
                selectedRegion: selectedRegion,
                onStateChanged: (value) => setState(() {
                  selectedState = value;
                  selectedRegion = null;
                }),
                onRegionChanged: (value) =>
                    setState(() => selectedRegion = value),
                addressRequired: true,
                externalLabels: true,
                addressLabel: 'House / unit, street',
                addressHelperText: null,
                stateLabel: 'State',
                regionLabel: 'Region / district',
                regionHelperText: null,
                addressFieldKey: const Key('contact-address-field'),
              ),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: isPrimary,
                onChanged: isEditing && isPrimary
                    ? null
                    : (value) => setState(() => isPrimary = value),
                title: const Text(
                  'Primary emergency contact',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'This person is prioritized for emergency alerts.',
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _submit,
                child: Text(isEditing ? 'Update' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactFieldShell extends StatelessWidget {
  const _ContactFieldShell({required this.label, required this.child});

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
