import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/contact_service.dart';
import '../../../services/user_service.dart';
import '../home/home_screen.dart';
import 'biometric_unlock_gate.dart';
import 'first_login_setup_screen.dart';
import 'login_screen.dart';
import 'primary_contact_setup_screen.dart';
import 'reset_password_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final authService = AuthService();
  final userService = UserService();
  final contactService = ContactService();
  String? initializedProfileUserId;
  String? activeProfileUserId;
  Future<Map<String, dynamic>>? activeProfileFuture;
  String? activePrimaryContactUserId;
  Future<bool>? activePrimaryContactFuture;
  int setupRefresh = 0;
  int contactRefresh = 0;
  bool passwordRecoveryActive = false;

  Future<Map<String, dynamic>> _profileFutureFor(String userId) {
    if (activeProfileUserId != userId || activeProfileFuture == null) {
      activeProfileUserId = userId;
      activeProfileFuture = _loadProfile(
        userId,
      ).timeout(const Duration(seconds: 18));
    }
    return activeProfileFuture!;
  }

  Future<bool> _primaryContactFutureFor(String userId) {
    if (activePrimaryContactUserId != userId ||
        activePrimaryContactFuture == null) {
      activePrimaryContactUserId = userId;
      activePrimaryContactFuture = contactService
          .hasPrimaryContact(forceRefresh: true)
          .timeout(const Duration(seconds: 18));
    }
    return activePrimaryContactFuture!;
  }

  Future<Map<String, dynamic>> _loadProfile(String userId) async {
    if (initializedProfileUserId != userId) {
      await authService.handleUserProfile();
      initializedProfileUserId = userId;
    }
    return userService.getCurrentProfile(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        final authEvent = snapshot.data?.event;
        if (authEvent == AuthChangeEvent.passwordRecovery) {
          passwordRecoveryActive = true;
        } else if (authEvent == AuthChangeEvent.signedOut) {
          passwordRecoveryActive = false;
        }

        final session = snapshot.data?.session ?? authService.currentSession;

        if (session != null) {
          if (passwordRecoveryActive) {
            return const ResetPasswordScreen();
          }

          return BiometricUnlockGate(
            key: ValueKey('biometric-${session.user.id}'),
            userId: session.user.id,
            onUsePassword: userService.signOut,
            unlockedBuilder: (context) => FutureBuilder<Map<String, dynamic>>(
              key: ValueKey('${session.user.id}-$setupRefresh'),
              future: _profileFutureFor(session.user.id),
              builder: (context, profileSnapshot) {
                if (profileSnapshot.connectionState != ConnectionState.done) {
                  return const _GateStatusScreen(
                    title: 'Loading your profile',
                    message: 'Preparing your safety setup.',
                  );
                }

                if (profileSnapshot.hasError) {
                  return Scaffold(
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 40),
                            const SizedBox(height: 12),
                            const Text(
                              'Unable to load your profile.',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              profileSnapshot.error.toString(),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => setState(() {
                                activeProfileFuture = null;
                                setupRefresh += 1;
                              }),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final profile = profileSnapshot.data ?? {};
                if (!UserService.isProfileSetupComplete(profile)) {
                  return FirstLoginSetupScreen(
                    profile: profile,
                    onComplete: () => setState(() {
                      initializedProfileUserId = null;
                      activeProfileFuture = null;
                      setupRefresh += 1;
                    }),
                  );
                }

                return FutureBuilder<bool>(
                  key: ValueKey(
                    'primary-contact-${session.user.id}-$contactRefresh',
                  ),
                  future: _primaryContactFutureFor(session.user.id),
                  builder: (context, contactSnapshot) {
                    if (contactSnapshot.connectionState !=
                        ConnectionState.done) {
                      return const _GateStatusScreen(
                        title: 'Checking emergency contact',
                        message: 'Making sure your primary contact is ready.',
                      );
                    }

                    if (contactSnapshot.hasError) {
                      return Scaffold(
                        body: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline, size: 40),
                                const SizedBox(height: 12),
                                const Text(
                                  'Unable to load emergency contacts.',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  contactSnapshot.error.toString(),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: () => setState(() {
                                    activePrimaryContactFuture = null;
                                    contactRefresh += 1;
                                  }),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    if (contactSnapshot.data != true) {
                      return PrimaryContactSetupScreen(
                        onComplete: () => setState(() {
                          activePrimaryContactFuture = null;
                          contactRefresh += 1;
                        }),
                      );
                    }

                    return const HomeScreen();
                  },
                );
              },
            ),
          );
        }

        initializedProfileUserId = null;
        activeProfileUserId = null;
        activeProfileFuture = null;
        activePrimaryContactUserId = null;
        activePrimaryContactFuture = null;
        return const LoginScreen();
      },
    );
  }
}

class _GateStatusScreen extends StatelessWidget {
  const _GateStatusScreen({required this.title, required this.message});

  final String title;
  final String message;

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
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
