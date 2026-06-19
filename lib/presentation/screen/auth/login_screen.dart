import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/colors.dart';
import '../home/home_screen.dart';

enum _AuthView { login, register, verifyEmail }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const mobileAuthCallback = 'io.supabase.flutter://login-callback/';

  // Enable this only after configuring Google OAuth in both Google Cloud and
  // Supabase Authentication > Providers > Google.
  static const googleOAuthEnabled = false;

  final supabase = Supabase.instance.client;
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  StreamSubscription<AuthState>? authSubscription;
  Timer? resendTimer;
  _AuthView view = _AuthView.login;
  bool loading = false;
  bool passwordVisible = false;
  bool navigating = false;
  int resendSeconds = 0;
  String? fieldError;

  @override
  void initState() {
    super.initState();
    authSubscription = supabase.auth.onAuthStateChange.listen((state) {
      if (state.session != null && mounted) _openHome();
    });
  }

  String get redirectUrl => kIsWeb ? Uri.base.origin : mobileAuthCallback;

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
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (supabase.auth.currentSession != null && mounted) _openHome();
      } else {
        final response = await supabase.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': name},
          emailRedirectTo: redirectUrl,
        );

        if (!mounted) return;
        if (response.session != null) {
          _openHome();
        } else {
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
      await supabase.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      if (supabase.auth.currentSession != null && mounted) _openHome();
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

  Future<void> resendVerification() async {
    if (resendSeconds > 0) return;
    setState(() => loading = true);
    try {
      await supabase.auth.resend(
        type: OtpType.signup,
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

  Future<void> signInWithGoogle() async {
    if (!googleOAuthEnabled) {
      _showMessage(
        'Google sign-in needs an OAuth client ID and secret configured in Supabase first.',
      );
      return;
    }
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
      );
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  String? _validate({
    required String email,
    required String password,
    required String name,
  }) {
    if (view == _AuthView.register && name.isEmpty) {
      return 'Please enter your name.';
    }
    if (email.isEmpty || !email.contains('@')) {
      return 'Please enter a valid email address.';
    }
    if (password.length < 6) {
      return 'Password must contain at least 6 characters.';
    }
    return null;
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
        ? 'Supabase has reached its email limit. Wait about one hour, then resend once.'
        : error is AuthException && error.code == 'email_not_confirmed'
        ? 'Confirm your email before logging in.'
        : errorText.contains('Failed host lookup')
        ? 'Cannot connect to Supabase. Check your internet connection.'
        : errorText;
    _showMessage(message);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _openHome() {
    if (!mounted || navigating) return;
    navigating = true;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
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
    authSubscription?.cancel();
    resendTimer?.cancel();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE5F8F2), Color(0xFFF7FBFA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: view == _AuthView.verifyEmail
                      ? _buildVerificationCard()
                      : _buildAuthCard(),
                ),
              ),
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
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x16008D68),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
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
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
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
              OutlinedButton.icon(
                onPressed: loading ? null : signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Text(
                  'G',
                  style: TextStyle(
                    color: AppColors.blue,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                label: Text(
                  googleOAuthEnabled
                      ? 'Continue with Google'
                      : 'Google sign-in — setup required',
                ),
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
    return Container(
      key: const ValueKey('verify-email'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16008D68),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
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
            title: 'Tap Confirm your email',
            detail: 'The link will return you to EthernaCare.',
          ),
          const _VerificationStep(
            number: 3,
            title: 'Continue into the app',
            detail: 'Return here if the app does not open automatically.',
          ),
          const SizedBox(height: 22),
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
