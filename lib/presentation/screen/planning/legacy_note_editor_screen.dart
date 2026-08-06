import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/colors.dart';
import '../../../models/legacy_note_model.dart';
import '../../../services/document_service.dart';

class LegacyNoteDraft {
  const LegacyNoteDraft({required this.title, required this.content});

  final String title;
  final String content;
}

class LegacyNoteEditorScreen extends StatefulWidget {
  const LegacyNoteEditorScreen({super.key, this.note});

  final LegacyNote? note;

  @override
  State<LegacyNoteEditorScreen> createState() =>
      _LegacyNoteEditorScreenState();
}

class _LegacyNoteEditorScreenState extends State<LegacyNoteEditorScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController contentController;

  bool get isEditing => widget.note != null;

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

  void _save() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      LegacyNoteDraft(
        title: titleController.text.trim(),
        content: contentController.text.trim(),
      ),
    );
  }

  String? _validateTitle(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 2) return 'Enter at least 2 characters.';
    if (text.length > 80) {
      return 'Title must not exceed 80 characters.';
    }
    return null;
  }

  String? _validateContent(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 2) return 'Enter at least 2 characters.';
    if (text.length > 1000) {
      return 'Note must not exceed 1000 characters.';
    }
    return DocumentService.legacyNoteSecurityWarning(
      title: titleController.text.trim(),
      content: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Legacy Note' : 'Add Legacy Note'),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.edit_note_outlined,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Private message',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Write a personal wish, reminder, or message for your trusted contact.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const Key('legacy-note-title-field'),
                      controller: titleController,
                      maxLength: 80,
                      maxLengthEnforcement: MaxLengthEnforcement.none,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'Give this note a clear title',
                      ),
                      validator: _validateTitle,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      key: const Key('legacy-note-content-field'),
                      controller: contentController,
                      maxLength: 1000,
                      maxLengthEnforcement: MaxLengthEnforcement.none,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      minLines: 10,
                      maxLines: 16,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        labelText: 'Note',
                        alignLabelWithHint: true,
                        hintText: 'Write your message here',
                      ),
                      validator: _validateContent,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.45),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 20,
                            color: AppColors.ink,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Never store passwords, PINs, OTPs, recovery phrases, API keys, or security codes here.',
                              style: TextStyle(
                                color: AppColors.ink,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  key: const Key('save-legacy-note'),
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
