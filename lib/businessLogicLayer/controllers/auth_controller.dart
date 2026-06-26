import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../services/user_service.dart';

class AuthController {
  AuthController({
    AuthService? authService,
    UserService? userService,
  }) : authService = authService ?? AuthService(),
       userService = userService ?? UserService();

  final AuthService authService;
  final UserService userService;

  User? get currentUser => authService.currentUser;
  Stream<AuthState> get authChanges => authService.authStateChanges;

  Future<AuthResponse> signIn(String email, String password) {
    return authService.signIn(email: email, password: password);
  }

  Future<void> signOut() => userService.signOut();
}
