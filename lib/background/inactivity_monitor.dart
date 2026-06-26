import '../services/inactivity_service.dart';

class InactivityMonitor {
  InactivityMonitor({InactivityService? inactivityService})
    : inactivityService = inactivityService ?? InactivityService();

  final InactivityService inactivityService;

  Future<void> checkNow() => inactivityService.checkInactivity();
}
