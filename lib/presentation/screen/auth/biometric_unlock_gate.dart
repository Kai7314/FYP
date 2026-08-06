import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../services/biometric_auth_service.dart';

class BiometricUnlockGate extends StatefulWidget {
  const BiometricUnlockGate({
    super.key,
    required this.userId,
    required this.unlockedBuilder,
    required this.onUsePassword,
    this.service,
  });

  final String userId;
  final WidgetBuilder unlockedBuilder;
  final Future<void> Function() onUsePassword;
  final BiometricAuthService? service;

  @override
  State<BiometricUnlockGate> createState() => _BiometricUnlockGateState();
}

class _BiometricUnlockGateState extends State<BiometricUnlockGate>
    with WidgetsBindingObserver {
  static const backgroundLockGracePeriod = Duration(seconds: 30);

  late final BiometricAuthService service =
      widget.service ?? BiometricAuthService();

  Timer? backgroundLockTimer;
  BiometricAvailability? availability;
  bool loading = true;
  bool enabled = false;
  bool unlocked = false;
  bool authenticating = false;
  bool authenticationChangedLifecycle = false;
  int authenticationGeneration = 0;
  int preferenceLoadGeneration = 0;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadPreference(initial: true));
  }

  @override
  void didUpdateWidget(covariant BiometricUnlockGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      backgroundLockTimer?.cancel();
      backgroundLockTimer = null;
      authenticationGeneration += 1;
      authenticationChangedLifecycle = false;
      setState(() {
        loading = true;
        enabled = false;
        unlocked = false;
        errorMessage = null;
      });
      unawaited(_loadPreference(initial: true));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final backgrounded =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;
    final leftForeground =
        state == AppLifecycleState.inactive ||
        backgrounded ||
        state == AppLifecycleState.detached;
    if (leftForeground && authenticating) {
      authenticationChangedLifecycle = true;
      return;
    }

    if (backgrounded) {
      _scheduleBackgroundLock();
      return;
    }

    if (state == AppLifecycleState.detached) {
      backgroundLockTimer?.cancel();
      backgroundLockTimer = null;
      return;
    }

    if (state != AppLifecycleState.resumed) return;

    backgroundLockTimer?.cancel();
    backgroundLockTimer = null;

    if (state == AppLifecycleState.resumed && authenticationChangedLifecycle) {
      authenticationChangedLifecycle = false;
      return;
    }

    if (state == AppLifecycleState.resumed && !authenticating) {
      unawaited(_loadPreference(initial: false));
    }
  }

  void _scheduleBackgroundLock() {
    if (!mounted || !enabled || !unlocked || backgroundLockTimer != null) {
      return;
    }
    backgroundLockTimer = Timer(backgroundLockGracePeriod, () {
      backgroundLockTimer = null;
      if (!mounted || authenticating || !enabled || !unlocked) return;
      setState(() {
        unlocked = false;
        errorMessage = null;
      });
    });
  }

  Future<void> _loadPreference({required bool initial}) async {
    final generation = ++preferenceLoadGeneration;
    final userId = widget.userId;
    try {
      final nextEnabled = await service.isEnabledForUser(userId);
      if (!_isCurrentPreferenceLoad(generation, userId)) return;
      if (!nextEnabled) {
        setState(() {
          loading = false;
          enabled = false;
          unlocked = true;
          errorMessage = null;
        });
        return;
      }

      final nextAvailability = await service.checkAvailability();
      if (!_isCurrentPreferenceLoad(generation, userId)) return;
      setState(() {
        loading = false;
        enabled = true;
        availability = nextAvailability;
        if (initial) unlocked = false;
        if (!nextAvailability.available) {
          unlocked = false;
          errorMessage =
              '${nextAvailability.methodLabel} is not available on this device.';
        }
      });
      if (!unlocked && nextAvailability.available) {
        await WidgetsBinding.instance.endOfFrame;
        if (_isCurrentPreferenceLoad(generation, userId)) {
          await _unlock(knownAvailability: nextAvailability);
        }
      }
    } catch (error) {
      if (!_isCurrentPreferenceLoad(generation, userId)) return;
      setState(() {
        loading = false;
        enabled = true;
        unlocked = false;
        errorMessage = error.toString();
      });
    }
  }

  bool _isCurrentPreferenceLoad(int generation, String userId) {
    return mounted &&
        generation == preferenceLoadGeneration &&
        userId == widget.userId;
  }

  Future<void> _unlock({BiometricAvailability? knownAvailability}) async {
    if (authenticating || unlocked) return;
    final generation = ++authenticationGeneration;
    final userId = widget.userId;
    setState(() {
      authenticating = true;
      errorMessage = null;
    });
    try {
      final authenticated = await service.authenticate(
        reason: 'Unlock your signed-in EthernaCare account.',
        knownAvailability: knownAvailability ?? availability,
      );
      if (!_isCurrentAuthentication(generation, userId)) return;
      setState(() {
        unlocked = authenticated;
        if (!authenticated) {
          errorMessage = 'Authentication was cancelled. Try again to unlock.';
        }
      });
    } catch (error) {
      if (!_isCurrentAuthentication(generation, userId)) return;
      setState(() => errorMessage = error.toString());
    } finally {
      if (_isCurrentAuthentication(generation, userId)) {
        setState(() => authenticating = false);
      }
    }
  }

  bool _isCurrentAuthentication(int generation, String userId) {
    return mounted &&
        generation == authenticationGeneration &&
        userId == widget.userId;
  }

  @override
  void dispose() {
    backgroundLockTimer?.cancel();
    authenticationGeneration += 1;
    preferenceLoadGeneration += 1;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _BiometricGateStatus(
        icon: Icons.shield_outlined,
        title: 'Securing your account',
        message: 'Checking device authentication.',
        loading: true,
      );
    }
    if (!enabled || unlocked) return widget.unlockedBuilder(context);

    final method = availability?.methodLabel ?? 'Biometrics';
    return _BiometricGateStatus(
      icon: method.contains('Face') ? Icons.face_outlined : Icons.fingerprint,
      title: 'Unlock EthernaCare',
      message:
          'Use $method to continue to your signed-in account on this device.',
      errorMessage: errorMessage,
      loading: authenticating,
      primaryLabel: 'Unlock',
      onPrimary: authenticating ? null : _unlock,
      secondaryLabel: 'Sign out and use password',
      onSecondary: authenticating ? null : widget.onUsePassword,
    );
  }
}

class _BiometricGateStatus extends StatelessWidget {
  const _BiometricGateStatus({
    required this.icon,
    required this.title,
    required this.message,
    this.errorMessage,
    this.loading = false,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? errorMessage;
  final bool loading;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final Future<void> Function()? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.appGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 86,
                      height: 86,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: Colors.white, size: 48),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 18),
                      Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (loading)
                      const CircularProgressIndicator()
                    else if (primaryLabel != null)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onPrimary,
                          icon: Icon(icon),
                          label: Text(primaryLabel!),
                        ),
                      ),
                    if (secondaryLabel != null) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: onSecondary == null
                            ? null
                            : () => unawaited(onSecondary!()),
                        child: Text(secondaryLabel!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
