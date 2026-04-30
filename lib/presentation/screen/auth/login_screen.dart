import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // 🔐 Email Auth
  Future<void> authenticate() async {
    setState(() => loading = true);

    try {
      if (isLogin) {
        await supabase.auth.signInWithPassword(
          email: emailController.text,
          password: passwordController.text,
        );
      } else {
        final res = await supabase.auth.signUp(
          email: emailController.text,
          password: passwordController.text,
        );

        // create user profile
        await supabase.from('users').insert({
          'id': res.user!.id,
          'name': 'New User',
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }

    setState(() => loading = false);
  }

  // 🔵 Google Login
  Future<void> signInWithGoogle() async {
    await supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.flutter://login-callback/',
    );
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
                  "SafeGuard",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 30),

                // 🧾 Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isLogin ? "Welcome Back" : "Create Account",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 20),

                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: "Email",
                          prefixIcon: Icon(Icons.email),
                        ),
                      ),

                      const SizedBox(height: 10),

                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "Password",
                          prefixIcon: Icon(Icons.lock),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 🔐 Login/Register Button
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
                              : Text(isLogin ? "Login" : "Register"),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // 🔁 Switch Mode
                      TextButton(
                        onPressed: () {
                          setState(() => isLogin = !isLogin);
                        },
                        child: Text(
                          isLogin
                              ? "Don't have an account? Register"
                              : "Already have an account? Login",
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text("OR"),

                      const SizedBox(height: 10),

                      // 🔵 Google Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: signInWithGoogle,
                          icon: const Icon(Icons.login),
                          label: const Text("Continue with Google"),
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
