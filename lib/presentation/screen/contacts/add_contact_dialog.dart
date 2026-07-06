import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../utils/validators.dart';
import '../../widgets/country_phone_field.dart';
import '../../widgets/malaysia_address_fields.dart';

class AddContactPage extends StatefulWidget {
  const AddContactPage({super.key});

  @override
  State<AddContactPage> createState() => _AddContactPageState();
}

class AddContactDialog extends AddContactPage {
  const AddContactDialog({super.key});
}

class _AddContactPageState extends State<AddContactPage> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final relationshipController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  String phoneDialCode = AppValidators.defaultPhoneCountry.dialCode;
  String? selectedState = 'Kuala Lumpur';
  String? selectedRegion = 'Kuala Lumpur';
  bool isPrimary = false;

  @override
  void dispose() {
    nameController.dispose();
    relationshipController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(formKey.currentState?.validate() ?? false)) return;

    Navigator.of(context).pop({
      'name': AppValidators.normalizeSpaces(nameController.text),
      'relationship': AppValidators.normalizeSpaces(relationshipController.text),
      'phone': AppValidators.normalizePhoneWithCountry(
        phoneController.text,
        phoneDialCode,
      ),
      'address': AppValidators.normalizeSpaces(addressController.text),
      'address_state': selectedState,
      'address_region': selectedRegion,
      'is_primary': isPrimary,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Contact')),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              const Text(
                'Emergency contact',
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
              ),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: isPrimary,
                onChanged: (value) => setState(() => isPrimary = value),
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
                child: const Text('Save'),
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
