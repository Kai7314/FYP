import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricAuthException implements Exception {
  const BiometricAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BiometricAvailability {
  const BiometricAvailability({
    required this.platformSupported,
    required this.available,
    required this.methodLabel,
  });

  const BiometricAvailability.unsupported()
    : platformSupported = false,
      available = false,
      methodLabel = 'Biometrics';

  final bool platformSupported;
  final bool available;
  final String methodLabel;
}

class BiometricSetting {
  const BiometricSetting({required this.enabled, required this.availability});

  final bool enabled;
  final BiometricAvailability availability;
}

abstract interface class BiometricDevice {
  Future<bool> isDeviceSupported();
  Future<bool> canCheckBiometrics();
  Future<List<BiometricType>> getAvailableBiometrics();
  Future<bool> authenticate({
    required String reason,
    required bool biometricOnly,
  });
}

class LocalAuthBiometricDevice implements BiometricDevice {
  LocalAuthBiometricDevice({LocalAuthentication? authentication})
    : authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication authentication;
  static Future<bool>? _platformAuthentication;

  @override
  Future<bool> isDeviceSupported() => authentication.isDeviceSupported();

  @override
  Future<bool> canCheckBiometrics() async => authentication.canCheckBiometrics;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() =>
      authentication.getAvailableBiometrics();

  @override
  Future<bool> authenticate({
    required String reason,
    required bool biometricOnly,
  }) async {
    final activeAuthentication = _platformAuthentication;
    if (activeAuthentication != null) {
      return await activeAuthentication;
    }

    final authenticationOperation = authentication.authenticate(
      localizedReason: reason,
      biometricOnly: biometricOnly,
      persistAcrossBackgrounding: true,
    );
    _platformAuthentication = authenticationOperation;
    try {
      return await authenticationOperation;
    } finally {
      if (identical(_platformAuthentication, authenticationOperation)) {
        _platformAuthentication = null;
      }
    }
  }
}

class BiometricAuthService {
  BiometricAuthService({
    BiometricDevice? device,
    Future<SharedPreferences> Function()? preferencesLoader,
    TargetPlatform? platform,
    bool? isWeb,
  }) : device = device ?? LocalAuthBiometricDevice(),
       preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance,
       platform = platform ?? defaultTargetPlatform,
       isWeb = isWeb ?? kIsWeb;

  final BiometricDevice device;
  final Future<SharedPreferences> Function() preferencesLoader;
  final TargetPlatform platform;
  final bool isWeb;
  Future<bool>? _authenticationInProgress;

  String _preferenceKey(String userId) => 'biometric_unlock_enabled_v1_$userId';

  bool get supportsCurrentPlatform {
    if (isWeb) return false;
    return switch (platform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => false,
    };
  }

  Future<bool> isEnabledForUser(String userId) async {
    final preferences = await preferencesLoader();
    return preferences.getBool(_preferenceKey(userId)) ?? false;
  }

  Future<void> setEnabledForUser(String userId, bool enabled) async {
    final preferences = await preferencesLoader();
    await preferences.setBool(_preferenceKey(userId), enabled);
  }

  Future<BiometricSetting> getSetting(String userId) async {
    final results = await Future.wait<Object>([
      isEnabledForUser(userId),
      checkAvailability(),
    ]);
    return BiometricSetting(
      enabled: results[0] as bool,
      availability: results[1] as BiometricAvailability,
    );
  }

  Future<BiometricAvailability> checkAvailability() async {
    if (!supportsCurrentPlatform) {
      return const BiometricAvailability.unsupported();
    }

    try {
      final supported = await device.isDeviceSupported();
      if (!supported) {
        return BiometricAvailability(
          platformSupported: true,
          available: false,
          methodLabel: _defaultMethodLabel(),
        );
      }

      final results = await Future.wait<Object>([
        device.canCheckBiometrics(),
        device.getAvailableBiometrics(),
      ]);
      final canCheck = results[0] as bool;
      final biometrics = results[1] as List<BiometricType>;
      final windowsHello = platform == TargetPlatform.windows;
      return BiometricAvailability(
        platformSupported: true,
        available: windowsHello || (canCheck && biometrics.isNotEmpty),
        methodLabel: _methodLabel(biometrics),
      );
    } on LocalAuthException catch (error) {
      if (_isUnavailableError(error.code)) {
        return BiometricAvailability(
          platformSupported: true,
          available: false,
          methodLabel: _defaultMethodLabel(),
        );
      }
      throw BiometricAuthException(_friendlyError(error));
    } on PlatformException {
      return BiometricAvailability(
        platformSupported: true,
        available: false,
        methodLabel: _defaultMethodLabel(),
      );
    }
  }

  Future<bool> authenticate({
    String reason = 'Unlock your EthernaCare account.',
  }) async {
    final activeAuthentication = _authenticationInProgress;
    if (activeAuthentication != null) {
      return await activeAuthentication;
    }

    final authenticationOperation = _authenticate(reason: reason);
    _authenticationInProgress = authenticationOperation;
    try {
      return await authenticationOperation;
    } finally {
      if (identical(_authenticationInProgress, authenticationOperation)) {
        _authenticationInProgress = null;
      }
    }
  }

  Future<bool> _authenticate({required String reason}) async {
    final availability = await checkAvailability();
    if (!availability.available) {
      throw BiometricAuthException(
        availability.platformSupported
            ? 'Set up ${availability.methodLabel} in your device settings before enabling biometric unlock.'
            : 'Biometric unlock is not supported on this platform.',
      );
    }

    try {
      return await device.authenticate(
        reason: reason,
        biometricOnly: platform != TargetPlatform.windows,
      );
    } on LocalAuthException catch (error) {
      if (error.code == LocalAuthExceptionCode.userCanceled ||
          error.code == LocalAuthExceptionCode.systemCanceled ||
          error.code == LocalAuthExceptionCode.timeout) {
        return false;
      }
      throw BiometricAuthException(_friendlyError(error));
    } on PlatformException {
      throw const BiometricAuthException(
        'Device authentication could not start. Please try again.',
      );
    }
  }

  bool _isUnavailableError(LocalAuthExceptionCode code) {
    return code == LocalAuthExceptionCode.noBiometricHardware ||
        code == LocalAuthExceptionCode.noBiometricsEnrolled ||
        code == LocalAuthExceptionCode.noCredentialsSet;
  }

  String _friendlyError(LocalAuthException error) {
    return switch (error.code) {
      LocalAuthExceptionCode.noBiometricHardware =>
        'This device does not have supported biometric hardware.',
      LocalAuthExceptionCode.noBiometricsEnrolled =>
        'Set up fingerprint or face recognition in your device settings first.',
      LocalAuthExceptionCode.noCredentialsSet =>
        'Set up a device PIN, password, fingerprint, or face recognition first.',
      LocalAuthExceptionCode.temporaryLockout =>
        'Biometric authentication is temporarily locked. Wait a moment and try again.',
      LocalAuthExceptionCode.biometricLockout =>
        'Biometrics are locked. Unlock the device with its PIN or password, then try again.',
      LocalAuthExceptionCode.authInProgress =>
        'Device authentication is already in progress.',
      LocalAuthExceptionCode.uiUnavailable =>
        'The device authentication screen is unavailable right now.',
      LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable =>
        'Biometric hardware is temporarily unavailable.',
      _ =>
        error.description?.trim().isNotEmpty == true
            ? error.description!.trim()
            : 'Device authentication failed. Please try again.',
    };
  }

  String _methodLabel(List<BiometricType> biometrics) {
    if (platform == TargetPlatform.windows) return 'Windows Hello';
    final hasFace = biometrics.contains(BiometricType.face);
    final hasFingerprint = biometrics.contains(BiometricType.fingerprint);
    if (hasFace && hasFingerprint) return 'Face or fingerprint';
    if (hasFace) {
      return platform == TargetPlatform.iOS ? 'Face ID' : 'Face recognition';
    }
    if (hasFingerprint) {
      return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS
          ? 'Touch ID'
          : 'Fingerprint';
    }
    return _defaultMethodLabel();
  }

  String _defaultMethodLabel() {
    return switch (platform) {
      TargetPlatform.iOS => 'Face ID or Touch ID',
      TargetPlatform.macOS => 'Touch ID',
      TargetPlatform.windows => 'Windows Hello',
      _ => 'Fingerprint or face recognition',
    };
  }
}
