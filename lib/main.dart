import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/config/supabase_config.dart';
import 'core/constants/strings.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screen/admin/admin_auth_gate.dart';
import 'presentation/screen/auth/auth_gate.dart';
import 'services/background_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const configuredAdminMode = bool.fromEnvironment('ADMIN_MODE');

  bool get adminEntry {
    if (configuredAdminMode) return true;
    final platformRoute = Uri.tryParse(
      WidgetsBinding.instance.platformDispatcher.defaultRouteName,
    );
    if (platformRoute?.path == AppRoutes.adminRewards) return true;
    if (!kIsWeb) return false;

    final uri = Uri.base;
    final fragment = uri.fragment.startsWith('/')
        ? uri.fragment
        : '/${uri.fragment}';
    return uri.path == AppRoutes.adminRewards ||
        fragment == AppRoutes.adminRewards;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) {
        return SizedBox.expand(
          child: child ?? const _StartupScreen(message: 'Starting EthernaCare'),
        );
      },
      home: _AppBootstrap(adminMode: adminEntry),
    );
  }
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap({this.adminMode = false});

  final bool adminMode;

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  late Future<void> startupFuture = _start();

  Future<void> _start() async {
    await ensureSupabaseInitialized();

    unawaited(
      BackgroundService()
          .initialize()
          .timeout(const Duration(seconds: 8))
          .catchError((error, stackTrace) {
            debugPrint('Background setup skipped: $error');
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: startupFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupScreen(message: 'Starting EthernaCare');
        }

        if (snapshot.hasError) {
          return _StartupErrorScreen(
            error: snapshot.error,
            onRetry: () => setState(() {
              startupFuture = _start();
            }),
          );
        }

        return widget.adminMode ? const AdminAuthGate() : const AuthGate();
      },
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 42),
              const SizedBox(height: 12),
              const Text(
                'Could not start EthernaCare.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
