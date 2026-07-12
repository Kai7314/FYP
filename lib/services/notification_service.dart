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
    required int missedCheckIns,
    required int requiredMissedCheckIns,
    bool testMode = false,
  }) async {
    if (kIsWeb) return;
    await initialize();
    await plugin.show(
      id: missedCheckInNotificationId,
      title: testMode
          ? 'Test reminder $missedCheckIns of $requiredMissedCheckIns'
          : 'Oren needs your check-in',
      body: testMode
          ? missedCheckIns >= requiredMissedCheckIns
                ? 'Third test reminder reached. EthernaCare is testing the primary-contact SMS now.'
                : 'This is a safe notification test. No SMS is sent until test reminder 3 of 3.'
          : missedCheckIns >= requiredMissedCheckIns
          ? 'Missed check-in $missedCheckIns of $requiredMissedCheckIns. EthernaCare is starting your configured emergency escalation now.'
          : 'Missed check-in $missedCheckIns of $requiredMissedCheckIns. Open EthernaCare and tap Oren before reminder 3 starts your configured emergency escalation.',
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

  Future<void> showOfficial999EscalationNotice() async {
    if (kIsWeb) return;
    await initialize();
    await plugin.show(
      id: missedCheckInNotificationId + 1,
      title: 'Emergency escalation recorded',
      body:
          'Your setting is 999. EthernaCare recorded the alert, but emergency services require a direct call to 999.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'official_999_escalation',
          '999 escalation notices',
          channelDescription:
              'Explains when an inactivity alert is configured for 999.',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
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
