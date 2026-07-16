import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  final SupabaseClient client;

  User? get currentUser => client.auth.currentUser;
  Session? get currentSession => client.auth.currentSession;
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  static bool isExistingAccountSignup(AuthResponse response) {
    final identities = response.user?.identities;
    return response.session == null &&
        identities != null &&
        identities.isEmpty;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String fullName,
    required String emailRedirectTo,
  }) {
    return client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
      emailRedirectTo: emailRedirectTo,
    );
  }

  Future<void> resendVerification({
    required String email,
    required String emailRedirectTo,
  }) {
    return client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: emailRedirectTo,
    );
  }

  Future<AuthResponse> verifySignupCode({
    required String email,
    required String token,
    required String redirectTo,
  }) {
    return client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
      redirectTo: redirectTo,
    );
  }

  Future<void> requestPasswordReset({
    required String email,
    required String redirectTo,
  }) {
    return client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }

  Future<AuthResponse> verifyPasswordRecoveryCode({
    required String email,
    required String token,
    required String redirectTo,
  }) {
    return client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.recovery,
      redirectTo: redirectTo,
    );
  }

  Future<UserResponse> updatePassword(String password) {
    return client.auth.updateUser(UserAttributes(password: password));
  }

  Future<bool> signInWithOAuth({
    required OAuthProvider provider,
    required String redirectTo,
  }) {
    return client.auth.signInWithOAuth(
      provider,
      redirectTo: redirectTo,
    );
  }

  Future<void> signOut() => client.auth.signOut();
}
