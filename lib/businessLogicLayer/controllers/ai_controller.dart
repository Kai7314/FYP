import '../../services/ai_service.dart';

class AiController {
  AiController({AiService? aiService}) : aiService = aiService ?? AiService();

  final AiService aiService;

  Future<String> ask(String question) => aiService.ask(question);
}
