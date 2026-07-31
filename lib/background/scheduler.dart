import '../services/notification_service.dart';

class AppScheduler {
  AppScheduler({NotificationService? notificationService})
    : notificationService = notificationService ?? NotificationService.instance;

  final NotificationService notificationService;

  Future<void> initializeDailyTasks() async {
    await notificationService.initialize();
    // Threshold reminders are evaluated by InactivityService. Remove the old
    // calendar-day notification so it cannot disagree with the user's hours.
    await notificationService.cancelDailyCheckInReminder();
  }
}
