import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();
  static const missedCheckInNotificationId = 1002;
  final plugin = FlutterLocalNotificationsPlugin();
  bool initialized = false;

  Future<void> initialize({bool requestPermission = true}) async {
    if (initialized || kIsWeb) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await plugin.initialize(settings: settings);
    if (requestPermission) {
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
    initialized = true;
  }

  Future<void> scheduleDailyCheckInReminder() async {
    if (kIsWeb) return;
    await initialize(requestPermission: false);
    await plugin.periodicallyShow(
      id: 1001,
      title: 'Oren is waiting for you',
      body: 'Open EthernaCare and complete today\'s safety check-in.',
      repeatInterval: RepeatInterval.daily,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_check_in',
          'Daily check-in reminders',
          channelDescription: 'Reminds users to pet Oren and check in.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> showMissedCheckInReminder({
    required int overdueHours,
    required int graceMinutes,
  }) async {
    if (kIsWeb) return;
    await initialize();
    await plugin.show(
      id: missedCheckInNotificationId,
      title: 'Oren needs your check-in',
      body:
          'Your safety check-in is $overdueHours hours overdue. Open EthernaCare within $graceMinutes minutes to prevent an emergency alert.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'missed_check_in',
          'Missed check-in alerts',
          channelDescription:
              'High-priority reminders before emergency contact escalation.',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
