import '../core/constants/inactivity_rules.dart';
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
    this.userSmsResult,
    this.emergencyResult,
  });

  final int reminderCount;
  final InactivityUserSmsResult? userSmsResult;
  final EmergencyTriggerResult? emergencyResult;

  bool get userSmsTriggered => userSmsResult?.accepted == true;
  bool get smsTriggered => emergencyResult != null;
}

class InactivityMonitorStatus {
  const InactivityMonitorStatus({
    required this.notificationCount,
    required this.escalated,
    this.userSmsAccepted = false,
    this.userSmsError,
  });

  const InactivityMonitorStatus.clear()
    : notificationCount = 0,
      escalated = false,
      userSmsAccepted = false,
      userSmsError = null;

  final int notificationCount;
  final bool escalated;
  final bool userSmsAccepted;
  final String? userSmsError;
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
       notificationService =
           notificationService ?? NotificationService.instance,
       clock = clock ?? DateTime.now;

  static const missedCheckInsBeforeEscalation = 3;
  static const userSmsReminderMiss = 2;
  static const userSmsRetryDelay = Duration(minutes: 30);
  static const malaysiaUtcOffset = Duration(hours: 8);

  static DateTime _malaysiaCalendarDate(DateTime value) {
    final malaysiaTime = value.toUtc().add(malaysiaUtcOffset);
    return DateTime.utc(
      malaysiaTime.year,
      malaysiaTime.month,
      malaysiaTime.day,
    );
  }

  static int calculateMissedCheckIns({
    required DateTime lastCheckIn,
    required DateTime now,
    required int thresholdHours,
  }) {
    if (now.isBefore(lastCheckIn)) return 0;
    final thresholdDays = InactivityRules.thresholdDaysFromHours(
      thresholdHours,
    );
    final lastDate = _malaysiaCalendarDate(lastCheckIn);
    final currentDate = _malaysiaCalendarDate(now);
    final elapsedCalendarDays = currentDate.difference(lastDate).inDays;
    return elapsedCalendarDays ~/ thresholdDays;
  }

  static bool isCheckInCurrent({
    required DateTime? lastCheckIn,
    required DateTime now,
    required int thresholdHours,
  }) {
    if (lastCheckIn == null) return false;
    return calculateMissedCheckIns(
          lastCheckIn: lastCheckIn,
          now: now,
          thresholdHours: thresholdHours,
        ) ==
        0;
  }

  static DateTime? nextCheckInDueAt({
    required DateTime? lastCheckIn,
    required int thresholdHours,
  }) {
    if (lastCheckIn == null) return null;
    final thresholdDays = InactivityRules.thresholdDaysFromHours(
      thresholdHours,
    );
    final dueMalaysiaDate = _malaysiaCalendarDate(
      lastCheckIn,
    ).add(Duration(days: thresholdDays));
    return dueMalaysiaDate.subtract(malaysiaUtcOffset);
  }

  static bool shouldAttemptUserSms({
    required int missedCheckIns,
    required bool userSmsAccepted,
    required DateTime now,
    DateTime? lastAttemptAt,
  }) {
    if (missedCheckIns < userSmsReminderMiss || userSmsAccepted) return false;
    return lastAttemptAt == null ||
        now.difference(lastAttemptAt) >= userSmsRetryDelay;
  }

