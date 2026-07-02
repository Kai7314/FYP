import '../dataAccessLayer/repositories/auth_repository.dart';
import '../dataAccessLayer/repositories/checkin_repository.dart';
import '../dataAccessLayer/repositories/emergency_repository.dart';
import '../dataAccessLayer/repositories/user_repository.dart';
import 'emergency_service.dart';
import 'local_cache_service.dart';
import 'notification_service.dart';

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

  static const emergencyGracePeriod = Duration(minutes: 30);

  final AuthRepository authRepository;
  final CheckinRepository checkinRepository;
  final UserRepository userRepository;
  final EmergencyRepository emergencyRepository;
  final EmergencyService emergencyService;
  final LocalCacheService cache;
  final NotificationService notificationService;
  final DateTime Function() clock;

  String _warningCacheKey(String userId) => 'missed_checkin_warning_v1_$userId';

  Future<void> checkInactivity() async {
    final user = authRepository.currentUser;
    if (user == null) return;

    final results = await Future.wait([
      checkinRepository.getLatestCheckin(user.id),
      userRepository.getProfile(user.id),
      emergencyRepository.getLatestAlert(user.id),
    ]);
    final checkin = results[0];
    if (checkin == null) return;
    final profile = results[1];
    final alert = results[2];
    final threshold =
        int.tryParse(profile?['inactivity_threshold']?.toString() ?? '') ?? 24;
    final lastCheckin = DateTime.tryParse(checkin['checkin_time'].toString());
    final now = clock();
    if (lastCheckin == null ||
        now.difference(lastCheckin).inHours <= threshold) {
      return;
    }

    final lastAlert = alert == null
        ? null
        : DateTime.tryParse(alert['triggered_time'].toString());
    if (lastAlert != null &&
        now.difference(lastAlert).inHours < threshold) {
      return;
    }

    final warning = await cache.readMap(_warningCacheKey(user.id));
    final warningForCheckin =
        warning?['last_checkin_at'] == checkin['checkin_time'];
    final warnedAt = DateTime.tryParse(warning?['warned_at']?.toString() ?? '');
    if (!warningForCheckin || warnedAt == null) {
      await notificationService.showMissedCheckInReminder(
        overdueHours: now.difference(lastCheckin).inHours,
        graceMinutes: emergencyGracePeriod.inMinutes,
      );
      await cache.writeMap(_warningCacheKey(user.id), {
        'last_checkin_at': checkin['checkin_time'],
        'warned_at': now.toUtc().toIso8601String(),
      });
      return;
    }

    if (now.difference(warnedAt).compareTo(emergencyGracePeriod) < 0) {
      return;
    }

    await emergencyService.triggerEmergency();
  }
}
