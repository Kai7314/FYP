import 'package:supabase_flutter/supabase_flutter.dart';

class PhoneVerificationPurpose {
  static const userPhone = 'user_phone';
  static const contactPhone = 'contact_phone';
}

class PhoneVerificationService {
  PhoneVerificationService({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  final SupabaseClient client;

  Future<void> requestCode({
    required String phone,
    required String purpose,
  }) async {
    final response = await client.functions.invoke(
      'request-phone-otp',
      body: {'phone': phone, 'purpose': purpose},
    );
    final data = response.data;
    final error = _errorFrom(data);
    if (error != null) throw StateError(error);
  }

  Future<DateTime?> verifyCode({
    required String phone,
    required String purpose,
    required String code,
  }) async {
    final response = await client.functions.invoke(
      'verify-phone-otp',
      body: {'phone': phone, 'purpose': purpose, 'code': code},
    );
    final data = response.data;
    final error = _errorFrom(data);
    if (error != null) throw StateError(error);
    if (data is Map) {
      return DateTime.tryParse(data['verifiedAt']?.toString() ?? '');
    }
    return null;
  }

  String? _errorFrom(Object? data) {
    if (data is! Map) return null;
    final error = data['error']?.toString();
    return error == null || error.trim().isEmpty ? null : error;
  }
}
