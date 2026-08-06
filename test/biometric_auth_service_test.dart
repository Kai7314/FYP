import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fyp/presentation/screen/auth/biometric_unlock_gate.dart';
import 'package:fyp/presentation/widgets/biometric_setting_tile.dart';
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

  test('concurrent biometric requests share one device prompt', () async {
    final device = _PendingBiometricDevice();
    final service = BiometricAuthService(
      device: device,
      platform: TargetPlatform.android,
      isWeb: false,
    );

    final first = service.authenticate();
    final second = service.authenticate();
    await Future<void>.delayed(Duration.zero);

    expect(device.authenticationCalls, 1);
    device.complete(true);
    expect(await Future.wait([first, second]), [isTrue, isTrue]);
  });

  test(
    'stale native authentication is stopped and retried asynchronously',
    () async {
      final device = _RetryBiometricDevice();
      final service = BiometricAuthService(
        device: device,
        platform: TargetPlatform.android,
        isWeb: false,
      );

      final authenticated = await service.authenticate();

      expect(authenticated, isTrue);
      expect(device.authenticationCalls, 2);
      expect(device.stopCalls, 1);
    },
  );

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
    'biometric setting can be enabled and disabled without an async setState callback',
    (tester) async {
      final service = BiometricAuthService(
        device: _FakeBiometricDevice(),
        platform: TargetPlatform.android,
        isWeb: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BiometricSettingTile(
              userId: 'user-a',
              biometricAuthService: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switchFinder = find.byKey(
        const Key('biometric-unlock-switch'),
      );
      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(await service.isEnabledForUser('user-a'), isTrue);
      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(await service.isEnabledForUser('user-a'), isFalse);
      expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);
    },
  );

  testWidgets(
    'brief app interruptions do not immediately relock an enabled account',
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
      expect(device.authenticationCalls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 29));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Protected account content'), findsOneWidget);
      expect(device.authenticationCalls, 1);
    },
  );

  testWidgets(
    'an enabled account relocks after the background grace period',
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

      expect(device.authenticationCalls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 30));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Protected account content'), findsOneWidget);
      expect(device.authenticationCalls, 2);
    },
  );

  testWidgets(
    'biometric prompt lifecycle does not immediately open another prompt',
    (tester) async {
      final device = _PendingBiometricDevice();
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
      await tester.pump();
      await tester.pump();
      expect(device.authenticationCalls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      device.complete(false);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(device.authenticationCalls, 1);
      expect(find.text('Unlock EthernaCare'), findsOneWidget);
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

  @override
  Future<bool> stopAuthentication() async => true;
}

class _PendingBiometricDevice implements BiometricDevice {
  final Completer<bool> _authentication = Completer<bool>();
  int authenticationCalls = 0;

  void complete(bool authenticated) {
    _authentication.complete(authenticated);
  }

  @override
  Future<bool> authenticate({
    required String reason,
    required bool biometricOnly,
  }) {
    authenticationCalls += 1;
    return _authentication.future;
  }

  @override
  Future<bool> canCheckBiometrics() async => true;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => const [
    BiometricType.fingerprint,
  ];

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> stopAuthentication() async => true;
}

class _RetryBiometricDevice implements BiometricDevice {
  int authenticationCalls = 0;
  int stopCalls = 0;

  @override
  Future<bool> authenticate({
    required String reason,
    required bool biometricOnly,
  }) async {
    authenticationCalls += 1;
    if (authenticationCalls == 1) {
      throw const LocalAuthException(
        code: LocalAuthExceptionCode.authInProgress,
      );
    }
    return true;
  }

  @override
  Future<bool> canCheckBiometrics() async => true;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => const [
    BiometricType.fingerprint,
  ];

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> stopAuthentication() async {
    stopCalls += 1;
    return true;
  }
}
