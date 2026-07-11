import '../dataAccessLayer/repositories/auth_repository.dart';
import '../dataAccessLayer/repositories/checkin_repository.dart';
import '../dataAccessLayer/repositories/emergency_repository.dart';
import '../dataAccessLayer/repositories/user_repository.dart';
import '../models/emergency_escalation_target.dart';
import 'emergency_service.dart';
import 'local_cache_service.dart';
import 'notification_service.dart';

class InactivityReminderTestResult {
  const InactivityReminderTestResult({
    required this.reminderCount,
    this.emergencyResult,
  });

  final int reminderCount;
  final EmergencyTriggerResult? emergencyResult;

  bool get smsTriggered => emergencyResult != null;
}

class InactivityMonitorStatus {
  const InactivityMonitorStatus({
    required this.notificationCount,
    required this.escalated,
  });

  const InactivityMonitorStatus.clear()
    : notificationCount = 0,
      escalated = false;

  final int notificationCount;
  final bool escalated;
}

class InactivityService {
  InactivityService({
    AuthRepository? authRepository,
    CheckinRepository? checkinRepository,
    UserRepository? userRepository,
    EmergencyRepository? emergencyRepository,
    EmergencyService? emergencyService,
    LocalCacheService? cache,
    NotificationService? notificationService,
    DateTime Function()? clock,
  }) : authRepository = authRepository ?? AuthRepository(),
       checkinRepository = checkinRepository ?? CheckinRepository(),
       userRepository = userRepository ?? UserRepository(),
       emergencyRepository = emergencyRepository ?? EmergencyRepository(),
       emergencyService = emergencyService ?? EmergencyService(),
       cache = cache ?? LocalCacheService(),
       notificationService = notificationService ?? NotificationService.instance,
       clock = clock ?? DateTime.now;

  static const missedCheckInsBeforeEscalation = 3;

  static int calculateMissedCheckIns({
    required DateTime lastCheckIn,
    required DateTime now,
    required int thresholdHours,
  }) {
    final safeThreshold = thresholdHours.clamp(1, 168).toInt();
    final elapsed = now.difference(lastCheckIn);
    if (elapsed.isNegative) return 0;
    return elapsed.inSeconds ~/ Duration(hours: safeThreshold).inSeconds;
  }

  static int nextTestReminderCount(int currentCount) {
    if (currentCount < 0 || currentCount >= missedCheckInsBeforeEscalation) {
      return 1;
    }
    return currentCount + 1;
  }

  final AuthRepository authRepository;
  final CheckinRepository checkinRepository;
  final UserRepository userRepository;
  final EmergencyRepository emergencyRepository;
  final EmergencyService emergencyService;
  final LocalCacheService cache;
  final NotificationService notificationService;
  final DateTime Function() clock;

  String _warningCacheKey(String userId) => 'missed_checkin_warning_v2_$userId';

  Future<InactivityMonitorStatus> getCurrentStatus({
    DateTime? latestCheckIn,
  }) async {
    final user = authRepository.currentUser;
    if (user == null) return const InactivityMonitorStatus.clear();

    final warning = await cache.readMap(_warningCacheKey(user.id));
    if (warning == null) return const InactivityMonitorStatus.clear();

    final trackedCheckIn = DateTime.tryParse(
      warning['last_checkin_at']?.toString() ?? '',
    );
    if (latestCheckIn != null &&
        (trackedCheckIn == null || trackedCheckIn.isBefore(latestCheckIn))) {
      return const InactivityMonitorStatus.clear();
    }

    final notificationCount =
        (int.tryParse(warning['last_notified_miss']?.toString() ?? '') ?? 0)
            .clamp(0, missedCheckInsBeforeEscalation)
            .toInt();
    return InactivityMonitorStatus(
      notificationCount: notificationCount,
      escalated: warning['escalated'] == true,
    );
  }

