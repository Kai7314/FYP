import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/colors.dart';
import '../../../services/auth_service.dart';
import '../../../utils/validators.dart';
import '../../widgets/premium_shell.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool passwordVisible = false;

  Future<void> _signIn() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      await widget.authService.signIn(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is AuthException
          ? 'The email or password is incorrect, or this account cannot sign in.'
          : 'Could not reach the authentication server. Try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: AutofillGroup(
              child: Form(
                key: formKey,
                child: GlassPanel(
                  padding: const EdgeInsets.all(24),
                  color: AppColors.glassStrong,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CircleAvatar(
                        radius: 34,
                        backgroundColor: AppColors.primary,
                        child: Icon(
                          Icons.admin_panel_settings_outlined,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Reward Admin',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sign in with an allowlisted administrator account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: emailController,
                        enabled: !loading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: (value) =>
                            AppValidators.email(value ?? ''),
                        decoration: const InputDecoration(
                          labelText: 'Admin email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: passwordController,
                        enabled: !loading,
                        obscureText: !passwordVisible,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        validator: (value) =>
                            AppValidators.loginPassword(value ?? ''),
                        onFieldSubmitted: (_) {
                          if (!loading) _signIn();
                        },
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: passwordVisible
                                ? 'Hide password'
                                : 'Show password',
                            onPressed: loading
                                ? null
                                : () => setState(
                                    () => passwordVisible = !passwordVisible,
                                  ),
                            icon: Icon(
                              passwordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: loading ? null : _signIn,
                        icon: loading
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(
                          loading ? 'Signing in...' : 'Sign In to Admin',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