  static bool shouldEscalateToTrustedContact({
    required int missedCheckIns,
    required bool alreadyEscalated,
    required bool alertAlreadyRecordedForCheckIn,
  }) {
    return missedCheckIns >= missedCheckInsBeforeEscalation &&
        !alreadyEscalated &&
        !alertAlreadyRecordedForCheckIn;
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

    try {
      final serverStatus = await emergencyRepository
          .getInactivityMonitorStatus(user.id);
      if (serverStatus != null) {
        final trackedCheckIn = DateTime.tryParse(
          serverStatus['last_checkin_at']?.toString() ?? '',
        );
        if (latestCheckIn == null ||
            (trackedCheckIn != null &&
                !trackedCheckIn.isBefore(latestCheckIn))) {
          final smsStatus =
              serverStatus['user_sms_status']?.toString() ?? 'not_due';
          return InactivityMonitorStatus(
            notificationCount:
                (int.tryParse(
                          serverStatus['missed_windows']?.toString() ?? '',
                        ) ??
                        0)
                    .clamp(0, missedCheckInsBeforeEscalation)
                    .toInt(),
            escalated: DateTime.tryParse(
                  serverStatus['escalated_at']?.toString() ?? '',
                ) !=
                null,
            userSmsAccepted: smsStatus == 'queued' || smsStatus == 'sent',
            userSmsError: serverStatus['user_sms_error']?.toString(),
          );
        }
      }
    } catch (_) {
      // Local state remains available while the server or network is offline.
    }

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
      userSmsAccepted: warning['user_sms_accepted'] == true,
      userSmsError: warning['user_sms_error']?.toString(),
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

    if (reminderCount == userSmsReminderMiss) {
      final thresholdHours = await getCurrentThresholdHours();
      final userSmsResult = await emergencyService.sendUserInactivityReminder(
        lastCheckIn: clock(),
        thresholdHours: thresholdHours,
        testMode: true,
        allowDirectSms: false,
      );
      return InactivityReminderTestResult(
        reminderCount: reminderCount,
        userSmsResult: userSmsResult,
      );
    }

    if (reminderCount < missedCheckInsBeforeEscalation) {
      return InactivityReminderTestResult(reminderCount: reminderCount);
    }

    final emergencyResult = await emergencyService.triggerEmergencyDetailed(
      allow999Dialer: false,
      sendAutomatedSms: true,
      allowDirectSms: false,
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
    ]);
    final checkin = results[0];
    if (checkin == null) return;
    final profile = results[1];
    final threshold = InactivityRules.normalizeThresholdHours(
      profile?['inactivity_threshold'],
    );
    final lastCheckin = DateTime.tryParse(checkin['checkin_time'].toString());
    final now = clock();
    if (lastCheckin == null) return;

    final missedCheckIns = calculateMissedCheckIns(
      lastCheckIn: lastCheckin,
      now: now,
      thresholdHours: threshold,
    );
    if (missedCheckIns == 0) {
      await cache.remove(_warningCacheKey(user.id));
      return;
    }
    final warning = await cache.readMap(_warningCacheKey(user.id));
    final warningForCheckin =
        warning?['last_checkin_at'] == checkin['checkin_time'];
    final lastNotifiedMiss = warningForCheckin
        ? int.tryParse(warning?['last_notified_miss']?.toString() ?? '') ?? 0
        : 0;
    var currentNotifiedMiss = lastNotifiedMiss;
    final reminderMiss = missedCheckIns
        .clamp(1, missedCheckInsBeforeEscalation)
        .toInt();

    if (reminderMiss > currentNotifiedMiss) {
      await notificationService.showMissedCheckInReminder(
        missedCheckIns: reminderMiss,
        requiredMissedCheckIns: missedCheckInsBeforeEscalation,
      );
      currentNotifiedMiss = reminderMiss;
    }

    // The scheduled Supabase worker owns all automatic SMS and trusted-contact
    // escalation. The phone only displays the local reminder when it is awake.
    await _saveWarning(
      userId: user.id,
      checkInValue: checkin['checkin_time'],
      lastNotifiedMiss: currentNotifiedMiss,
      escalated: false,
      userSmsAccepted: false,
    );
  }

  Future<int> getCurrentThresholdHours() async {
    final user = authRepository.currentUser;
    if (user == null) return InactivityRules.defaultThresholdHours;
    final profile = await userRepository.getProfile(user.id);
    return InactivityRules.normalizeThresholdHours(
      profile?['inactivity_threshold'],
    );
  }

  Future<void> _saveWarning({
    required String userId,
    required Object? checkInValue,
    required int lastNotifiedMiss,
    required bool escalated,
    required bool userSmsAccepted,
    String? userSmsError,
    DateTime? userSmsLastAttemptAt,
  }) {
    return cache.writeMap(_warningCacheKey(userId), {
      'last_checkin_at': checkInValue,
      'last_notified_miss': lastNotifiedMiss,
      'escalated': escalated,
      'user_sms_accepted': userSmsAccepted,
      'user_sms_error': userSmsError,
      'user_sms_last_attempt_at': userSmsLastAttemptAt?.toIso8601String(),
    });
  }
}
