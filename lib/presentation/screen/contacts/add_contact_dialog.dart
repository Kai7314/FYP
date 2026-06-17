import 'package:flutter/material.dart';

class AddContactDialog extends StatefulWidget {
  const AddContactDialog({super.key});

  @override
  State<AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<AddContactDialog> {
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
    if (nameController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty) {
      return;
    }

    Navigator.of(context).pop({
      'name': nameController.text.trim(),
      'relationship': relationshipController.text.trim().isEmpty
          ? 'Trusted contact'
          : relationshipController.text.trim(),
      'phone': phoneController.text.trim(),
      'address': addressController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Emergency Contact'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: relationshipController,
              decoration: const InputDecoration(labelText: 'Relationship'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone number'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
          ],
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
