import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/auth_service.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;

    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? auth.currentSession;

        if (session != null) {
          Future.microtask(() => AuthService().handleUserProfile());
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
