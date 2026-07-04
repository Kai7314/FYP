import 'package:flutter/material.dart';

import '../../../utils/validators.dart';
import '../../widgets/country_phone_field.dart';
import '../../widgets/malaysia_address_fields.dart';

class AddContactDialog extends StatefulWidget {
  const AddContactDialog({super.key});

  @override
  State<AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<AddContactDialog> {
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
    return AlertDialog(
      title: const Text('Add Emergency Contact'),
      icon: const Icon(Icons.person_add_alt_1),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                maxLength: AppValidators.maxDisplayNameLength,
                textCapitalization: TextCapitalization.words,
                validator: (value) => AppValidators.displayName(value ?? ''),
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: relationshipController,
                maxLength: 30,
                textCapitalization: TextCapitalization.words,
                validator: (value) =>
                    AppValidators.relationship(value ?? '', required: true),
                decoration: const InputDecoration(labelText: 'Relationship'),
              ),
              const SizedBox(height: 12),
              CountryPhoneField(
                controller: phoneController,
                dialCode: phoneDialCode,
                onDialCodeChanged: (value) =>
                    setState(() => phoneDialCode = value),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Maximum 5 contacts. Duplicate phone numbers are not allowed.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ),
              const SizedBox(height: 12),
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
                addressLabel: 'Contact address',
                addressHelperText: 'House/unit, street, building, or landmark',
                regionHelperText: 'Used for contact location context',
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: isPrimary,
                onChanged: (value) => setState(() => isPrimary = value),
                title: const Text('Primary emergency contact'),
                subtitle: const Text(
                  'This person is prioritized for emergency alerts.',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
