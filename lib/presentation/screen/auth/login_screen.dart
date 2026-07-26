import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_terms.dart';
import '../../../core/constants/colors.dart';
import '../../../services/auth_service.dart';
import '../../../utils/validators.dart';
import '../../widgets/premium_shell.dart';
import '../legal/terms_and_conditions_screen.dart';
import '../planning/legacy_check_screen.dart';

enum _AuthView { login, register, verifyEmail, forgotPassword }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const mobileAuthCallback = 'io.supabase.flutter://login-callback/';
  static const configuredAuthRedirect = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
  );

  final authService = AuthService();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final verificationCodeController = TextEditingController();
  final recoveryCodeController = TextEditingController();

  Timer? resendTimer;
  _AuthView view = _AuthView.login;
  bool loading = false;
  bool passwordVisible = false;
  bool passwordResetEmailSent = false;
  bool registrationTermsReviewed = false;
  bool acceptedRegistrationTerms = false;
  DateTime? registrationTermsAcceptedAt;
  int resendSeconds = 0;
  String? fieldError;

  @override
  void initState() {
    super.initState();
  }

  String get redirectUrl {
    if (configuredAuthRedirect.isNotEmpty) return configuredAuthRedirect;
    return kIsWeb ? Uri.base.origin : mobileAuthCallback;
  }

  Future<void> authenticate() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final name = nameController.text.trim();

    final validation = _validate(email: email, password: password, name: name);
    if (validation != null) {
      setState(() => fieldError = validation);
      return;
    }

    setState(() {
      loading = true;
      fieldError = null;
    });

    try {
      if (view == _AuthView.login) {
        await authService.signIn(email: email, password: password);
      } else {
        final response = await authService.register(
          email: email,
          password: password,
          fullName: AppValidators.normalizeSpaces(name),
          emailRedirectTo: redirectUrl,
          termsVersion: AppTerms.version,
          termsAcceptedAt:
              registrationTermsAcceptedAt ?? DateTime.now().toUtc(),
        );

        if (!mounted) return;
        if (authService.isExistingAccountSignup(response)) {
          setState(() => view = _AuthView.login);
          _showMessage(
            'An account already uses this email. Sign in or use Forgot password.',
          );
          return;
        }
        if (response.session == null) {
          setState(() => view = _AuthView.verifyEmail);
          _startResendCooldown();
        }
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> checkVerification() async {
    setState(() => loading = true);
    try {
      await authService.signIn(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      if (error.code == 'email_not_confirmed') {
        _showMessage(
          'Your email is not verified yet. Enter the code from the latest email or use its confirmation link.',
        );
      } else {
        _showError(error);
      }
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> verifyEmailCode() async {
    final email = emailController.text.trim();
    final token = verificationCodeController.text.trim();
    if (AppValidators.email(email) != null) {
      _showMessage('Enter the same email address used to register.');
      return;
    }
    final codeError = AppValidators.emailVerificationCode(token);
    if (codeError != null) {
      _showMessage(codeError);
      return;
    }

    setState(() => loading = true);
    try {
      await authService.verifySignupCode(
        email: email,
        token: token,
        redirectTo: redirectUrl,
      );
      if (!mounted) return;
      _showMessage('Email verified. Welcome to EthernaCare.');
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resendVerification() async {
    if (resendSeconds > 0) return;
    final email = emailController.text.trim();
    if (AppValidators.email(email) != null) {
      _showMessage('Enter the same email address used to register.');
      return;
    }
    setState(() => loading = true);
    try {
      await authService.resendVerification(
        email: email,
        emailRedirectTo: redirectUrl,
      );
      if (!mounted) return;
      _showMessage(
        'A new verification email was requested. Check your inbox and spam folder.',
      );
      _startResendCooldown();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> requestPasswordReset() async {
    if (resendSeconds > 0) return;
    final email = emailController.text.trim();
    final emailError = AppValidators.email(email);
    if (emailError != null) {
      setState(() => fieldError = emailError);
      return;
    }

    setState(() {
      loading = true;
      fieldError = null;
    });
    try {
      await authService.requestPasswordReset(
        email: email,
        redirectTo: redirectUrl,
      );
      if (!mounted) return;
      setState(() => passwordResetEmailSent = true);
      _showMessage(
        'If an EthernaCare account uses this email, its password reset message is on the way.',
      );
      _startResendCooldown();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> verifyPasswordRecoveryCode() async {
    final email = emailController.text.trim();
    final token = recoveryCodeController.text.trim();
    final emailError = AppValidators.email(email);
    final codeError = AppValidators.emailVerificationCode(token);
    if (emailError != null || codeError != null) {
      setState(() => fieldError = emailError ?? codeError);
      return;
    }

    setState(() {
      loading = true;
      fieldError = null;
    });
    try {
      await authService.verifyPasswordRecoveryCode(
        email: email,
        token: token,
        redirectTo: redirectUrl,
      );
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> signInWithProvider(OAuthProvider provider) async {
    setState(() => loading = true);
    try {
      await authService.signInWithOAuth(
        provider: provider,
        redirectTo: redirectUrl,
      );
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String? _validate({
    required String email,
    required String password,
    required String name,
  }) {
    if (view == _AuthView.register) {
      final nameError = AppValidators.displayName(name);
      if (nameError != null) return nameError;
    }
    final emailError = AppValidators.email(email);
    if (emailError != null) return emailError;
    final passwordError = view == _AuthView.register
        ? AppValidators.registrationPassword(password, email: email, name: name)
        : AppValidators.loginPassword(password);
    if (passwordError != null) return passwordError;
    if (view == _AuthView.register && !acceptedRegistrationTerms) {
      return 'Read and accept the Terms and Conditions before creating an account.';
    }
    return null;
  }

  Future<void> _openRegistrationTerms() async {
    final accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            const TermsAndConditionsScreen(acceptanceMode: true),
      ),
    );
    if (!mounted || accepted != true) return;
    setState(() {
      registrationTermsReviewed = true;
      acceptedRegistrationTerms = true;
      registrationTermsAcceptedAt = DateTime.now().toUtc();
      fieldError = null;
    });
  }

  Future<void> _setRegistrationTerms(bool? value) async {
    if (value == true && !registrationTermsReviewed) {
      await _openRegistrationTerms();
      return;
    }
    setState(() {
      acceptedRegistrationTerms = value ?? false;
      registrationTermsAcceptedAt = acceptedRegistrationTerms
          ? DateTime.now().toUtc()
          : null;
    });
  }

  void _startResendCooldown() {
    resendTimer?.cancel();
    setState(() => resendSeconds = 60);
    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => resendSeconds = 0);
      } else {
        setState(() => resendSeconds--);
      }
    });
  }

  void _showError(Object error) {
    final errorText = error.toString();
    final normalizedError = errorText.toLowerCase();
    final message =
        error is AuthException &&
            (error.code == 'over_email_send_rate_limit' ||
                error.statusCode == '429')
        ? 'The built-in Supabase email service reached its limit. Wait about one hour or configure custom SMTP in Supabase.'
        : (error is AuthException && error.statusCode == '504') ||
              normalizedError.contains('upstream request timeout')
        ? 'The email service took too long to respond. Wait one minute, then try once more. If this continues, email delivery needs administrator attention.'
        : (error is AuthException &&
                  error.code == 'email_address_not_authorized') ||
              normalizedError.contains('error sending confirmation email') ||
              normalizedError.contains('error sending recovery email')
        ? 'We could not send the email. Email delivery is not configured for this address yet. Please try again later or contact EthernaCare support.'
        : (error is AuthException && error.code == 'user_already_exists') ||
              normalizedError.contains('user already registered')
        ? 'An account already uses this email. Sign in or use Forgot password.'
        : error is AuthException && error.code == 'email_not_confirmed'
        ? 'Confirm your email before logging in.'
        : error is AuthException &&
              (error.code == 'otp_expired' ||
                  error.code == 'otp_disabled' ||
                  error.code == 'validation_failed')
        ? 'That verification code is invalid or expired. Request a new email and use its latest code.'
        : errorText.contains('Failed host lookup') ||
              errorText.contains('Failed to fetch')
        ? 'Cannot reach Supabase. Check the device internet connection, then try again.'
        : errorText;
    _showMessage(message);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _changeView(_AuthView next) {
    resendTimer?.cancel();
    setState(() {
      view = next;
      fieldError = null;
      loading = false;
      resendSeconds = 0;
      if (next != _AuthView.forgotPassword) {
        passwordResetEmailSent = false;
        recoveryCodeController.clear();
      }
      if (next != _AuthView.register) {
        registrationTermsReviewed = false;
        acceptedRegistrationTerms = false;
        registrationTermsAcceptedAt = null;
      }
    });
  }

  @override
  void dispose() {
    resendTimer?.cancel();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    verificationCodeController.dispose();
    recoveryCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      padding: const EdgeInsets.all(22),
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: view == _AuthView.verifyEmail
                  ? _buildVerificationCard()
                  : view == _AuthView.forgotPassword
                  ? _buildForgotPasswordCard()
                  : _buildAuthCard(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthCard() {
    final registering = view == _AuthView.register;
    return Column(
      key: ValueKey(view),
      children: [
        _buildBrand(),
        const SizedBox(height: 26),
        GlassPanel(
          padding: const EdgeInsets.all(22),
          color: AppColors.glassStrong,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                registering ? 'Create your account' : 'Welcome to EthernaCare',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                registering
                    ? 'Start your daily well-being check-ins.'
                    : 'Meet Oren, your virtual companion for simple daily safety check-ins.',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 22),
              if (registering) ...[
                TextField(
                  controller: nameController,
                  maxLength: AppValidators.maxDisplayNameLength,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                    helperText:
                        '2-50 letters; spaces, apostrophes, and hyphens allowed',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: !passwordVisible,
                textInputAction: TextInputAction.done,
                autofillHints: registering
                    ? const [AutofillHints.newPassword]
                    : const [AutofillHints.password],
                onSubmitted: (_) {
                  if (!loading) authenticate();
                },
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: registering
                      ? '8+ chars with upper, lower, number, and symbol'
                      : null,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => passwordVisible = !passwordVisible),
                    icon: Icon(
                      passwordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    tooltip: passwordVisible
                        ? 'Hide password'
                        : 'Show password',
                  ),
                ),
              ),
              if (registering) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const Key('read-registration-terms-button'),
                  onPressed: loading ? null : _openRegistrationTerms,
                  icon: const Icon(Icons.policy_outlined),
                  label: Text(
                    registrationTermsReviewed
                        ? 'Review Terms and Conditions'
                        : 'Read Terms and Conditions',
                  ),
                ),
                CheckboxListTile(
                  key: const Key('registration-terms-checkbox'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: acceptedRegistrationTerms,
                  onChanged: loading ? null : _setRegistrationTerms,
                  title: const Text(
                    'I agree to the Terms and Conditions, including the privacy and safety notices.',
                    style: TextStyle(fontSize: 14, height: 1.3),
                  ),
                ),
              ],
              if (!registering)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: loading
                        ? null
                        : () => _changeView(_AuthView.forgotPassword),
                    child: const Text('Forgot password?'),
                  ),
                ),
              if (fieldError != null) ...[
                const SizedBox(height: 10),
                Text(
                  fieldError!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: loading ? null : authenticate,
                child: loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : Text(registering ? 'Create Account' : 'Sign In'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              _OAuthButton(
                label: 'Continue with Google',
                mark: 'G',
                markColor: AppColors.blue,
                onPressed: loading
                    ? null
                    : () => signInWithProvider(OAuthProvider.google),
              ),
              const SizedBox(height: 10),
              _OAuthButton(
                label: 'Continue with Facebook',
                mark: 'f',
                markColor: const Color(0xFF1877F2),
                onPressed: loading
                    ? null
                    : () => signInWithProvider(OAuthProvider.facebook),
              ),
              const SizedBox(height: 10),
              _OAuthButton(
                label: 'Continue with GitHub',
                mark: '{}',
                markColor: AppColors.ink,
                onPressed: loading
                    ? null
                    : () => signInWithProvider(OAuthProvider.github),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: loading
                    ? null
                    : () => _changeView(
                        registering ? _AuthView.login : _AuthView.register,
                      ),
                child: Text(
                  registering
                      ? 'Already have an account? Sign in'
                      : 'New to EthernaCare? Create an account',
                ),
              ),
              if (!registering) ...[
                const SizedBox(height: 4),
                const Divider(),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: loading
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LegacyCheckScreen(),
                          ),
                        ),
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Check Legacy Access'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Your daily check-in helps trusted people know you are safe.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildForgotPasswordCard() {
    return Column(
      key: const ValueKey('forgot-password'),
      children: [
        _buildBrand(),
        const SizedBox(height: 26),
        GlassPanel(
          padding: const EdgeInsets.all(24),
          color: AppColors.glassStrong,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primarySoft,
                child: Icon(
                  Icons.lock_reset_outlined,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                passwordResetEmailSent
                    ? 'Enter your reset code'
                    : 'Reset your password',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                passwordResetEmailSent
                    ? 'Use the eight-digit code from the latest reset email. The reset link in that email also works.'
                    : 'Enter your account email to receive a secure password reset link and code.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: emailController,
                enabled: !passwordResetEmailSent && !loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: passwordResetEmailSent
                    ? TextInputAction.next
                    : TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                onSubmitted: (_) {
                  if (!loading && !passwordResetEmailSent) {
                    requestPasswordReset();
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              if (passwordResetEmailSent) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: recoveryCodeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: AppValidators.emailVerificationCodeLength,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!loading) verifyPasswordRecoveryCode();
                  },
                  decoration: const InputDecoration(
                    labelText: '8-digit reset code',
                    prefixIcon: Icon(Icons.password_outlined),
                    helperText: 'Only the newest reset code will work',
                  ),
                ),
              ],
              if (fieldError != null) ...[
                const SizedBox(height: 10),
                Text(
                  fieldError!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: loading ||
                        (!passwordResetEmailSent && resendSeconds > 0)
                    ? null
                    : passwordResetEmailSent
                    ? verifyPasswordRecoveryCode
                    : requestPasswordReset,
                icon: loading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        passwordResetEmailSent
                            ? Icons.verified_outlined
                            : Icons.send_outlined,
                      ),
                label: Text(
                  loading
                      ? 'Please wait...'
                      : !passwordResetEmailSent && resendSeconds > 0
                      ? 'Send available in ${resendSeconds}s'
                      : passwordResetEmailSent
                      ? 'Verify Reset Code'
                      : 'Send Reset Email',
                ),
              ),
              if (passwordResetEmailSent) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: loading || resendSeconds > 0
                      ? null
                      : requestPasswordReset,
                  child: Text(
                    resendSeconds > 0
                        ? 'Resend available in ${resendSeconds}s'
                        : 'Resend reset email',
                  ),
                ),
                TextButton(
                  onPressed: loading
                      ? null
                      : () => setState(() {
                          passwordResetEmailSent = false;
                          recoveryCodeController.clear();
                          fieldError = null;
                        }),
                  child: const Text('Use a different email'),
                ),
              ],
              TextButton(
                onPressed: loading ? null : () => _changeView(_AuthView.login),
                child: const Text('Back to sign in'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationCard() {
    return GlassPanel(
      key: const ValueKey('verify-email'),
      padding: const EdgeInsets.all(24),
      color: AppColors.glassStrong,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CircleAvatar(
            radius: 34,
            backgroundColor: AppColors.primarySoft,
            child: Icon(
              Icons.mark_email_read_outlined,
              color: AppColors.primary,
              size: 36,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Verify your email',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We sent an eight-digit verification code to\n${emailController.text.trim()}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          const _VerificationStep(
            number: 1,
            title: 'Open your email',
            detail: 'Find the latest EthernaCare verification message.',
            complete: true,
          ),
          const _VerificationStep(
            number: 2,
            title: 'Copy the latest code',
            detail: 'Check the spam folder if the message is not in your inbox.',
          ),
          const _VerificationStep(
            number: 3,
            title: 'Verify in EthernaCare',
            detail: 'Enter the code below. The email link also remains available.',
          ),
          const SizedBox(height: 22),
          TextField(
            controller: verificationCodeController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: AppValidators.emailVerificationCodeLength,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!loading) verifyEmailCode();
            },
            decoration: const InputDecoration(
              labelText: '8-digit verification code',
              prefixIcon: Icon(Icons.password_outlined),
              helperText: 'Only the newest verification code will work',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: loading ? null : verifyEmailCode,
            icon: const Icon(Icons.verified_outlined),
            label: Text(loading ? 'Verifying...' : 'Verify Code In App'),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: loading ? null : checkVerification,
            icon: const Icon(Icons.verified_outlined),
            label: Text(loading ? 'Checking...' : 'I Have Verified My Email'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: loading || resendSeconds > 0 ? null : resendVerification,
            child: Text(
              resendSeconds > 0
                  ? 'Resend available in ${resendSeconds}s'
                  : 'Resend confirmation email',
            ),
          ),
          TextButton(
            onPressed: loading ? null : () => _changeView(_AuthView.register),
            child: const Text('Use a different email'),
          ),
        ],
      ),
    );
  }

  Widget _buildBrand() {
    return const Column(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: AppColors.primary,
          child: Icon(Icons.shield_outlined, color: Colors.white, size: 36),
        ),
        SizedBox(height: 12),
        Text(
          'EthernaCare',
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'A gentle daily signal that you are safe',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
      ],
    );
  }
}

class _OAuthButton extends StatelessWidget {
  const _OAuthButton({
    required this.label,
    required this.mark,
    required this.markColor,
    required this.onPressed,
  });

  final String label;
  final String mark;
  final Color markColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Text(
        mark,
        style: TextStyle(
          color: markColor,
          fontSize: 19,
          fontWeight: FontWeight.w900,
        ),
      ),
      label: Text(label),
    );
  }
}

class _VerificationStep extends StatelessWidget {
  const _VerificationStep({
    required this.number,
    required this.title,
    required this.detail,
    this.complete = false,
  });

  final int number;
  final String title;
  final String detail;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: complete
                ? AppColors.primary
                : AppColors.primarySoft,
            foregroundColor: complete ? Colors.white : AppColors.primaryDark,
            child: complete
                ? const Icon(Icons.check, size: 20)
                : Text(
                    '$number',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
