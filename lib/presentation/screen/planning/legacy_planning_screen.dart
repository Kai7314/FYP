import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/colors.dart';
import '../../../models/document_model.dart';
import '../../../models/legacy_note_model.dart';
import '../../../services/contact_service.dart';
import '../../../services/document_service.dart';
import '../../../services/legacy_server_test_service.dart';
import '../../../utils/validators.dart';
import '../../widgets/error_dialog.dart';
import '../../widgets/guidance_sheet.dart';
import 'funeral_preferences_editor_screen.dart';

class LegacyPlanningScreen extends StatefulWidget {
  const LegacyPlanningScreen({super.key});

  @override
  State<LegacyPlanningScreen> createState() => _LegacyPlanningScreenState();
}

class _LegacyPlanningScreenState extends State<LegacyPlanningScreen> {
  final service = DocumentService();
  final contactService = ContactService();
  late Future<LegacyPlanningSnapshot> future;
  bool isUploadingDocument = false;
  bool isUpdatingLegacyAccess = false;
  bool isUpdatingLegacyTestingAccess = false;
  String? busyDocumentId;

  @override
  void initState() {
    super.initState();
    future = service.load();
  }

  void _refresh() {
    setState(() {
      future = service.load();
    });
  }

  Future<void> _edit(FuneralPreferences preferences) async {
    List<Map<String, dynamic>> contacts;
    try {
      contacts = await contactService.getContacts(forceRefresh: true);
    } catch (error) {
      try {
        contacts = await contactService.getContacts();
      } catch (_) {
        if (mounted) {
          await AppErrorDialog.show(
            context,
            title: 'Could not load trusted contacts',
            error: error,
          );
        }
        return;
      }
    }
    if (!mounted) return;

    final result = await Navigator.of(context).push<FuneralPreferences>(
      MaterialPageRoute(
        builder: (_) => FuneralPreferencesEditorScreen(
          preferences: preferences,
          contacts: contacts,
        ),
      ),
    );
    if (result == null) return;
    try {
      await service.savePreferences(result);
      if (mounted) _refresh();
    } catch (error) {
      if (mounted) {
        await AppErrorDialog.show(
          context,
          title: 'Could not save preferences',
          error: error,
        );
      }
    }
  }

  Future<void> _setLegacyAccessEnabled(bool enabled) async {
    if (isUpdatingLegacyAccess) return;
    setState(() => isUpdatingLegacyAccess = true);
    try {
      if (enabled) {
        await _requireVerifiedPrimaryContact();
      }

      await service.setLegacyAccessEnabled(enabled);
      if (!mounted) return;
      _refresh();
      _showMessage(
        enabled ? 'Legacy Checking enabled.' : 'Legacy Checking disabled.',
      );
    } catch (error) {
      if (mounted) {
        await AppErrorDialog.show(
          context,
          title: 'Could not update Legacy Checking',
          error: error,
        );
      }
    } finally {
      if (mounted) setState(() => isUpdatingLegacyAccess = false);
    }
  }

  Future<void> _setLegacyTestingAccessEnabled(bool enabled) async {
    if (isUpdatingLegacyTestingAccess) return;
    setState(() => isUpdatingLegacyTestingAccess = true);
    try {
      if (enabled) await _requireVerifiedPrimaryContact();
      await service.setLegacyTestingAccessEnabled(enabled);
      if (!mounted) return;
      _refresh();
      _showMessage(
        enabled
            ? 'Testing access enabled for this account.'
            : 'Testing access disabled.',
      );
    } catch (error) {
      if (mounted) {
        await AppErrorDialog.show(
          context,
          title: 'Could not update testing access',
          error: error,
        );
      }
    } finally {
      if (mounted) setState(() => isUpdatingLegacyTestingAccess = false);
    }
  }

  Future<void> _requireVerifiedPrimaryContact() async {
    final contacts = await contactService.getContacts(forceRefresh: true);
    Map<String, dynamic>? primaryContact;
    for (final contact in contacts) {
      if (contact['is_primary'] == true) {
        primaryContact = contact;
        break;
      }
    }
    if (primaryContact == null) {
      throw StateError(
        'Add a primary trusted contact before enabling Legacy Checking.',
      );
    }
    if (primaryContact['phone_verified_at'] == null) {
      throw StateError(
        'Verify the primary contact phone number before enabling Legacy Checking.',
      );
    }
    if (AppValidators.email(primaryContact['email']?.toString() ?? '') !=
        null) {
      throw StateError(
        'Add a valid email to the primary trusted contact before enabling Legacy Checking.',
      );
    }
  }