  Future<InactivityReminderTestResult> triggerReminderTest({
    required int currentCount,
  }) async {
    final reminderCount = nextTestReminderCount(currentCount);
    await notificationService.showMissedCheckInReminder(
      missedCheckIns: reminderCount,
      requiredMissedCheckIns: missedCheckInsBeforeEscalation,
      testMode: true,
    );

    if (reminderCount < missedCheckInsBeforeEscalation) {
      return InactivityReminderTestResult(reminderCount: reminderCount);
    }

    final emergencyResult = await emergencyService.triggerEmergencyDetailed(
      allow999Dialer: false,
      sendAutomatedSms: true,
      escalationTarget: EmergencyEscalationTarget.primaryContact,
      testMode: true,
    );
    return InactivityReminderTestResult(
      reminderCount: reminderCount,
      emergencyResult: emergencyResult,
    );
  }

  Future<void> checkInactivity() async {
    final user = authRepository.currentUser;
    if (user == null) return;

    final results = await Future.wait([
      checkinRepository.getLatestCheckin(user.id),
      userRepository.getProfile(user.id),
      emergencyRepository.getLatestTriggeredAlert(user.id),
    ]);
    final checkin = results[0];
    if (checkin == null) return;
    final profile = results[1];
    final alert = results[2];
    final configuredThreshold =
        int.tryParse(profile?['inactivity_threshold']?.toString() ?? '') ?? 24;
    final threshold = configuredThreshold.clamp(1, 168).toInt();
    final thresholdDuration = Duration(hours: threshold);
    final lastCheckin = DateTime.tryParse(checkin['checkin_time'].toString());
    final now = clock();
    if (lastCheckin == null) return;

    final elapsed = now.difference(lastCheckin);
    if (elapsed.isNegative || elapsed.compareTo(thresholdDuration) < 0) {
      await cache.remove(_warningCacheKey(user.id));
      return;
    }

    final missedCheckIns = calculateMissedCheckIns(
      lastCheckIn: lastCheckin,
      now: now,
      thresholdHours: threshold,
    );
    final lastAlert = alert == null
        ? null
        : DateTime.tryParse(alert['triggered_time'].toString());
    final alertAlreadyRecordedForThisCheckIn =
        lastAlert != null && !lastAlert.isBefore(lastCheckin);
    if (alertAlreadyRecordedForThisCheckIn) {
      return;
    }

    final warning = await cache.readMap(_warningCacheKey(user.id));
    final warningForCheckin =
        warning?['last_checkin_at'] == checkin['checkin_time'];
    final lastNotifiedMiss = warningForCheckin
        ? int.tryParse(warning?['last_notified_miss']?.toString() ?? '') ?? 0
        : 0;
    final escalated = warningForCheckin && warning?['escalated'] == true;

    if (missedCheckIns < missedCheckInsBeforeEscalation) {
      if (missedCheckIns <= lastNotifiedMiss) return;

      await notificationService.showMissedCheckInReminder(
        missedCheckIns: missedCheckIns,
        requiredMissedCheckIns: missedCheckInsBeforeEscalation,
      );
      await cache.writeMap(_warningCacheKey(user.id), {
        'last_checkin_at': checkin['checkin_time'],
        'last_notified_miss': missedCheckIns,
        'escalated': false,
      });
      return;
    }

    if (escalated) return;

    if (lastNotifiedMiss < missedCheckInsBeforeEscalation) {
      await notificationService.showMissedCheckInReminder(
        missedCheckIns: missedCheckInsBeforeEscalation,
        requiredMissedCheckIns: missedCheckInsBeforeEscalation,
      );
      await cache.writeMap(_warningCacheKey(user.id), {
        'last_checkin_at': checkin['checkin_time'],
        'last_notified_miss': missedCheckInsBeforeEscalation,
        'escalated': false,
      });
    }

    final result = await emergencyService.triggerEmergencyDetailed(
      allow999Dialer: false,
      sendAutomatedSms: true,
    );
    if (result.alertRecorded) {
      await cache.writeMap(_warningCacheKey(user.id), {
        'last_checkin_at': checkin['checkin_time'],
        'last_notified_miss': missedCheckIns,
        'escalated': true,
      });
    }
    if (result.official999Selected) {
      await notificationService.showOfficial999EscalationNotice();
    }
  }
}
