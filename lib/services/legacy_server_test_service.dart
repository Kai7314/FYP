import 'package:supabase_flutter/supabase_flutter.dart';

class LegacyServerTestException implements Exception {
  const LegacyServerTestException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LegacyServerTestResult {
  const LegacyServerTestResult({
    required this.ok,
    required this.title,
    required this.message,
    required this.details,
  });

  final bool ok;
  final String title;
  final String message;
  final Map<String, dynamic> details;

  factory LegacyServerTestResult.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['details'];
    return LegacyServerTestResult(
      ok: json['ok'] == true,
      title: json['title']?.toString() ?? 'Legacy server test',
      message: json['message']?.toString() ?? 'The server test completed.',
      details: rawDetails is Map
          ? Map<String, dynamic>.from(rawDetails)
          : const {},
    );
  }
}

class LegacyServerTestService {
  LegacyServerTestService({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  final SupabaseClient client;

  Future<LegacyServerTestResult> run(String action) async {
    try {
      final response = await client.functions.invoke(
        'legacy-server-test',
        body: {'action': action},
      );
      final data = response.data;
      if (data is! Map) {
        throw const LegacyServerTestException(
          'The Legacy server returned an invalid test result.',
        );
      }
      final json = Map<String, dynamic>.from(data);
      final error = json['error']?.toString().trim();
      if (error != null && error.isNotEmpty) {
        throw LegacyServerTestException(error);
      }
      return LegacyServerTestResult.fromJson(json);
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map ? details['error']?.toString() : null;
      throw LegacyServerTestException(
        message?.trim().isNotEmpty == true
            ? message!.trim()
            : 'The Legacy server test is unavailable right now.',
      );
    }
  }
}
