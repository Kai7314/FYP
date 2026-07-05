import '../dataAccessLayer/repositories/auth_repository.dart';
import '../models/ai_chat_message.dart';
import 'local_cache_service.dart';

class AiChatHistoryService {
  AiChatHistoryService({
    AuthRepository? authRepository,
    LocalCacheService? cache,
  }) : authRepository = authRepository ?? AuthRepository(),
       cache = cache ?? LocalCacheService();

  static const maxStoredMessages = 40;

  final AuthRepository authRepository;
  final LocalCacheService cache;

  String get _userKey {
    final userId = authRepository.currentUser?.id ?? 'guest';
    return 'ai_chat_history_v1_$userId';
  }

  Future<List<AiChatMessage>> load() async {
    final cached = await cache.readMap(_userKey);
    final rows = cached?['messages'] as List?;
    if (rows == null) return const [];
    return rows
        .whereType<Map>()
        .map((row) => AiChatMessage.fromJson(Map<String, dynamic>.from(row)))
        .where((message) => message.text.trim().isNotEmpty)
        .toList();
  }

  Future<void> save(List<AiChatMessage> messages) async {
    final trimmed = messages.length <= maxStoredMessages
        ? messages
        : messages.sublist(messages.length - maxStoredMessages);
    await cache.writeMap(_userKey, {
      'messages': trimmed.map((message) => message.toJson()).toList(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> clear() => cache.remove(_userKey);
}
