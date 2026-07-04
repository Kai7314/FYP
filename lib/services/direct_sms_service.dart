import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DirectSmsResult {
  const DirectSmsResult({
    required this.sent,
    this.error,
  });

  final bool sent;
  final String? error;
}

class DirectSmsService {
  static const _channel = MethodChannel('com.example.fyp/emergency_sms');

  Future<DirectSmsResult> send({
    required String phone,
    required String message,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const DirectSmsResult(
        sent: false,
        error: 'Direct SMS is only supported on Android devices.',
      );
    }

    final normalizedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (normalizedPhone.isEmpty) {
      return const DirectSmsResult(
        sent: false,
        error: 'Missing phone number.',
      );
    }

    try {
      final response = await _channel.invokeMapMethod<String, Object?>(
        'sendSms',
        {'phone': normalizedPhone, 'message': message},
      );
      final sent = response?['sent'] == true;
      return DirectSmsResult(
        sent: sent,
        error: response?['error']?.toString(),
      );
    } on PlatformException catch (error) {
      return DirectSmsResult(
        sent: false,
        error: error.message ?? error.code,
      );
    } on MissingPluginException {
      return const DirectSmsResult(
        sent: false,
        error: 'Android SMS bridge is unavailable in this app context.',
      );
    }
  }
}
