import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/colors.dart';
import '../../widgets/error_dialog.dart';
import '../../widgets/premium_shell.dart';
import '../../../services/contact_service.dart';
import 'add_contact_dialog.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, this.scrollController});

  final ScrollController? scrollController;

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

  Future<List<Map<String, dynamic>>> _loadContacts({
    bool forceRefresh = false,
  }) async {
    return contactService.getContacts(forceRefresh: forceRefresh);
  }

  Future<void> _addContact() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const AddContactPage()),
    );
    if (result == null) return;

    final phone = result['phone']?.toString() ?? '';
    try {
      await contactService.addContact(
        name: result['name']!,
        relationship: result['relationship']!,
        phone: result['phone']!,
        email: result['email']!,
        address: result['address'],
        addressState: result['address_state'],
        addressRegion: result['address_region'],
        isPrimary: result['is_primary'] == true,
      );
      await _refreshContacts();
      if (!mounted) return;
      _showMessage('Emergency contact added.');
    } catch (error) {
      final added = await _refreshAndCheck(
        (rows) => _containsPhone(rows, phone),
      );
      if (added) {
        if (!mounted) return;
        _showMessage('Emergency contact added.');
        return;
      }
      if (mounted) {
        AppErrorDialog.show(
          context,
          title: 'Could not add contact',
          error: error,
        );
      }
    }
  }

  Future<void> _editContact(Map<String, dynamic> row) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => AddContactPage(initialContact: row),
      ),
    );
    if (result == null) return;

    try {
      await contactService.updateContact(
        row: row,
        name: result['name']?.toString() ?? '',
        relationship: result['relationship']?.toString() ?? '',
        phone: result['phone']?.toString() ?? '',
        email: result['email']?.toString() ?? '',
        address: result['address']?.toString() ?? '',
        addressState: result['address_state']?.toString() ?? '',
        addressRegion: result['address_region']?.toString() ?? '',
        isPrimary: result['is_primary'] == true,
      );
      await _refreshContacts();
      if (!mounted) return;
      _showMessage('Emergency contact updated.');
    } catch (error) {
      if (mounted) {
        AppErrorDialog.show(
          context,
          title: 'Could not update contact',
          error: error,
        );
      }
    }
  }

  Future<void> _setPrimaryContact(Map<String, dynamic> row) async {
    try {
      await contactService.setPrimaryContact(row);
      await _refreshContacts();
      if (!mounted) return;
      _showMessage('${row['name'] ?? 'Contact'} set as primary.');
    } catch (error) {
      final updated = await _refreshAndCheck(
        (rows) => _rowIsPrimary(rows, row),
      );
      if (updated) {
        if (!mounted) return;
        _showMessage('${row['name'] ?? 'Contact'} set as primary.');
        return;
      }
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
      await _refreshContacts();
      if (!mounted) return;
      _showMessage('Emergency contact deleted.');
    } catch (error) {
      final deleted = await _refreshAndCheck(
        (rows) => !_containsRow(rows, row),
      );
      if (deleted) {
        if (!mounted) return;
        _showMessage('Emergency contact deleted.');
        return;
      }
      if (mounted) {
        AppErrorDialog.show(
          context,
          title: 'Could not delete contact',
          error: error,
        );
      }
    }
  }

  Future<void> _callContact(Map<String, dynamic> row) async {
    final phone = row['phone']?.toString() ?? '';
    final normalizedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (normalizedPhone.isEmpty) {
      _showMessage('This contact does not have a valid phone number.');
      return;
    }

    try {
      final launched = await launchUrl(
        Uri(scheme: 'tel', path: normalizedPhone),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError('The phone app could not be opened.');
      }
    } catch (error) {
      if (!mounted) return;
      AppErrorDialog.show(context, title: 'Could not start call', error: error);
    }
  }

  Future<List<Map<String, dynamic>>> _refreshContacts() async {
    final rows = await _loadContacts(forceRefresh: true);
    if (mounted) {
      setState(() {
        contactsFuture = Future.value(rows);
      });
    }
    return rows;
  }

  Future<bool> _refreshAndCheck(
    bool Function(List<Map<String, dynamic>> rows) predicate,
  ) async {
    try {
      final rows = await _refreshContacts();
      return predicate(rows);
    } catch (_) {
      return false;
    }
  }

  bool _containsPhone(List<Map<String, dynamic>> rows, String phone) {
    final digits = _digits(phone);
    if (digits.isEmpty) return false;
    return rows.any((row) => _digits(row['phone']) == digits);
  }

  bool _containsRow(
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> target,
  ) {
    final targetId = target['id'] ?? target['contact_id'];
    if (targetId != null) {
      return rows.any(
        (row) =>
            (row['id'] ?? row['contact_id'])?.toString() == targetId.toString(),
      );
    }

    final targetPhone = _digits(target['phone']);
    if (targetPhone.isNotEmpty) {
      return rows.any((row) => _digits(row['phone']) == targetPhone);
    }

    final targetName = target['name']?.toString();
    return targetName != null &&
        rows.any((row) => row['name']?.toString() == targetName);
  }

  bool _rowIsPrimary(
    List<Map<String, dynamic>> rows,
    Map<String, dynamic> target,
  ) {
    final targetId = target['id'] ?? target['contact_id'];
    final targetPhone = _digits(target['phone']);
    return rows.any((row) {
      if (row['is_primary'] != true) return false;
      if (targetId != null) {
        return (row['id'] ?? row['contact_id'])?.toString() ==
            targetId.toString();
      }
      return targetPhone.isNotEmpty && _digits(row['phone']) == targetPhone;
    });
  }

  String _digits(Object? value) {
    return value?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = MediaQuery.sizeOf(context).width < 360
        ? 14.0
        : 20.0;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: contactsFuture,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? [];
        return ListView(
          controller: widget.scrollController,
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            24,
          ),
          children: [
            PremiumHeader(
              title: 'Emergency Contacts',
              subtitle:
                  'Oren can help you call a trusted contact whenever you need support.',
              orenAsset:
                  'lib/assets/images/pixel/oren_pixel_phone_call_transparent.png',
              orenSemanticLabel: 'Oren holding a phone',
              action: IconButton.filled(
                onPressed: _addContact,
                icon: const Icon(Icons.person_add_alt_1),
                tooltip: 'Add contact',
              ),
            ),
            const SizedBox(height: 14),
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
                      'Your primary contact receives inactivity and SOS alerts.',
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
                  onCall: () => _callContact(row),
                  onEdit: () => _editContact(row),
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
    required this.onCall,
    required this.onEdit,
    required this.onDelete,
    required this.onSetPrimary,
  });

  final Map<String, dynamic> row;
  final VoidCallback onCall;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSetPrimary;

  @override
  Widget build(BuildContext context) {
    final name = row['name']?.toString() ?? 'Unnamed';
    final isPrimary = row['is_primary'] == true;
    final address = _addressText(row);
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
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          size: 14,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            row['email']?.toString().trim().isNotEmpty == true
                                ? row['email'].toString()
                                : 'Email required for Legacy Checking',
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
                              address,
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
                  IconButton(
                    onPressed: onCall,
                    icon: const Icon(Icons.call_outlined),
                    color: AppColors.primary,
                    tooltip: 'Call contact',
                  ),
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    color: AppColors.primary,
                    tooltip: 'Edit contact',
                  ),
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

  String _addressText(Map<String, dynamic> row) {
    final address = row['address']?.toString().trim() ?? '';
    final region = row['address_region']?.toString().trim() ?? '';
    final state = row['address_state']?.toString().trim() ?? '';
    final parts = [
      if (address.isNotEmpty) address,
      if (region.isNotEmpty) region,
      if (state.isNotEmpty) state,
    ];
    return parts.isEmpty ? 'No address' : parts.join(', ');
  }
}
