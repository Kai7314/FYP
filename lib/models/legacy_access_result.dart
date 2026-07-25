import 'document_model.dart';
import 'legacy_note_model.dart';

class LegacyAccessResult {
  const LegacyAccessResult({
    required this.ownerName,
    required this.preferences,
    required this.notes,
    required this.documents,
    required this.lastActivityAt,
    this.accessExpiresAt,
    this.protectedContentAvailable = false,
    this.protectedStatus = 'unavailable',
    this.protectedMessage = '',
    this.protectedAvailableAt,
    this.daysRemaining,
  });

  final String ownerName;
  final FuneralPreferences preferences;
  final List<LegacyNote> notes;
  final List<LegacyAccessDocument> documents;
  final DateTime? lastActivityAt;
  final DateTime? accessExpiresAt;
  final bool protectedContentAvailable;
  final String protectedStatus;
  final String protectedMessage;
  final DateTime? protectedAvailableAt;
  final int? daysRemaining;

  factory LegacyAccessResult.fromJson(Map<String, dynamic> json) {
    final preferencesData = json['preferences'];
    final notesData = json['notes'];
    final documentsData = json['documents'];
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
      documents: documentsData is List
          ? documentsData
                .whereType<Map>()
                .map(
                  (document) => LegacyAccessDocument.fromJson(
                    Map<String, dynamic>.from(document),
                  ),
                )
                .where((document) => document.signedUrl.isNotEmpty)
                .toList()
          : const [],
      lastActivityAt: DateTime.tryParse(
        json['lastActivityAt']?.toString() ?? '',
      ),
      accessExpiresAt: DateTime.tryParse(
        (json['accessExpiresAt'] ?? json['access_expires_at'])?.toString() ??
            '',
      ),
      protectedContentAvailable:
          json['protectedContentAvailable'] == true ||
          json['protected_content_available'] == true,
      protectedStatus:
          (json['protectedStatus'] ?? json['protected_status'])?.toString() ??
          'unavailable',
      protectedMessage:
          (json['protectedMessage'] ?? json['protected_message'])?.toString() ??
          '',
      protectedAvailableAt: DateTime.tryParse(
        (json['protectedAvailableAt'] ?? json['protected_available_at'])
                ?.toString() ??
            '',
      ),
      daysRemaining: _optionalInt(
        json['daysRemaining'] ?? json['days_remaining'],
      ),
    );
  }
}

int? _optionalInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

class LegacyAccessDocument {
  const LegacyAccessDocument({
    required this.id,
    required this.name,
    required this.signedUrl,
    required this.uploadedAt,
  });

  final String id;
  final String name;
  final String signedUrl;
  final DateTime? uploadedAt;

  factory LegacyAccessDocument.fromJson(Map<String, dynamic> json) {
    return LegacyAccessDocument(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Document',
      signedUrl: (json['signedUrl'] ?? json['signed_url'])?.toString() ?? '',
      uploadedAt: DateTime.tryParse(
        (json['uploadedAt'] ?? json['uploaded_at'])?.toString() ?? '',
      ),
    );
  }
}

class LegacyAccessRequestStatus {
  const LegacyAccessRequestStatus({
    required this.codeSent,
    required this.status,
    required this.message,
    required this.daysRemaining,
    required this.availableAt,
    required this.accessExpiresAt,
    this.protectedContentAvailable = false,
    this.protectedStatus = 'unavailable',
  });

  final bool codeSent;
  final String status;
  final String message;
  final int? daysRemaining;
  final DateTime? availableAt;
  final DateTime? accessExpiresAt;
  final bool protectedContentAvailable;
  final String protectedStatus;

  factory LegacyAccessRequestStatus.fromJson(Map<String, dynamic> json) {
    final rawDays = json['daysRemaining'] ?? json['days_remaining'];
    return LegacyAccessRequestStatus(
      codeSent: json['codeSent'] == true || json['code_sent'] == true,
      status: json['status']?.toString() ?? 'unavailable',
      message:
          json['message']?.toString() ??
          'No SMS was sent. Check the entered details and try again.',
      daysRemaining: rawDays is num
          ? rawDays.toInt()
          : int.tryParse(rawDays?.toString() ?? ''),
      availableAt: DateTime.tryParse(
        (json['availableAt'] ?? json['available_at'])?.toString() ?? '',
      ),
      accessExpiresAt: DateTime.tryParse(
        (json['accessExpiresAt'] ?? json['access_expires_at'])?.toString() ??
            '',
      ),
      protectedContentAvailable:
          json['protectedContentAvailable'] == true ||
          json['protected_content_available'] == true,
      protectedStatus:
          (json['protectedStatus'] ?? json['protected_status'])?.toString() ??
          'unavailable',
    );
  }
}
