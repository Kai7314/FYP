import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final supabase = Supabase.instance.client;
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLogin = true;
  bool loading = false;

  Future<void> authenticate() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password.')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      if (isLogin) {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        final res = await supabase.auth.signUp(
          email: email,
          password: password,
        );

        if (res.user != null) {
          await supabase.from('users').upsert({
            'id': res.user!.id,
            'name': 'New User',
          });
        }
      }

      if (!mounted) return;

      if (supabase.auth.currentSession != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else if (!isLogin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created. Please confirm your email, then log in.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> signInWithGoogle() async {
    await supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb
          ? Uri.base.origin
          : 'io.supabase.flutter://login-callback/',
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Icon(Icons.shield, size: 80, color: Colors.white),
                const SizedBox(height: 10),
                const Text(
                  'EthernaCare',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isLogin ? 'Welcome Back' : 'Create Account',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (!loading) authenticate();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: loading ? null : authenticate,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Text(isLogin ? 'Login' : 'Register'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: loading
                            ? null
                            : () {
                                setState(() => isLogin = !isLogin);
                              },
                        child: Text(
                          isLogin
                              ? "Don't have an account? Register"
                              : 'Already have an account? Login',
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text('OR'),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: loading ? null : signInWithGoogle,
                          icon: const Icon(Icons.login),
                          label: const Text('Continue with Google'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
