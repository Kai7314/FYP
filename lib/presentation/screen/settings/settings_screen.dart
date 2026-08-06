import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../services/app_settings_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/user_service.dart';
import '../../widgets/biometric_setting_tile.dart';
import '../../widgets/error_dialog.dart';
import '../../widgets/premium_shell.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.onOpenFeatureGuide});

  final VoidCallback? onOpenFeatureGuide;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final settingsService = AppSettingsService.instance;
  final notificationService = NotificationService.instance;
  final userService = UserService();
  final Set<String> updating = {};

  Future<void> _update(
    String key,
    Future<void> Function() action, {
    Future<void> Function()? rollback,
  }) async {
    if (updating.contains(key)) return;
    setState(() => updating.add(key));
    try {
      await action();
    } catch (error) {
      if (rollback != null) await rollback();
      if (!mounted) return;
      await AppErrorDialog.show(
        context,
        title: 'Could not update setting',
        error: error,
      );
    } finally {
      if (mounted) setState(() => updating.remove(key));
    }
  }

  Future<void> _setLocalReminders(bool enabled) async {
    final previous = settingsService.current.localRemindersEnabled;
    await _update(
      'reminders',
      () async {
        await settingsService.setLocalRemindersEnabled(enabled);
        if (enabled) {
          await notificationService.initialize(requestPermission: true);
        } else {
          await notificationService.cancelSafetyNotifications();
        }
      },
      rollback: () => settingsService.setLocalRemindersEnabled(previous),
    );
  }

  Future<void> _restoreDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore default settings?'),
        content: const Text(
          'This restores reminders, Oren sounds, text size, and motion preferences. Biometric unlock is not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _update('restore', () async {
      await settingsService.resetToDefaults();
      await notificationService.initialize(requestPermission: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default settings restored.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  Future<void> _openFeatureGuide() async {
    final openGuide = widget.onOpenFeatureGuide;
    if (openGuide == null) return;
    Navigator.of(context).pop();
    await Future<void>.delayed(const Duration(milliseconds: 360));
    openGuide();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      child: Column(
        children: [
          PremiumHeader(
            title: 'Settings',
            subtitle: 'Personalise EthernaCare on this device',
            orenAsset:
                'lib/assets/images/pixel/oren_pixel_calm_transparent.png',
            orenSemanticLabel: 'Oren beside settings',
            action: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              tooltip: 'Close settings',
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ValueListenableBuilder<AppSettings>(
              valueListenable: settingsService.settings,
              builder: (context, settings, _) => ListView(
                children: [
                  _SettingsSection(
                    title: 'NOTIFICATIONS',
                    child: SwitchListTile.adaptive(
                      key: const Key('local-reminders-switch'),
                      value: settings.localRemindersEnabled,
                      onChanged: updating.contains('reminders')
                          ? null
                          : _setLocalReminders,
                      secondary: const _SettingIcon(
                        icon: Icons.notifications_active_outlined,
                        color: AppColors.blue,
                      ),
                      title: const Text(
                        'On-device reminders',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text(
                        'Show check-in and safety notifications on this device. Server SMS escalation remains active.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsSection(
                    title: 'OREN',
                    child: SwitchListTile.adaptive(
                      key: const Key('oren-sounds-switch'),
                      value: settings.orenSoundsEnabled,
                      onChanged: updating.contains('sounds')
                          ? null
                          : (value) => _update(
                              'sounds',
                              () => settingsService.setOrenSoundsEnabled(value),
                            ),
                      secondary: const _SettingIcon(
                        icon: Icons.volume_up_outlined,
                        color: AppColors.accent,
                      ),
                      title: const Text(
                        'Oren sound effects',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text(
                        'Play feedback sounds when feeding or playing with Oren.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsSection(
                    title: 'ACCESSIBILITY',
                    child: Column(
                      children: [
                        ListTile(
                          leading: const _SettingIcon(
                            icon: Icons.text_fields_rounded,
                            color: AppColors.purple,
                          ),
                          title: const Text(
                            'Text size',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: const Text(
                            'Use the system size or make EthernaCare text larger.',
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<AppTextSize>(
                              key: const Key('text-size-control'),
                              segments: const [
                                ButtonSegment(
                                  value: AppTextSize.system,
                                  icon: Icon(Icons.settings_suggest_outlined),
                                  label: Text('System'),
                                ),
                                ButtonSegment(
                                  value: AppTextSize.large,
                                  icon: Icon(Icons.format_size_rounded),
                                  label: Text('Large'),
                                ),
                              ],
                              selected: {settings.textSize},
                              onSelectionChanged: updating.contains('text')
                                  ? null
                                  : (selection) => _update(
                                      'text',
                                      () => settingsService.setTextSize(
                                        selection.first,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const Divider(height: 1, indent: 72),
                        SwitchListTile.adaptive(
                          key: const Key('reduce-motion-switch'),
                          value: settings.reduceMotion,
                          onChanged: updating.contains('motion')
                              ? null
                              : (value) => _update(
                                  'motion',
                                  () => settingsService.setReduceMotion(value),
                                ),
                          secondary: const _SettingIcon(
                            icon: Icons.motion_photos_off_outlined,
                            color: AppColors.primary,
                          ),
                          title: const Text(
                            'Reduce motion',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: const Text(
                            'Reduce page and guide animations where supported.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsSection(
                    title: 'ACCOUNT SECURITY',
                    child: BiometricSettingTile(
                      userId: userService.currentUserId,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsSection(
                    title: 'HELP',
                    child: ListTile(
                      key: const Key('feature-guide-setting'),
                      onTap: _openFeatureGuide,
                      leading: const _SettingIcon(
                        icon: Icons.menu_book_outlined,
                        color: AppColors.primary,
                      ),
                      title: const Text(
                        'Feature Guide',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text(
                        'Guide the live app screens step by step.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    key: const Key('restore-settings-button'),
                    onPressed: updating.contains('restore')
                        ? null
                        : _restoreDefaults,
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('Restore default settings'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        GlassPanel(
          padding: EdgeInsets.zero,
          color: AppColors.glassStrong,
          child: child,
        ),
      ],
    );
  }
}

class _SettingIcon extends StatelessWidget {
  const _SettingIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: color.withValues(alpha: .1),
      foregroundColor: color,
      child: Icon(icon, size: 22),
    );
  }
}
