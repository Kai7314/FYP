import '../../services/ai_service.dart';
import '../../models/ai_chat_message.dart';

class AiController {
  AiController({AiService? aiService}) : aiService = aiService ?? AiService();

  final AiService aiService;

  Future<String> ask(
    String question, {
    List<AiChatMessage> history = const [],
  }) => aiService.ask(question, history: history);
}
