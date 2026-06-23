import '../dataAccessLayer/repositories/auth_repository.dart';
import '../dataAccessLayer/repositories/checkin_repository.dart';
import '../dataAccessLayer/repositories/emergency_repository.dart';
import '../dataAccessLayer/repositories/user_repository.dart';
import 'emergency_service.dart';

class InactivityService {
  InactivityService({
    AuthRepository? authRepository,
    CheckinRepository? checkinRepository,
    UserRepository? userRepository,
    EmergencyRepository? emergencyRepository,
    EmergencyService? emergencyService,
  }) : authRepository = authRepository ?? AuthRepository(),
       checkinRepository = checkinRepository ?? CheckinRepository(),
       userRepository = userRepository ?? UserRepository(),
       emergencyRepository = emergencyRepository ?? EmergencyRepository(),
       emergencyService = emergencyService ?? EmergencyService();

  final AuthRepository authRepository;
  final CheckinRepository checkinRepository;
  final UserRepository userRepository;
  final EmergencyRepository emergencyRepository;
  final EmergencyService emergencyService;

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
    if (lastCheckin == null ||
        DateTime.now().difference(lastCheckin).inHours <= threshold) {
      return;
    }

    final lastAlert = alert == null
        ? null
        : DateTime.tryParse(alert['triggered_time'].toString());
    if (lastAlert != null &&
        DateTime.now().difference(lastAlert).inHours < threshold) {
      return;
    }

    await emergencyService.triggerEmergency();
  }
}
