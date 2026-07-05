class LegacyNote {
  const LegacyNote({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory LegacyNote.fromJson(Map<String, dynamic> json) {
    final createdAt =
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now();
    return LegacyNote(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled note',
      content: json['content']?.toString() ?? '',
      createdAt: createdAt,
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  LegacyNote copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LegacyNote(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
