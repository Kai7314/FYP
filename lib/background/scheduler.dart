import '../services/notification_service.dart';

class AppScheduler {
  AppScheduler({NotificationService? notificationService})
    : notificationService = notificationService ?? NotificationService.instance;

  final NotificationService notificationService;

  Future<void> initializeDailyTasks() async {
    await notificationService.initialize();
    await notificationService.scheduleDailyCheckInReminder();
  }
}
