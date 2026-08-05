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
  late final BiometricAuthService service =
      widget.service ?? BiometricAuthService();

  BiometricAvailability? availability;
  bool loading = true;
  bool enabled = false;
  bool unlocked = false;
  bool authenticating = false;
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
    if ((state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.detached) &&
        enabled &&
        !authenticating &&
        mounted) {
      setState(() {
        unlocked = false;
        errorMessage = null;
      });
      return;
    }

    if (state == AppLifecycleState.resumed && !authenticating) {
      unawaited(_loadPreference(initial: false));
    }
  }

  Future<void> _loadPreference({required bool initial}) async {
    try {
      final nextEnabled = await service.isEnabledForUser(widget.userId);
      if (!mounted) return;
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
      if (!mounted) return;
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_unlock());
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        enabled = true;
        unlocked = false;
        errorMessage = error.toString();
      });
    }
  }

  Future<void> _unlock() async {
    if (authenticating || unlocked) return;
    setState(() {
      authenticating = true;
      errorMessage = null;
    });
    try {
      final authenticated = await service.authenticate(
        reason: 'Unlock your signed-in EthernaCare account.',
      );
      if (!mounted) return;
      setState(() {
        unlocked = authenticated;
        if (!authenticated) {
          errorMessage = 'Authentication was cancelled. Try again to unlock.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => authenticating = false);
    }
  }

  @override
  void dispose() {
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
