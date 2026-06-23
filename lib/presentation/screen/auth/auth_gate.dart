import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/auth_service.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final authService = AuthService();
  String? initializedProfileUserId;

  void _initializeProfile(String userId) {
    if (initializedProfileUserId == userId) return;
    initializedProfileUserId = userId;
    Future.microtask(() => AuthService().handleUserProfile());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? authService.currentSession;

        if (session != null) {
          _initializeProfile(session.user.id);
          return const HomeScreen();
        }

        initializedProfileUserId = null;
        return const LoginScreen();
      },
    );
  }
}
