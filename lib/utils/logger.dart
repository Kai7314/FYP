import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  static void info(String message) {
    if (kDebugMode) debugPrint('[EthernaCare] $message');
  }

  static void error(String message, Object error) {
    if (kDebugMode) debugPrint('[EthernaCare] $message: $error');
  }
}
