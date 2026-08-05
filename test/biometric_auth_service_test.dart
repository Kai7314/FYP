import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyp/presentation/screen/auth/biometric_unlock_gate.dart';
import 'package:fyp/services/biometric_auth_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('biometric preference is stored separately for each account', () async {
    final service = BiometricAuthService(
      device: _FakeBiometricDevice(),
      platform: TargetPlatform.android,
      isWeb: false,
    );

    expect(await service.isEnabledForUser('user-a'), isFalse);
    await service.setEnabledForUser('user-a', true);

    expect(await service.isEnabledForUser('user-a'), isTrue);
    expect(await service.isEnabledForUser('user-b'), isFalse);
  });

  test(
    'Face ID is identified and biometrics-only authentication is used',
    () async {
      final device = _FakeBiometricDevice(
        biometrics: const [BiometricType.face],
      );
      final service = BiometricAuthService(
        device: device,
        platform: TargetPlatform.iOS,
        isWeb: false,
      );

      final availability = await service.checkAvailability();
      final authenticated = await service.authenticate();

      expect(availability.available, isTrue);
      expect(availability.methodLabel, 'Face ID');
      expect(authenticated, isTrue);
      expect(device.lastBiometricOnly, isTrue);
    },
  );

  test('Windows Hello permits the operating system credential flow', () async {
    final device = _FakeBiometricDevice(canCheck: false, biometrics: const []);
    final service = BiometricAuthService(
      device: device,
      platform: TargetPlatform.windows,
      isWeb: false,
    );

    final availability = await service.checkAvailability();
    await service.authenticate();

    expect(availability.available, isTrue);
    expect(availability.methodLabel, 'Windows Hello');
    expect(device.lastBiometricOnly, isFalse);
  });

  test('web reports biometric unlock as unsupported', () async {
    final service = BiometricAuthService(
      device: _FakeBiometricDevice(),
      platform: TargetPlatform.android,
      isWeb: true,
    );

    final availability = await service.checkAvailability();

    expect(availability.platformSupported, isFalse);
    expect(availability.available, isFalse);
  });

  testWidgets('saved biometric setting unlocks a persisted session', (
    tester,
  ) async {
    final device = _FakeBiometricDevice();
    final service = BiometricAuthService(
      device: device,
      platform: TargetPlatform.android,
      isWeb: false,
    );
    await service.setEnabledForUser('user-a', true);

    await tester.pumpWidget(
      MaterialApp(
        home: BiometricUnlockGate(
          userId: 'user-a',
          service: service,
          onUsePassword: () async {},
          unlockedBuilder: (_) =>
              const Scaffold(body: Text('Protected account content')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Protected account content'), findsOneWidget);
    expect(device.authenticationCalls, 1);
  });

  testWidgets('cancelled biometric prompt keeps account content locked', (
    tester,
  ) async {
    final device = _FakeBiometricDevice(authenticated: false);
    final service = BiometricAuthService(
      device: device,
      platform: TargetPlatform.android,
      isWeb: false,
    );
    await service.setEnabledForUser('user-a', true);

    await tester.pumpWidget(
      MaterialApp(
        home: BiometricUnlockGate(
          userId: 'user-a',
          service: service,
          onUsePassword: () async {},
          unlockedBuilder: (_) =>
              const Scaffold(body: Text('Protected account content')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unlock EthernaCare'), findsOneWidget);
    expect(find.text('Protected account content'), findsNothing);
    expect(find.textContaining('cancelled'), findsOneWidget);
  });

  testWidgets(
    'an enabled account locks whenever the app leaves the foreground',
    (tester) async {
      final device = _FakeBiometricDevice();
      final service = BiometricAuthService(
        device: device,
        platform: TargetPlatform.android,
        isWeb: false,
      );
      await service.setEnabledForUser('user-a', true);

      await tester.pumpWidget(
        MaterialApp(
          home: BiometricUnlockGate(
            userId: 'user-a',
            service: service,
            onUsePassword: () async {},
            unlockedBuilder: (_) =>
                const Scaffold(body: Text('Protected account content')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Protected account content'), findsOneWidget);
      expect(device.authenticationCalls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Protected account content'), findsOneWidget);
      expect(device.authenticationCalls, 2);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Protected account content'), findsOneWidget);
      expect(device.authenticationCalls, 3);
    },
  );
}

class _FakeBiometricDevice implements BiometricDevice {
  _FakeBiometricDevice({
    this.canCheck = true,
    this.biometrics = const [BiometricType.fingerprint],
    this.authenticated = true,
  });

  final bool canCheck;
  final List<BiometricType> biometrics;
  final bool authenticated;

  int authenticationCalls = 0;
  bool? lastBiometricOnly;

  @override
  Future<bool> authenticate({
    required String reason,
    required bool biometricOnly,
  }) async {
    authenticationCalls += 1;
    lastBiometricOnly = biometricOnly;
    return authenticated;
  }

  @override
  Future<bool> canCheckBiometrics() async => canCheck;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => biometrics;

  @override
  Future<bool> isDeviceSupported() async => true;
}
