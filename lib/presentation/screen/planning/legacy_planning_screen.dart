import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/colors.dart';
import '../../../models/document_model.dart';
import '../../../models/legacy_note_model.dart';
import '../../../services/document_service.dart';
import '../../widgets/error_dialog.dart';

class LegacyPlanningScreen extends StatefulWidget {
  const LegacyPlanningScreen({super.key});

  @override
  State<LegacyPlanningScreen> createState() => _LegacyPlanningScreenState();
}

class _LegacyPlanningScreenState extends State<LegacyPlanningScreen> {
  final service = DocumentService();
  late Future<LegacyPlanningSnapshot> future;

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
    final result = await showDialog<FuneralPreferences>(
      context: context,
      builder: (_) => _PreferencesDialog(preferences: preferences),
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
    try {
      final uploaded = await service.pickAndUploadDocument();
      if (uploaded && mounted) _refresh();
    } catch (error) {
      if (mounted) {
        await AppErrorDialog.show(
          context,
          title: 'Could not upload document',
          error: error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legacy Planning')),
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
                'Save personal wishes, reminders, account instructions, or messages for trusted contacts.',
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
                  onPressed: _upload,
                  icon: const Icon(Icons.upload_file),
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
                ...data.documents.map(
                  (document) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(document.name),
                      subtitle: Text(
                        DateFormat(
                          'dd MMM yyyy, h:mm a',
                        ).format(document.uploadedAt),
                      ),
                      trailing: IconButton(
                        onPressed: () async {
                          await service.deleteDocument(document);
                          _refresh();
                        },
                        icon: const Icon(Icons.delete_outline),
                        color: AppColors.danger,
                        tooltip: 'Delete document',
                      ),
                    ),
                  ),
                ),
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

class _LegacyNoteCard extends StatelessWidget {
  const _LegacyNoteCard({
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  final LegacyNote note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
                    note.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    note.content,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Updated ${DateFormat('dd MMM yyyy, h:mm a').format(note.updatedAt)}',
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
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit note',
                ),
                IconButton(
                  onPressed: onDelete,
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

class _PreferencesDialog extends StatefulWidget {
  const _PreferencesDialog({required this.preferences});
  final FuneralPreferences preferences;

  @override
  State<_PreferencesDialog> createState() => _PreferencesDialogState();
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
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.length < 2) return 'Enter at least 2 characters.';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: contentController,
                maxLength: 1000,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Note'),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.length < 2) return 'Enter at least 2 characters.';
                  return null;
                },
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

class _PreferencesDialogState extends State<_PreferencesDialog> {
  late final List<TextEditingController> controllers;

  @override
  void initState() {
    super.initState();
    controllers = [
      TextEditingController(text: widget.preferences.religion),
      TextEditingController(text: widget.preferences.serviceType),
      TextEditingController(text: widget.preferences.venue),
      TextEditingController(text: widget.preferences.authorizedContact),
      TextEditingController(text: widget.preferences.notes),
    ];
  }

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Religion',
      'Service type',
      'Venue',
      'Authorized contact',
      'Notes',
    ];
    return AlertDialog(
      title: const Text('Edit Funeral Preferences'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            controllers.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: controllers[index],
                maxLength: index == 4 ? 500 : 100,
                maxLines: index == 4 ? 4 : 1,
                decoration: InputDecoration(labelText: labels[index]),
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            FuneralPreferences(
              religion: controllers[0].text.trim(),
              serviceType: controllers[1].text.trim(),
              venue: controllers[2].text.trim(),
              authorizedContact: controllers[3].text.trim(),
              notes: controllers[4].text.trim(),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
