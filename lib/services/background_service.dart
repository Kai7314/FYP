import '../background/inactivity_monitor.dart';
import '../background/scheduler.dart';

class BackgroundService {
  BackgroundService({
    AppScheduler? scheduler,
    InactivityMonitor? inactivityMonitor,
  }) : scheduler = scheduler ?? AppScheduler(),
       inactivityMonitor = inactivityMonitor ?? InactivityMonitor();

  final AppScheduler scheduler;
  final InactivityMonitor inactivityMonitor;

  Future<void> initialize() async {
    await scheduler.initializeDailyTasks();
    await inactivityMonitor.checkNow();
  }
}