  Future<void> _addNote() async {
    final result = await showDialog<_LegacyNoteDraft>(
      context: context,
      builder: (_) => const _LegacyNoteDialog(),
    );
    if (result == null) return;
    try {
      await service.createNote(title: result.title, content: result.content);
      if (mounted) _refresh();
    } catch (error) {
      if (mounted) {
        await AppErrorDialog.show(
          context,
          title: 'Could not add note',
          error: error,
        );
      }
    }
  }

  Future<void> _editNote(LegacyNote note) async {
    final result = await showDialog<_LegacyNoteDraft>(
      context: context,
      builder: (_) => _LegacyNoteDialog(note: note),
    );
    if (result == null) return;
    try {
      await service.updateNote(
        note.copyWith(title: result.title, content: result.content),
      );
      if (mounted) _refresh();
    } catch (error) {
      if (mounted) {
        await AppErrorDialog.show(
          context,
          title: 'Could not update note',
          error: error,
        );
      }
    }
  }

  Future<void> _deleteNote(LegacyNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text('This will permanently delete "${note.title}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await service.deleteNote(note);
      if (mounted) _refresh();
    } catch (error) {
      if (mounted) {
        await AppErrorDialog.show(
          context,
          title: 'Could not delete note',
          error: error,
        );
      }
    }
  }

  Future<void> _upload() async {
    if (isUploadingDocument) return;
    setState(() => isUploadingDocument = true);
    try {
      final uploaded = await service.pickAndUploadDocument();
      if (uploaded && mounted) {
        _refresh();
        _showMessage('Document uploaded securely.');
      }
    } catch (error) {
      if (mounted) {
        await AppErrorDialog.show(
          context,
          title: 'Could not upload document',
          error: error,
        );
      }
    } finally {
      if (mounted) setState(() => isUploadingDocument = false);
    }
  }

  Future<void> _openDocument(LegacyDocument document) async {
    if (busyDocumentId != null) return;
    setState(() => busyDocumentId = document.id);
    try {
      await service.openDocument(document);
    } catch (error) {
      if (mounted) {
        await AppErrorDialog.show(
          context,
          title: 'Could not open document',
          error: error,
        );
      }
    } finally {
      if (mounted) setState(() => busyDocumentId = null);
    }
  }

