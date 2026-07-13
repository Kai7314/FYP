import 'document_model.dart';
import 'legacy_note_model.dart';

class LegacyAccessResult {
  const LegacyAccessResult({
    required this.ownerName,
    required this.preferences,
    required this.notes,
    required this.lastActivityAt,
  });

  final String ownerName;
  final FuneralPreferences preferences;
  final List<LegacyNote> notes;
  final DateTime? lastActivityAt;

  factory LegacyAccessResult.fromJson(Map<String, dynamic> json) {
    final preferencesData = json['preferences'];
    final notesData = json['notes'];
    return LegacyAccessResult(
      ownerName: json['ownerName']?.toString() ?? 'EthernaCare user',
      preferences: FuneralPreferences.fromJson(
        preferencesData is Map
            ? Map<String, dynamic>.from(preferencesData)
            : null,
      ),
      notes: notesData is List
          ? notesData
                .whereType<Map>()
                .map(
                  (note) =>
                      LegacyNote.fromJson(Map<String, dynamic>.from(note)),
                )
                .toList()
          : const [],
      lastActivityAt: DateTime.tryParse(
        json['lastActivityAt']?.toString() ?? '',
      ),
    );
  }
}
