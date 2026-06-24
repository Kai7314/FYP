import 'package:supabase_flutter/supabase_flutter.dart';

import '../dataAccessLayer/repositories/auth_repository.dart';
import '../dataAccessLayer/repositories/user_repository.dart';

class AuthService {
  AuthService({AuthRepository? authRepository, UserRepository? userRepository})
    : authRepository = authRepository ?? AuthRepository(),
      userRepository = userRepository ?? UserRepository();

  final AuthRepository authRepository;
  final UserRepository userRepository;

  User? get currentUser => authRepository.currentUser;
  Session? get currentSession => authRepository.currentSession;
  Stream<AuthState> get authStateChanges => authRepository.authStateChanges;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return authRepository.signIn(email: email, password: password);
  }

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String fullName,
    required String emailRedirectTo,
  }) {
    return authRepository.register(
      email: email,
      password: password,
      fullName: fullName,
      emailRedirectTo: emailRedirectTo,
    );
  }

  Future<void> resendVerification({
    required String email,
    required String emailRedirectTo,
  }) {
    return authRepository.resendVerification(
      email: email,
      emailRedirectTo: emailRedirectTo,
    );
  }

  Future<AuthResponse> verifySignupCode({
    required String email,
    required String token,
    required String redirectTo,
  }) {
    return authRepository.verifySignupCode(
      email: email,
      token: token,
      redirectTo: redirectTo,
    );
  }

  Future<bool> signInWithOAuth({
    required OAuthProvider provider,
    required String redirectTo,
  }) {
    return authRepository.signInWithOAuth(
      provider: provider,
      redirectTo: redirectTo,
    );
  }

  Future<void> signOut() => authRepository.signOut();

  Future<void> handleUserProfile() async {
    final user = currentUser;
    if (user == null) return;

    try {
      await userRepository.createProfileIfMissing(
        userId: user.id,
        name:
            user.userMetadata?['full_name']?.toString().trim().isNotEmpty ==
                true
            ? user.userMetadata!['full_name'].toString()
            : (user.email?.split('@').first ?? 'EthernaCare User'),
      );
    } catch (_) {
      // Authentication remains valid if optional profile setup fails.
    }
  }
}
