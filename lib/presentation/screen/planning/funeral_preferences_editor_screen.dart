import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/colors.dart';
import '../../../models/document_model.dart';

class FuneralPreferencesEditorScreen extends StatefulWidget {
  const FuneralPreferencesEditorScreen({
    super.key,
    required this.preferences,
    required this.contacts,
  });

  final FuneralPreferences preferences;
  final List<Map<String, dynamic>> contacts;

  @override
  State<FuneralPreferencesEditorScreen> createState() =>
      _FuneralPreferencesEditorScreenState();
}

class _FuneralPreferencesEditorScreenState
    extends State<FuneralPreferencesEditorScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController venueController;
  late final TextEditingController notesController;
  late final List<String> religionOptions;
  late final List<String> serviceTypeOptions;
  late final List<String> contactOptions;
  String? selectedReligion;
  String? selectedServiceType;
  String? selectedAuthorizedContact;

  @override
  void initState() {
    super.initState();
    venueController = TextEditingController(text: widget.preferences.venue);
    notesController = TextEditingController(text: widget.preferences.notes);
    religionOptions = _withExistingValue(
      FuneralPreferenceOptions.religions,
      widget.preferences.religion,
    );
    serviceTypeOptions = _withExistingValue(
      FuneralPreferenceOptions.serviceTypes,
      widget.preferences.serviceType,
    );
    selectedReligion = _selectedValue(
      religionOptions,
      widget.preferences.religion,
    );
    selectedServiceType = _selectedValue(
      serviceTypeOptions,
      widget.preferences.serviceType,
    );
    contactOptions = widget.contacts.map(_contactLabel).toSet().toList();
    selectedAuthorizedContact = _initialContactSelection();
  }

  @override
  void dispose() {
    venueController.dispose();
    notesController.dispose();
    super.dispose();
  }

  List<String> _withExistingValue(List<String> options, String existing) {
    final values = [...options];
    final trimmed = existing.trim();
    if (trimmed.isNotEmpty && !values.contains(trimmed)) values.add(trimmed);
    return values;
  }

  String? _selectedValue(List<String> options, String existing) {
    final trimmed = existing.trim();
    return options.contains(trimmed) ? trimmed : null;
  }

  String _contactLabel(Map<String, dynamic> contact) {
    final name = contact['name']?.toString().trim() ?? '';
    final phone = contact['phone']?.toString().trim() ?? '';
    return phone.isEmpty ? name : '$name - $phone';
  }

  String? _initialContactSelection() {
    if (contactOptions.isEmpty) return null;
    final saved = widget.preferences.authorizedContact.trim();
    if (contactOptions.contains(saved)) return saved;

    for (final contact in widget.contacts) {
      final name = contact['name']?.toString().trim() ?? '';
      if (name == saved) return _contactLabel(contact);
    }
    for (final contact in widget.contacts) {
      if (contact['is_primary'] == true) return _contactLabel(contact);
    }
    return null;
  }

  void _save() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      FuneralPreferences(
        religion: selectedReligion!,
        serviceType: selectedServiceType!,
        venue: venueController.text.trim(),
        authorizedContact: selectedAuthorizedContact ?? '',
        notes: notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Funeral Preferences')),
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
                    const _SectionLabel(
                      icon: Icons.church_outlined,
                      label: 'Service preferences',
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedReligion,
                      isExpanded: true,
                      menuMaxHeight: 360,
                      decoration: const InputDecoration(
                        labelText: 'Religion',
                        hintText: 'Select religion',
                      ),
                      items: religionOptions
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                value,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => selectedReligion = value,
                      validator: (value) => value == null
                          ? 'Select a religion or preference.'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue: selectedServiceType,
                      isExpanded: true,
                      menuMaxHeight: 360,
                      decoration: const InputDecoration(
                        labelText: 'Service type',
                        hintText: 'Select service type',
                      ),
                      items: serviceTypeOptions
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                value,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => selectedServiceType = value,
                      validator: (value) => value == null
                          ? 'Select a service type or Not decided.'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      key: const Key('funeral-venue-field'),
                      controller: venueController,
                      maxLength: 100,
                      maxLengthEnforcement: MaxLengthEnforcement.none,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Preferred venue',
                        hintText: 'Venue, place of worship, or location',
                      ),
                      validator: (value) => (value?.trim().length ?? 0) > 100
                          ? 'Preferred venue must not exceed 100 characters.'
                          : null,
                    ),
                    const SizedBox(height: 22),
                    const _SectionLabel(
                      icon: Icons.person_outline,
                      label: 'Contact and notes',
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedAuthorizedContact,
                      isExpanded: true,
                      menuMaxHeight: 320,
                      decoration: InputDecoration(
                        labelText: 'Authorized contact',
                        hintText: contactOptions.isEmpty
                            ? 'No trusted contacts available'
                            : 'Select a trusted contact',
                        helperText: contactOptions.isEmpty
                            ? 'Add a trusted contact from the Contacts page.'
                            : null,
                      ),
                      selectedItemBuilder: (context) => contactOptions
                          .map(
                            (value) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      items: contactOptions
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                value,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: contactOptions.isEmpty
                          ? null
                          : (value) => selectedAuthorizedContact = value,
                      validator: contactOptions.isEmpty
                          ? null
                          : (value) => value == null
                                ? 'Select an authorized contact.'
                                : null,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      key: const Key('funeral-notes-field'),
                      controller: notesController,
                      maxLength: 500,
                      maxLengthEnforcement: MaxLengthEnforcement.none,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      minLines: 5,
                      maxLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      validator: (value) => (value?.trim().length ?? 0) > 500
                          ? 'Notes must not exceed 500 characters.'
                          : null,
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
                  key: const Key('save-funeral-preferences'),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
