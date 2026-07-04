import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../widgets/error_dialog.dart';
import '../../widgets/premium_shell.dart';
import '../../../services/contact_service.dart';
import 'add_contact_dialog.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final contactService = ContactService();
  late Future<List<Map<String, dynamic>>> contactsFuture;

  @override
  void initState() {
    super.initState();
    contactsFuture = _loadContacts();
  }

  Future<List<Map<String, dynamic>>> _loadContacts() async {
    return contactService.getContacts();
  }

  Future<void> _addContact() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const AddContactDialog(),
    );
    if (result == null) return;

    try {
      await contactService.addContact(
        name: result['name']!,
        relationship: result['relationship']!,
        phone: result['phone']!,
        address: result['address'],
        isPrimary: result['is_primary'] == true,
      );
      if (mounted) {
        setState(() => contactsFuture = _loadContacts());
        _showMessage('Emergency contact added.');
      }
    } catch (error) {
      if (mounted) {
        AppErrorDialog.show(
          context,
          title: 'Could not add contact',
          error: error,
        );
      }
    }
  }

  Future<void> _setPrimaryContact(Map<String, dynamic> row) async {
    try {
      await contactService.setPrimaryContact(row);
      if (mounted) {
        setState(() => contactsFuture = _loadContacts());
        _showMessage('${row['name'] ?? 'Contact'} set as primary.');
      }
    } catch (error) {
      if (mounted) {
        AppErrorDialog.show(
          context,
          title: 'Could not set primary contact',
          error: error,
        );
      }
    }
  }

  Future<void> _deleteContact(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete emergency contact?'),
        content: Text(
          '${row['name'] ?? 'This contact'} will no longer receive emergency alerts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await contactService.deleteContact(row);
      if (mounted) {
        setState(() => contactsFuture = _loadContacts());
        _showMessage('Emergency contact deleted.');
      }
    } catch (error) {
      if (mounted) {
        AppErrorDialog.show(
          context,
          title: 'Could not delete contact',
          error: error,
        );
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = MediaQuery.sizeOf(context).width < 360 ? 14.0 : 20.0;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: contactsFuture,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? [];
        return ListView(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 24),
          children: [
            PremiumHeader(
              title: 'Emergency Contacts',
              subtitle: 'People notified in emergencies',
              action: IconButton.filled(
                  onPressed: _addContact,
                  icon: const Icon(Icons.person_add_alt_1),
                  tooltip: 'Add contact',
                ),
            ),
            const SizedBox(height: 18),
            GlassPanel(
              padding: const EdgeInsets.all(14),
              color: AppColors.primarySoft,
              borderColor: AppColors.primary,
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'These are the trusted contacts linked to your emergency records and location updates.',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (snapshot.hasError)
              const GlassPanel(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Unable to load contacts. Check your connection and try again.',
                  style: TextStyle(color: AppColors.danger),
                ),
              )
            else if (rows.isEmpty)
              const GlassPanel(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No contacts yet. Add at least one family member or caregiver.',
                ),
              )
            else
              ...rows.map(
                (row) => _ContactCard(
                  row: row,
                  onDelete: () => _deleteContact(row),
                  onSetPrimary: () => _setPrimaryContact(row),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.row,
    required this.onDelete,
    required this.onSetPrimary,
  });

  final Map<String, dynamic> row;
  final VoidCallback onDelete;
  final VoidCallback onSetPrimary;

  @override
  Widget build(BuildContext context) {
    final name = row['name']?.toString() ?? 'Unnamed';
    final isPrimary = row['is_primary'] == true;
    final color = row['color'] is Color
        ? row['color'] as Color
        : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanel(
        color: isPrimary ? AppColors.primarySoft : AppColors.glassStrong,
        borderColor: isPrimary
            ? AppColors.primary.withValues(alpha: .38)
            : AppColors.border,
        child: Padding(
          padding: EdgeInsets.zero,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: color,
                foregroundColor: Colors.white,
                child: Text(
                  name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (isPrimary) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: AppColors.primaryDark,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Primary contact',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.primaryDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Text(
                      row['relationship']?.toString() ?? 'Trusted contact',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_outlined,
                          size: 14,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            row['phone']?.toString() ?? 'No phone',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              row['address']?.toString() ?? 'No address',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isPrimary)
                    IconButton(
                      onPressed: onSetPrimary,
                      icon: const Icon(Icons.star_border_rounded),
                      color: AppColors.primary,
                      tooltip: 'Set as primary',
                    ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.muted,
                    tooltip: 'Delete contact',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
