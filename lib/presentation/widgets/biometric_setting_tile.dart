import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../services/biometric_auth_service.dart';
import 'error_dialog.dart';

class BiometricSettingTile extends StatefulWidget {
  const BiometricSettingTile({
    super.key,
    required this.userId,
    this.biometricAuthService,
  });

  final String? userId;
  final BiometricAuthService? biometricAuthService;

  @override
  State<BiometricSettingTile> createState() => _BiometricSettingTileState();
}

class _BiometricSettingTileState extends State<BiometricSettingTile> {
  late final BiometricAuthService biometricAuthService =
      widget.biometricAuthService ?? BiometricAuthService();
  late Future<BiometricSetting> settingFuture = _loadSetting();
  bool busy = false;

  Future<BiometricSetting> _loadSetting() {
    final userId = widget.userId;
    if (userId == null) {
      return Future.value(
        const BiometricSetting(
          enabled: false,
          availability: BiometricAvailability.unsupported(),
        ),
      );
    }
    return biometricAuthService.getSetting(userId);
  }

  Future<void> _setEnabled(bool enabled) async {
    final userId = widget.userId;
    if (userId == null || busy) return;
    setState(() => busy = true);
    try {
      if (enabled) {
        final availability = await biometricAuthService.checkAvailability();
        if (!availability.available) {
          throw BiometricAuthException(
            availability.platformSupported
                ? 'Set up ${availability.methodLabel} in your device settings first.'
                : 'Biometric unlock is not supported on this platform.',
          );
        }
        final authenticated = await biometricAuthService.authenticate(
          reason: 'Confirm ${availability.methodLabel} for EthernaCare.',
          knownAvailability: availability,
        );
        if (!authenticated) {
          if (mounted) _showMessage('Biometric unlock was not enabled.');
          return;
        }
      }

      await biometricAuthService.setEnabledForUser(userId, enabled);
      if (!mounted) return;
      setState(() => settingFuture = _loadSetting());
      _showMessage(
        enabled
            ? 'Biometric unlock enabled on this device.'
            : 'Biometric unlock disabled on this device.',
      );
    } catch (error) {
      if (!mounted) return;
      await AppErrorDialog.show(
        context,
        title: 'Could not update biometric unlock',
        error: error,
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BiometricSetting>(
      future: settingFuture,
      builder: (context, snapshot) {
        final setting = snapshot.data;
        final availability = setting?.availability;
        final loading = snapshot.connectionState != ConnectionState.done || busy;
        final enabled = setting?.enabled ?? false;
        final available = availability?.available ?? false;
        final method = availability?.methodLabel ?? 'Biometrics';
        final subtitle = snapshot.hasError
            ? 'Biometric status unavailable.'
            : enabled
            ? 'Required when opening the app.'
            : available
            ? 'Unlock EthernaCare with $method.'
            : 'Set up device biometrics first.';

        return SwitchListTile.adaptive(
          key: const Key('biometric-unlock-switch'),
          value: enabled,
          onChanged: loading || (!available && !enabled) ? null : _setEnabled,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          visualDensity: VisualDensity.compact,
          secondary: CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: .1),
            foregroundColor: AppColors.primary,
            child: Icon(
              method.contains('Face') ? Icons.face_outlined : Icons.fingerprint,
              size: 20,
            ),
          ),
          title: const Text(
            'Biometric unlock',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}
