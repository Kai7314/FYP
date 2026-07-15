import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/legacy_access_result.dart';

class LegacyAccessException implements Exception {
  const LegacyAccessException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LegacyAccessService {
  LegacyAccessService({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  final SupabaseClient client;

  Future<void> requestCode({
    required String ownerUid,
    required String phone,
  }) async {
    await _invoke(
      'request-legacy-access',
      body: {'ownerUid': ownerUid.trim(), 'phone': phone},
    );
  }

  Future<LegacyAccessResult> verifyCode({
    required String ownerUid,
    required String phone,
    required String code,
  }) async {
    final response = await _invoke(
      'verify-legacy-access',
      body: {'ownerUid': ownerUid.trim(), 'phone': phone, 'code': code},
    );
    final data = response.data;
    if (data is! Map || data['authorized'] != true) {
      throw const LegacyAccessException('Legacy access could not be verified.');
    }
    return LegacyAccessResult.fromJson(Map<String, dynamic>.from(data));
  }

  Future<LegacyAccessResult> verifyTestingAccess({
    required String ownerUid,
    required String phone,
  }) async {
    final response = await _invoke(
      'verify-legacy-access',
      body: {
        'ownerUid': ownerUid.trim(),
        'phone': phone,
        'testingMode': true,
      },
    );
    final data = response.data;
    if (data is! Map || data['authorized'] != true) {
      throw const LegacyAccessException(
        'Legacy testing access could not be verified.',
      );
    }
    return LegacyAccessResult.fromJson(Map<String, dynamic>.from(data));
  }

  Future<FunctionResponse> _invoke(
    String functionName, {
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await client.functions.invoke(functionName, body: body);
      final error = _errorFrom(response.data);
      if (error != null) throw LegacyAccessException(error);
      return response;
    } on FunctionException catch (error) {
      final message = _errorFrom(error.details);
      throw LegacyAccessException(
        message ?? 'Legacy Checking is unavailable right now.',
      );
    }
  }

  String? _errorFrom(Object? data) {
    if (data is! Map) return null;
    final error = data['error']?.toString().trim();
    return error == null || error.isEmpty ? null : error;
  }
}
