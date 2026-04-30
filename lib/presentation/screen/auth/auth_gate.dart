import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/auth_service.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      // 🔥 THIS RUNS AFTER GOOGLE LOGIN
      AuthService().handleUserProfile();

      return const HomeScreen();
    } else {
      return const LoginScreen();
    }
  }
}
