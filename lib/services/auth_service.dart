import 'package:supabase_flutter/supabase_flutter.dart';

import '../dataAccessLayer/repositories/auth_repository.dart';
import '../dataAccessLayer/repositories/user_repository.dart';
import '../utils/validators.dart';

class AuthService {
  AuthService({AuthRepository? authRepository, UserRepository? userRepository})
    : authRepository = authRepository ?? AuthRepository(),
      userRepository = userRepository ?? UserRepository();

  final AuthRepository authRepository;
  final UserRepository userRepository;

  User? get currentUser => authRepository.currentUser;
  Session? get currentSession => authRepository.currentSession;
  Stream<AuthState> get authStateChanges => authRepository.authStateChanges;

  bool isExistingAccountSignup(AuthResponse response) {
    return AuthRepository.isExistingAccountSignup(response);
  }

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
    required String termsVersion,
    required DateTime termsAcceptedAt,
  }) {
    return authRepository.register(
      email: email,
      password: password,
      fullName: fullName,
      emailRedirectTo: emailRedirectTo,
      termsVersion: termsVersion,
      termsAcceptedAt: termsAcceptedAt,
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

  Future<void> requestPasswordReset({
    required String email,
    required String redirectTo,
  }) {
    return authRepository.requestPasswordReset(
      email: email,
      redirectTo: redirectTo,
    );
  }

  Future<AuthResponse> verifyPasswordRecoveryCode({
    required String email,
    required String token,
    required String redirectTo,
  }) {
    return authRepository.verifyPasswordRecoveryCode(
      email: email,
      token: token,
      redirectTo: redirectTo,
    );
  }

  Future<UserResponse> updatePassword(String password) {
    return authRepository.updatePassword(password);
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

    await userRepository.createProfileIfMissing(
      userId: user.id,
      name: _safeDisplayName(user),
    );
  }

  String _safeDisplayName(User user) {
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final candidates = [
      metadata['full_name'],
      metadata['name'],
      metadata['display_name'],
      metadata['preferred_username'],
      user.email?.split('@').first,
      'EthernaCare User',
    ];

    for (final candidate in candidates) {
      final cleaned = _cleanProfileName(candidate?.toString() ?? '');
      if (cleaned != null) return cleaned;
    }
    return 'EthernaCare User';
  }

  String? _cleanProfileName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r"[^A-Za-z .'-]"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.length < 2 || !RegExp(r'^[A-Za-z]').hasMatch(cleaned)) {
      return null;
    }
    if (cleaned.length <= AppValidators.maxDisplayNameLength) return cleaned;
    return null;
  }
}
