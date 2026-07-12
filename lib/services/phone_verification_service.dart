import 'package:supabase_flutter/supabase_flutter.dart';

class PhoneVerificationPurpose {
  static const userPhone = 'user_phone';
  static const contactPhone = 'contact_phone';
}

class PhoneVerificationException implements Exception {
  const PhoneVerificationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PhoneVerificationService {
  PhoneVerificationService({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  final SupabaseClient client;

  Future<void> requestCode({
    required String phone,
    required String purpose,
  }) async {
    final response = await _invoke(
      'request-phone-otp',
      body: {'phone': phone, 'purpose': purpose},
    );
    final data = response.data;
    final error = _errorFrom(data);
    if (error != null) throw PhoneVerificationException(error);
  }

  Future<DateTime?> verifyCode({
    required String phone,
    required String purpose,
    required String code,
  }) async {
    final response = await _invoke(
      'verify-phone-otp',
      body: {'phone': phone, 'purpose': purpose, 'code': code},
    );
    final data = response.data;
    final error = _errorFrom(data);
    if (error != null) throw PhoneVerificationException(error);
    if (data is Map) {
      return DateTime.tryParse(data['verifiedAt']?.toString() ?? '');
    }
    return null;
  }

  Future<FunctionResponse> _invoke(
    String functionName, {
    required Map<String, dynamic> body,
  }) async {
    try {
      return await client.functions.invoke(functionName, body: body);
    } on FunctionException catch (error) {
      final message = _errorFrom(error.details);
      throw PhoneVerificationException(
        message ?? 'Phone verification service is unavailable right now.',
      );
    }
  }

  String? _errorFrom(Object? data) {
    if (data is! Map) return null;
    final error = data['error']?.toString();
    return error == null || error.trim().isEmpty ? null : error;
  }
}
