import '../background/inactivity_monitor.dart';
import '../background/platform_background_scheduler.dart';
import '../background/scheduler.dart';

class BackgroundService {
  BackgroundService({
    AppScheduler? scheduler,
    InactivityMonitor? inactivityMonitor,
    PlatformBackgroundScheduler? platformBackgroundScheduler,
  }) : scheduler = scheduler ?? AppScheduler(),
       inactivityMonitor = inactivityMonitor ?? InactivityMonitor(),
       platformBackgroundScheduler =
           platformBackgroundScheduler ?? PlatformBackgroundScheduler();

  final AppScheduler scheduler;
  final InactivityMonitor inactivityMonitor;
  final PlatformBackgroundScheduler platformBackgroundScheduler;

  Future<void> initialize() async {
    await scheduler.initializeDailyTasks();
    await platformBackgroundScheduler.initialize();
    await inactivityMonitor.checkNow();
  }
}
