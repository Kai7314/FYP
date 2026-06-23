import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/colors.dart';
import '../../../models/document_model.dart';
import '../../../services/document_service.dart';

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

  void _refresh() => setState(() => future = service.load());

  Future<void> _edit(FuneralPreferences preferences) async {
    final result = await showDialog<FuneralPreferences>(
      context: context,
      builder: (_) => _PreferencesDialog(preferences: preferences),
    );
    if (result == null) return;
    await service.savePreferences(result);
    _refresh();
  }

  Future<void> _upload() async {
    try {
      final uploaded = await service.pickAndUploadDocument();
      if (uploaded) _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
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
            return Center(
              child: Text('Unable to load planning data: ${snapshot.error}'),
            );
          }
          final preferences = data!.preferences;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Funeral Preferences',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _edit(preferences),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit preferences',
                  ),
                ],
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
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Secure Documents',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: _upload,
                    icon: const Icon(Icons.upload_file),
                    tooltip: 'Upload document',
                  ),
                ],
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

class _PreferencesDialog extends StatefulWidget {
  const _PreferencesDialog({required this.preferences});
  final FuneralPreferences preferences;

  @override
  State<_PreferencesDialog> createState() => _PreferencesDialogState();
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
