import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/colors.dart';
import '../../../services/auth_service.dart';
import '../../../utils/validators.dart';
import '../../widgets/premium_shell.dart';

enum _AuthView { login, register, verifyEmail }

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

  Timer? resendTimer;
  _AuthView view = _AuthView.login;
  bool loading = false;
  bool passwordVisible = false;
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
        );

        if (!mounted) return;
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
          'Your email is not verified yet. Open the latest email and tap the confirmation link.',
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
    if (!RegExp(r'^[0-9]{6}$').hasMatch(token)) {
      _showMessage('Enter the 6-digit code from your verification email.');
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
    setState(() => loading = true);
    try {
      await authService.resendVerification(
        email: emailController.text.trim(),
        emailRedirectTo: redirectUrl,
      );
      if (!mounted) return;
      _showMessage('A new confirmation email has been sent.');
      _startResendCooldown();
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
    return view == _AuthView.register
        ? AppValidators.registrationPassword(password, email: email, name: name)
        : AppValidators.loginPassword(password);
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
    final message =
        error is AuthException &&
            (error.code == 'over_email_send_rate_limit' ||
                error.statusCode == '429')
        ? 'The built-in Supabase email service reached its limit. Wait about one hour or configure custom SMTP in Supabase.'
        : error is AuthException && error.code == 'email_not_confirmed'
        ? 'Confirm your email before logging in.'
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
    setState(() {
      view = next;
      fieldError = null;
      loading = false;
    });
  }

  @override
  void dispose() {
    resendTimer?.cancel();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    verificationCodeController.dispose();
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
                registering ? 'Create your account' : 'Welcome back',
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
                    : 'Sign in to continue caring for Oren.',
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
            'We sent a confirmation link to\n${emailController.text.trim()}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          const _VerificationStep(
            number: 1,
            title: 'Open your email',
            detail: 'Find the latest message from Supabase.',
            complete: true,
          ),
          const _VerificationStep(
            number: 2,
            title: 'Tap the link or copy the code',
            detail: 'If the link opens a blank page, enter the code below.',
          ),
          const _VerificationStep(
            number: 3,
            title: 'Continue into the app',
            detail: 'Return here if the app does not open automatically.',
          ),
          const SizedBox(height: 22),
          TextField(
            controller: verificationCodeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!loading) verifyEmailCode();
            },
            decoration: const InputDecoration(
              labelText: '6-digit verification code',
              prefixIcon: Icon(Icons.password_outlined),
              helperText: 'Use the code from the latest verification email',
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
