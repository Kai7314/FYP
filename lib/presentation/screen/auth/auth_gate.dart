import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/auth_service.dart';
import '../../../services/onboarding_service.dart';
import '../../../services/user_service.dart';
import '../home/home_screen.dart';
import 'first_login_setup_screen.dart';
import 'login_screen.dart';
import 'tutorial_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final authService = AuthService();
  final userService = UserService();
  final onboardingService = OnboardingService();
  String? initializedProfileUserId;
  String? activeProfileUserId;
  Future<Map<String, dynamic>>? activeProfileFuture;
  String? activeTutorialUserId;
  Future<bool>? activeTutorialFuture;
  int setupRefresh = 0;
  int tutorialRefresh = 0;

  Future<Map<String, dynamic>> _profileFutureFor(String userId) {
    if (activeProfileUserId != userId || activeProfileFuture == null) {
      activeProfileUserId = userId;
      activeProfileFuture = _loadProfile(userId);
    }
    return activeProfileFuture!;
  }

  Future<bool> _tutorialFutureFor(String userId) {
    if (activeTutorialUserId != userId || activeTutorialFuture == null) {
      activeTutorialUserId = userId;
      activeTutorialFuture = onboardingService.hasCompletedTutorial();
    }
    return activeTutorialFuture!;
  }

  Future<Map<String, dynamic>> _loadProfile(String userId) async {
    if (initializedProfileUserId == userId) {
      return userService.getCurrentProfile();
    }
    initializedProfileUserId = userId;
    await authService.handleUserProfile();
    return userService.getCurrentProfile(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? authService.currentSession;

        if (session != null) {
          return FutureBuilder<Map<String, dynamic>>(
            key: ValueKey('${session.user.id}-$setupRefresh'),
            future: _profileFutureFor(session.user.id),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
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
                key: ValueKey('tutorial-${session.user.id}-$tutorialRefresh'),
                future: _tutorialFutureFor(session.user.id),
                builder: (context, tutorialSnapshot) {
                  if (tutorialSnapshot.connectionState !=
                      ConnectionState.done) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (tutorialSnapshot.data != true) {
                    return TutorialScreen(
                      onComplete: () => setState(() {
                        activeTutorialFuture = null;
                        tutorialRefresh += 1;
                      }),
                    );
                  }

                  return const HomeScreen();
                },
              );
            },
          );
        }

        initializedProfileUserId = null;
        activeProfileUserId = null;
        activeProfileFuture = null;
        activeTutorialUserId = null;
        activeTutorialFuture = null;
        return const LoginScreen();
      },
    );
  }
}