  Future<void> _deleteDocument(LegacyDocument document) async {
    if (busyDocumentId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete secure document?'),
        content: Text(
          'This permanently removes "${document.name}" from secure storage.',
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
    if (confirmed != true || !mounted) return;

    setState(() => busyDocumentId = document.id);
    try {
      await service.deleteDocument(document);
      if (!mounted) return;
      _refresh();
      _showMessage('Document deleted.');
    } catch (error) {
      if (mounted) {
        await AppErrorDialog.show(
          context,
          title: 'Could not delete document',
          error: error,
        );
      }
    } finally {
      if (mounted) setState(() => busyDocumentId = null);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _showGuide() {
    return GuidanceSheet.show(
      context,
      title: 'Legacy Planning Guide',
      description:
          'Use this private area to record wishes and documents, and choose whether your primary trusted contact may access selected information later.',
      items: const [
        GuidanceItem(
          icon: Icons.tune_outlined,
          title: 'Funeral Preferences',
          description:
              'Choose the religion, service type, venue, and an authorized person from your existing trusted contacts.',
        ),
        GuidanceItem(
          icon: Icons.sticky_note_2_outlined,
          title: 'Legacy Notes',
          description:
              'Save wishes or messages. Note content stays hidden until you reveal it. Never enter passwords, PINs, OTPs, recovery phrases, or security codes.',
          color: AppColors.purple,
        ),
        GuidanceItem(
          icon: Icons.lock_outline,
          title: 'Secure Documents',
          description:
              'Upload PDF, JPG, or PNG files up to 10 MB. They stay private until an authorized Legacy Check, which uses a short-lived secure link.',
          color: AppColors.blue,
        ),
        GuidanceItem(
          icon: Icons.verified_user_outlined,
          title: 'Legacy Checking',
          description:
              'After 90 days without a check-in, the server emails your SMS-verified primary contact and opens Legacy Checking for seven days.',
          color: AppColors.accent,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Legacy Planning'),
        actions: [
          IconButton(
            onPressed: _showGuide,
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Legacy Planning guide',
          ),
        ],
      ),
      body: FutureBuilder<LegacyPlanningSnapshot>(
        future: future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null &&
              snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _LoadError(
              message: AppErrorDialog.friendlyMessage(
                snapshot.error ?? 'Unknown error',
              ),
              onRetry: _refresh,
            );
          }
          final preferences = data!.preferences;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: SwitchListTile(
                  value: data.legacyAccessEnabled,
                  onChanged: isUpdatingLegacyAccess
                      ? null
                      : _setLegacyAccessEnabled,
                  secondary: isUpdatingLegacyAccess
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_user_outlined),
                  title: const Text(
                    'Legacy Checking',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'After 90 days without a check-in, your primary contact receives an email and can use Legacy Checking for seven days.',
                  ),
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 10),
                Card(
                  child: SwitchListTile(
                    value: data.legacyTestingAccessEnabled,
                    onChanged:
                        isUpdatingLegacyTestingAccess ||
                            !data.legacyAccessEnabled
                        ? null
                        : _setLegacyTestingAccessEnabled,
                    secondary: isUpdatingLegacyTestingAccess
                        ? const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.science_outlined,
                            color: AppColors.danger,
                          ),
                    title: const Text(
                      'Testing access',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      data.legacyAccessEnabled
                          ? 'For this account only, allow the verified primary phone and Legacy UID to skip SMS and the 90-day wait.'
                          : 'Enable Legacy Checking above before turning on account testing.',
                    ),
                  ),
                ),
                if (data.legacyTestingAccessEnabled) ...[
                  const SizedBox(height: 10),
                  const _LegacyServerTestPanel(),
                ],
              ],
              const SizedBox(height: 20),
              _SectionHeader(
                title: 'Funeral Preferences',
                action: IconButton(
                  onPressed: () => _edit(preferences),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit preferences',
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _PreferenceRow('Religion', preferences.religion),
                      _PreferenceRow('Service', preferences.serviceType),
                      _PreferenceRow('Venue', preferences.venue),
                      _PreferenceRow(
                        'Authorized contact',
                        preferences.authorizedContact,
                      ),
                      _PreferenceRow('Notes', preferences.notes),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _SectionHeader(
                title: 'Legacy Notes',
                action: IconButton.filled(
                  onPressed: _addNote,
                  icon: const Icon(Icons.add),
                  tooltip: 'Add note',
                ),
              ),
              const Text(
                'Save personal wishes, non-sensitive reminders, or messages for trusted contacts. Never store passwords or security codes.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              if (data.notes.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No legacy notes yet.'),
                  ),
                )
              else
                ...data.notes.map(
                  (note) => _LegacyNoteCard(
                    note: note,
                    onEdit: () => _editNote(note),
                    onDelete: () => _deleteNote(note),
                  ),
                ),
              const SizedBox(height: 20),
              _SectionHeader(
                title: 'Secure Documents',
                action: IconButton.filled(
                  onPressed: isUploadingDocument ? null : _upload,
                  icon: isUploadingDocument
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  tooltip: 'Upload document',
                ),
              ),
              const Text(
                'PDF or image, maximum 10 MB. Upload completed legal documents only.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              if (data.documents.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No documents uploaded yet.'),
                  ),
                )
              else
                ...data.documents.map((document) {
                  final isBusy = busyDocumentId == document.id;
                  return Card(
                    child: ListTile(
                      onTap: isBusy ? null : () => _openDocument(document),
                      leading: isBusy
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.description_outlined),
                      title: Text(
                        document.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${DateFormat('dd MMM yyyy, h:mm a').format(document.uploadedAt)}\nTap to open securely',
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        onPressed: isBusy
                            ? null
                            : () => _deleteDocument(document),
                        icon: const Icon(Icons.delete_outline),
                        color: AppColors.danger,
                        tooltip: 'Delete document',
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.danger),
                const SizedBox(height: 12),
                const Text(
                  'Unable to load planning data',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegacyServerTestPanel extends StatefulWidget {
  const _LegacyServerTestPanel();

  @override
  State<_LegacyServerTestPanel> createState() => _LegacyServerTestPanelState();
}

class _LegacyServerTestPanelState extends State<_LegacyServerTestPanel> {
  final service = LegacyServerTestService();
  String? activeAction;
  LegacyServerTestResult? result;

  Future<void> _run(String action) async {
    if (activeAction != null) return;
    final sendsEmail = {'day_90', 'day_91', 'test_email'}.contains(action);
    if (sendsEmail) {
      final ownerWarning = action == 'day_90';
      final day91Notice = action == 'day_91';
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.mark_email_read_outlined),
          title: Text(
            ownerWarning
                ? 'Send owner warning test?'
                : day91Notice
                ? 'Send primary contact test?'
                : 'Send test email?',
          ),
          content: Text(
            ownerWarning
                ? 'This sends a TEST ONLY day-90 warning to your account email and sets the isolated testing timeline to Day 90. The primary contact is not emailed, and the real heartbeat does not change.'
                : day91Notice
                ? 'This sends a TEST ONLY post-grace notice to the real primary contact and sets the isolated testing timeline to Day 91. It does not change the real heartbeat.'
                : 'This sends a TEST ONLY email to the real primary contact. It does not change heartbeat or Legacy access.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send Test'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
    }

    setState(() {
      activeAction = action;
      result = null;
    });
    try {
      final testResult = await service.run(action);
      if (mounted) setState(() => result = testResult);
    } catch (error) {
      if (mounted) {
        await AppErrorDialog.show(
          context,
          title: 'Legacy server test failed',
          error: error,
        );
      }
    } finally {
      if (mounted) setState(() => activeAction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    const tests = [
      ('live_status', Icons.monitor_heart_outlined, 'Restore Live Timeline'),
      ('day_89', Icons.hourglass_bottom, 'Test Day 89'),
      (
        'day_90',
        Icons.notifications_active_outlined,
        'Test Day 90 Owner Email',
      ),
      ('day_91', Icons.mark_email_read_outlined, 'Test Day 91 Contact Email'),
      ('day_97', Icons.event_busy_outlined, 'Test Day 97'),
      ('day_98', Icons.event_busy_outlined, 'Test Day 98'),
      ('test_email', Icons.outgoing_mail, 'Send Test Email'),
    ];
    final testResult = result;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.dns_outlined, color: AppColors.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Legacy Server Tests',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Day buttons set the isolated timeline used by Legacy Check Testing mode. Day 90 emails the owner, Day 91 emails the primary contact, and Restore Live Timeline returns to real heartbeat status.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final buttonWidth = constraints.maxWidth < 440
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final test in tests)
                      SizedBox(
                        width: buttonWidth,
                        child: OutlinedButton.icon(
                          onPressed: activeAction == null
                              ? () => _run(test.$1)
                              : null,
                          icon: activeAction == test.$1
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(test.$2),
                          label: Text(test.$3),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (testResult != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: testResult.ok
                      ? AppColors.primarySoft
                      : AppColors.danger.withValues(alpha: 0.08),
                  border: Border.all(
                    color: testResult.ok ? AppColors.primary : AppColors.danger,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      testResult.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(testResult.message),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action});

  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ),
        action,
      ],
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(value.isEmpty ? 'Not provided' : value),
    );
  }
}

class _LegacyNoteCard extends StatefulWidget {
  const _LegacyNoteCard({
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  final LegacyNote note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_LegacyNoteCard> createState() => _LegacyNoteCardState();
}

class _LegacyNoteCardState extends State<_LegacyNoteCard>
    with WidgetsBindingObserver {
  bool contentVisible = false;
  Timer? hideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    hideTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _hideContent();
  }

  void _toggleContent() {
    hideTimer?.cancel();
    setState(() => contentVisible = !contentVisible);
    if (contentVisible) {
      hideTimer = Timer(const Duration(seconds: 30), _hideContent);
    }
  }

  void _hideContent() {
    hideTimer?.cancel();
    if (!mounted || !contentVisible) return;
    setState(() => contentVisible = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 3),
              child: Icon(Icons.sticky_note_2_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.note.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (contentVisible)
                    Text(
                      widget.note.content,
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    const Row(
                      children: [
                        Icon(
                          Icons.visibility_off_outlined,
                          size: 16,
                          color: AppColors.muted,
                        ),
                        SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Content hidden for privacy',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Updated ${DateFormat('dd MMM yyyy, h:mm a').format(widget.note.updatedAt)}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _toggleContent,
                  icon: Icon(
                    contentVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  tooltip: contentVisible
                      ? 'Hide private note'
                      : 'Reveal private note',
                ),
                IconButton(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit note',
                ),
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.danger,
                  tooltip: 'Delete note',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegacyNoteDraft {
  const _LegacyNoteDraft({required this.title, required this.content});

  final String title;
  final String content;
}

class _LegacyNoteDialog extends StatefulWidget {
  const _LegacyNoteDialog({this.note});

  final LegacyNote? note;

  @override
  State<_LegacyNoteDialog> createState() => _LegacyNoteDialogState();
}

class _LegacyNoteDialogState extends State<_LegacyNoteDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController contentController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.note?.title ?? '');
    contentController = TextEditingController(text: widget.note?.content ?? '');
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.note == null ? 'Add Legacy Note' : 'Edit Legacy Note'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                maxLength: 80,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.length < 2) return 'Enter at least 2 characters.';
                  if (text.length > 80) {
                    return 'Title must not exceed 80 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: contentController,
                maxLength: 1000,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Note'),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.length < 2) return 'Enter at least 2 characters.';
                  if (text.length > 1000) {
                    return 'Note must not exceed 1000 characters.';
                  }
                  return DocumentService.legacyNoteSecurityWarning(
                    title: titleController.text.trim(),
                    content: text,
                  );
                },
              ),
              const SizedBox(height: 4),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 17, color: AppColors.muted),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Never store passwords, PINs, OTPs, recovery phrases, API keys, or security codes here.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              _LegacyNoteDraft(
                title: titleController.text.trim(),
                content: contentController.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
