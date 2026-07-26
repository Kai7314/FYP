import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/reward_admin_service.dart';
import '../../widgets/premium_shell.dart';
import 'admin_login_screen.dart';
import 'admin_reward_catalog_screen.dart';

class AdminAuthGate extends StatefulWidget {
  const AdminAuthGate({super.key});

  @override
  State<AdminAuthGate> createState() => _AdminAuthGateState();
}

class _AdminAuthGateState extends State<AdminAuthGate> {
  final authService = AuthService();
  final adminService = RewardAdminService();

  String? checkedUserId;
  Future<bool>? adminCheck;

  Future<bool> _adminCheckFor(String userId) {
    if (checkedUserId != userId || adminCheck == null) {
      checkedUserId = userId;
      adminCheck = adminService
          .isCurrentUserAdmin()
          .timeout(const Duration(seconds: 18));
    }
    return adminCheck!;
  }

  void _retry() {
    setState(() {
      checkedUserId = null;
      adminCheck = null;
    });
  }

  Future<void> _signOut() async {
    await adminService.signOut();
    if (!mounted) return;
    setState(() {
      checkedUserId = null;
      adminCheck = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? authService.currentSession;
        if (session == null) {
          checkedUserId = null;
          adminCheck = null;
          return AdminLoginScreen(authService: authService);
        }

        return FutureBuilder<bool>(
          future: _adminCheckFor(session.user.id),
          builder: (context, adminSnapshot) {
            if (adminSnapshot.connectionState != ConnectionState.done) {
              return const _AdminGateStatus(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Checking admin access',
                message: 'Verifying this account with the server.',
                loading: true,
              );
            }

            if (adminSnapshot.hasError) {
              return _AdminGateStatus(
                icon: Icons.cloud_off_outlined,
                title: 'Could not verify access',
                message:
                    'The server could not confirm this administrator account.',
                primaryLabel: 'Retry',
                onPrimary: _retry,
                secondaryLabel: 'Sign out',
                onSecondary: _signOut,
              );
            }

            if (adminSnapshot.data != true) {
              return _AdminGateStatus(
                icon: Icons.lock_outline,
                title: 'Admin access required',
                message:
                    '${session.user.email ?? 'This account'} is not an active reward administrator.',
                primaryLabel: 'Sign out',
                onPrimary: _signOut,
              );
            }

            return AdminRewardCatalogScreen(
              adminService: adminService,
              adminEmail: session.user.email ?? 'Administrator',
            );
          },
        );
      },
    );
  }
}

class _AdminGateStatus extends StatelessWidget {
  const _AdminGateStatus({
    required this.icon,
    required this.title,
    required this.message,
    this.loading = false,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool loading;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: GlassPanel(
            padding: const EdgeInsets.all(24),
            color: AppColors.glassStrong,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const CircularProgressIndicator()
                else
                  Icon(icon, size: 44, color: AppColors.primaryDark),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, height: 1.4),
                ),
                if (primaryLabel != null && onPrimary != null) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onPrimary,
                      child: Text(primaryLabel!),
                    ),
                  ),
                ],
                if (secondaryLabel != null && onSecondary != null)
                  TextButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
