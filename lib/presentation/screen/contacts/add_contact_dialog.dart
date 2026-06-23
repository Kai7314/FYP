import 'package:flutter/material.dart';

import '../../../utils/validators.dart';

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
      'relationship': relationshipController.text.trim().isEmpty
          ? 'Trusted contact'
          : AppValidators.normalizeSpaces(relationshipController.text),
      'phone': AppValidators.normalizePhone(phoneController.text),
      'address': AppValidators.normalizeSpaces(addressController.text),
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
                validator: (value) => AppValidators.relationship(value ?? ''),
                decoration: const InputDecoration(labelText: 'Relationship'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                validator: (value) => AppValidators.phone(value ?? ''),
                decoration: const InputDecoration(labelText: 'Phone number'),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Maximum 5 contacts. Duplicate phone numbers are not allowed.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: addressController,
                maxLength: AppValidators.maxAddressLength,
                maxLines: 2,
                validator: (value) => AppValidators.address(value ?? ''),
                decoration: const InputDecoration(labelText: 'Address'),
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
