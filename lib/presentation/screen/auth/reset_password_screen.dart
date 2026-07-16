import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/colors.dart';
import '../../../services/auth_service.dart';
import '../../../utils/validators.dart';
import '../../widgets/premium_shell.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late final AuthService authService = widget.authService ?? AuthService();
  final passwordController = TextEditingController();
  final confirmationController = TextEditingController();

  bool loading = false;
  bool passwordVisible = false;
  bool confirmationVisible = false;
  String? fieldError;

  Future<void> _updatePassword() async {
    final password = passwordController.text;
    final confirmation = confirmationController.text;
    final passwordError = AppValidators.registrationPassword(password);
    final validationError = passwordError ??
        (password != confirmation ? 'The passwords do not match.' : null);

    if (validationError != null) {
      setState(() => fieldError = validationError);
      return;
    }

    setState(() {
      loading = true;
      fieldError = null;
    });

    try {
      await authService.updatePassword(password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed. Sign in with your new password.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await authService.signOut();
    } catch (error) {
      if (!mounted) return;
      final message = error is AuthSessionMissingException ||
              (error is AuthException && error.statusCode == '401')
          ? 'This password reset link or code has expired. Request a new reset email.'
          : 'Could not change the password: $error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _cancelRecovery() async {
    if (loading) return;
    setState(() => loading = true);
    try {
      await authService.signOut();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmationController.dispose();
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
            child: GlassPanel(
              padding: const EdgeInsets.all(24),
              color: AppColors.glassStrong,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.primarySoft,
                    child: Icon(
                      Icons.lock_reset_outlined,
                      color: AppColors.primary,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Choose a new password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use a password you have not used for EthernaCare before.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: passwordController,
                    obscureText: !passwordVisible,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'New password',
                      helperText: '8+ chars with upper, lower, number, and symbol',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => passwordVisible = !passwordVisible,
                        ),
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmationController,
                    obscureText: !confirmationVisible,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onSubmitted: (_) {
                      if (!loading) _updatePassword();
                    },
                    decoration: InputDecoration(
                      labelText: 'Confirm new password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => confirmationVisible = !confirmationVisible,
                        ),
                        icon: Icon(
                          confirmationVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        tooltip: confirmationVisible
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
                  FilledButton.icon(
                    onPressed: loading ? null : _updatePassword,
                    icon: loading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(loading ? 'Changing...' : 'Change Password'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: loading ? null : _cancelRecovery,
                    child: const Text('Cancel and return to sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
