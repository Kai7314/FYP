import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../services/contact_service.dart';
import '../../../services/user_service.dart';
import '../../../utils/validators.dart';
import '../../widgets/error_dialog.dart';

class PrimaryContactSetupScreen extends StatefulWidget {
  const PrimaryContactSetupScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<PrimaryContactSetupScreen> createState() =>
      _PrimaryContactSetupScreenState();
}

class _PrimaryContactSetupScreenState extends State<PrimaryContactSetupScreen> {
  final formKey = GlobalKey<FormState>();
  final contactService = ContactService();
  final userService = UserService();
  final nameController = TextEditingController();
  final relationshipController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  late Future<List<Map<String, dynamic>>> contactsFuture;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    contactsFuture = contactService.getContacts(forceRefresh: true);
  }

  @override
  void dispose() {
    nameController.dispose();
    relationshipController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false) || saving) return;
    setState(() => saving = true);
    try {
      await contactService.addContact(
        name: AppValidators.normalizeSpaces(nameController.text),
        relationship: AppValidators.normalizeSpaces(
          relationshipController.text,
        ),
        phone: AppValidators.normalizePhone(phoneController.text),
        address: AppValidators.normalizeSpaces(addressController.text),
        isPrimary: true,
      );
      if (mounted) widget.onComplete();
    } catch (error) {
      if (mounted) {
        AppErrorDialog.show(
          context,
          title: 'Could not save primary contact',
          error: error,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _setPrimary(Map<String, dynamic> row) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await contactService.setPrimaryContact(row);
      if (mounted) widget.onComplete();
    } catch (error) {
      if (mounted) {
        AppErrorDialog.show(
          context,
          title: 'Could not set primary contact',
          error: error,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
          children: [
            const Text(
              'Add Primary Emergency Contact',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'EthernaCare needs one trusted person before SOS and safety follow-up can work.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: const Row(
                  children: [
                    Icon(Icons.star_rounded, color: AppColors.primary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This contact will be marked as your primary emergency contact and prioritized during SOS alerts.',
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: contactsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final contacts = snapshot.data ?? const <Map<String, dynamic>>[];
                if (contacts.isNotEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final contact in contacts)
                        Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.person_outline,
                              color: AppColors.primary,
                            ),
                            title: Text(
                              contact['name']?.toString() ?? 'Unnamed contact',
                            ),
                            subtitle: Text(
                              '${contact['relationship'] ?? 'Trusted contact'} - ${contact['phone'] ?? 'No phone'}',
                            ),
                            trailing: FilledButton(
                              onPressed: saving
                                  ? null
                                  : () => _setPrimary(contact),
                              child: const Text('Set Primary'),
                            ),
                          ),
                        ),
                    ],
                  );
                }
                return _NewPrimaryContactForm(
                  formKey: formKey,
                  nameController: nameController,
                  relationshipController: relationshipController,
                  phoneController: phoneController,
                  addressController: addressController,
                );
              },
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: contactsFuture,
              builder: (context, snapshot) {
                final contacts = snapshot.data ?? const <Map<String, dynamic>>[];
                if (contacts.isNotEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: FilledButton.icon(
                    onPressed: saving ? null : _save,
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      saving ? 'Saving...' : 'Save Primary Contact',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                );
              },
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: contactsFuture,
              builder: (context, snapshot) {
                final contacts = snapshot.data ?? const <Map<String, dynamic>>[];
                if (contacts.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: OutlinedButton.icon(
                    onPressed: saving
                        ? null
                        : () => setState(() {
                            contactsFuture = Future.value(
                              const <Map<String, dynamic>>[],
                            );
                          }),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Add New Contact Instead'),
                  ),
                );
              },
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

class _NewPrimaryContactForm extends StatelessWidget {
  const _NewPrimaryContactForm({
    required this.formKey,
    required this.nameController,
    required this.relationshipController,
    required this.phoneController,
    required this.addressController,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController relationshipController;
  final TextEditingController phoneController;
  final TextEditingController addressController;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: nameController,
            maxLength: AppValidators.maxDisplayNameLength,
            textCapitalization: TextCapitalization.words,
            validator: (value) => AppValidators.displayName(value ?? ''),
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: relationshipController,
            maxLength: 30,
            textCapitalization: TextCapitalization.words,
            validator: (value) =>
                AppValidators.relationship(value ?? '', required: true),
            decoration: const InputDecoration(labelText: 'Relationship'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            validator: (value) => AppValidators.phone(value ?? ''),
            decoration: const InputDecoration(labelText: 'Phone number'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: addressController,
            maxLength: AppValidators.maxAddressLength,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            validator: (value) =>
                AppValidators.address(value ?? '', required: true),
            decoration: const InputDecoration(labelText: 'Address'),
          ),
        ],
      ),
    );
  }
}
