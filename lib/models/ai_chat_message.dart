class AiChatMessage {
  const AiChatMessage({
    required this.role,
    required this.text,
    required this.createdAt,
  });

  final String role;
  final String text;
  final DateTime createdAt;

  bool get isUser => role == 'user';

  factory AiChatMessage.user(String text) {
    return AiChatMessage(
      role: 'user',
      text: text,
      createdAt: DateTime.now(),
    );
  }

  factory AiChatMessage.assistant(String text) {
    return AiChatMessage(
      role: 'assistant',
      text: text,
      createdAt: DateTime.now(),
    );
  }

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    final role = json['role']?.toString() == 'user' ? 'user' : 'assistant';
    return AiChatMessage(
      role: role,
      text: json['text']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'role': role,
    'text': text,
    'created_at': createdAt.toIso8601String(),
  };
}
