class LegacyDocument {
  const LegacyDocument({
    required this.id,
    required this.name,
    required this.storagePath,
    required this.uploadedAt,
  });

  final String id;
  final String name;
  final String storagePath;
  final DateTime uploadedAt;

  factory LegacyDocument.fromJson(Map<String, dynamic> json) {
    return LegacyDocument(
      id: (json['id'] ?? json['document_id']).toString(),
      name: json['name']?.toString() ?? 'Document',
      storagePath: json['storage_path']?.toString() ?? '',
      uploadedAt:
          DateTime.tryParse(json['uploaded_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class FuneralPreferences {
  const FuneralPreferences({
    this.religion = '',
    this.serviceType = '',
    this.venue = '',
    this.notes = '',
    this.authorizedContact = '',
  });

  final String religion;
  final String serviceType;
  final String venue;
  final String notes;
  final String authorizedContact;

  factory FuneralPreferences.fromJson(Map<String, dynamic>? json) {
    return FuneralPreferences(
      religion: json?['religion']?.toString() ?? '',
      serviceType: json?['service_type']?.toString() ?? '',
      venue: json?['venue']?.toString() ?? '',
      notes: json?['notes']?.toString() ?? '',
      authorizedContact: json?['authorized_contact']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'religion': religion,
    'service_type': serviceType,
    'venue': venue,
    'notes': notes,
    'authorized_contact': authorizedContact,
  };
}
