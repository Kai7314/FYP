import 'package:supabase_flutter/supabase_flutter.dart';

class AiService {
  AiService({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  final SupabaseClient client;

  Future<String> ask(String question) => askGuidance(question);

  Future<String> askGuidance(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) return 'Please enter a question.';

    try {
      final response = await client.functions
          .invoke('ai-guidance', body: {'question': trimmed})
          .timeout(const Duration(seconds: 25));
      final data = response.data;
      if (data is Map) {
        final answer = data['answer']?.toString().trim();
        if (answer != null && answer.isNotEmpty) return answer;

        final error = data['error']?.toString().trim();
        if (error != null && error.isNotEmpty) {
          return 'AI guidance is unavailable right now: $error';
        }
      }
    } catch (_) {
      // Fall back to offline guidance when the Edge Function is unavailable.
    }
    return offlineAnswer(trimmed);
  }

  static String offlineAnswer(String question) {
    final text = question.toLowerCase();
    if (text.contains('emergency') || text.contains('ambulance')) {
      return 'For immediate danger in Malaysia, call 999. EthernaCare can also record an SOS alert for your trusted contacts.';
    }
    if (text.contains('will')) {
      return 'Upload only a completed legal will. EthernaCare stores a copy but does not create, validate, or notarize a will.';
    }
    if (text.contains('funeral')) {
      return 'Record your religion, preferred service type, venue, authorized contact, and any personal notes in Legacy Planning.';
    }
    if (text.contains('contact')) {
      return 'Add up to five trusted contacts with valid phone numbers. They are the intended recipients for emergency follow-up.';
    }
    return 'I can provide general guidance about check-ins, emergencies, trusted contacts, funeral preferences, and stored will documents. For medical or legal decisions, contact a qualified professional.';
  }
}
