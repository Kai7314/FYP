import '../dataAccessLayer/repositories/auth_repository.dart';
import '../dataAccessLayer/repositories/checkin_repository.dart';
import '../dataAccessLayer/repositories/emergency_repository.dart';
import '../dataAccessLayer/repositories/user_repository.dart';
import 'local_cache_service.dart';
import 'reward_service.dart';

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.userName,
    required this.checkinTimes,
    required this.emergencyStatus,
    required this.latestEmergencyAlertTime,
    required this.syncedAt,
  });

  final String userName;
  final List<DateTime> checkinTimes;
  final String emergencyStatus;
  final DateTime? latestEmergencyAlertTime;
  final DateTime syncedAt;

  int get totalCheckins => checkinTimes.length;
  int get streak => RewardService.calculateStreak(checkinTimes);
  DateTime? get lastCheckin => checkinTimes.isEmpty ? null : checkinTimes.first;

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    return DashboardSnapshot(
      userName: json['user_name']?.toString() ?? 'EthernaCare User',
      checkinTimes: (json['checkin_times'] as List? ?? const [])
          .map((value) => DateTime.tryParse(value.toString()))
          .whereType<DateTime>()
          .toList(),
      emergencyStatus: json['emergency_status']?.toString() ?? 'safe',
      latestEmergencyAlertTime: DateTime.tryParse(
        json['latest_emergency_alert_time']?.toString() ?? '',
      ),
      syncedAt:
          DateTime.tryParse(json['synced_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_name': userName,
    'checkin_times': checkinTimes
        .map((value) => value.toIso8601String())
        .toList(),
    'emergency_status': emergencyStatus,
    'latest_emergency_alert_time': latestEmergencyAlertTime?.toIso8601String(),
    'synced_at': syncedAt.toIso8601String(),
  };
}

class DashboardService {
  DashboardService({
    LocalCacheService? cache,
    AuthRepository? authRepository,
    CheckinRepository? checkinRepository,
    UserRepository? userRepository,
    EmergencyRepository? emergencyRepository,
  }) : cache = cache ?? LocalCacheService(),
       authRepository = authRepository ?? AuthRepository(),
       checkinRepository = checkinRepository ?? CheckinRepository(),
       userRepository = userRepository ?? UserRepository(),
       emergencyRepository = emergencyRepository ?? EmergencyRepository();

  final LocalCacheService cache;
  final AuthRepository authRepository;
  final CheckinRepository checkinRepository;
  final UserRepository userRepository;
  final EmergencyRepository emergencyRepository;

  String _cacheKey(String userId) => 'dashboard_snapshot_v1_$userId';

  Future<DashboardSnapshot?> loadCached() async {
    final user = authRepository.currentUser;
    if (user == null) return null;
    final value = await cache.readMap(_cacheKey(user.id));
    return value == null ? null : DashboardSnapshot.fromJson(value);
  }

  Future<DashboardSnapshot> refresh() async {
    final user = authRepository.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to load the dashboard.');
    }

    final results = await Future.wait([
      checkinRepository.getCheckinTimes(user.id),
      userRepository.getProfile(user.id),
      emergencyRepository.getLatestAlert(user.id),
    ]);
    final checkinTimes = results[0] as List<DateTime>;
    final profile = results[1] as Map<String, dynamic>?;
    final alert = results[2] as Map<String, dynamic>?;
    final profileName = profile?['name']?.toString();
    final alertStatus = alert?['status']?.toString().trim();
    final latestAlertTime = DateTime.tryParse(
      alert?['triggered_time']?.toString() ?? '',
    );
    final snapshot = DashboardSnapshot(
      userName: profileName == null || profileName.trim().isEmpty
          ? (user.email?.split('@').first ?? 'EthernaCare User')
          : profileName,
      checkinTimes: checkinTimes,
      emergencyStatus: alertStatus == null || alertStatus.isEmpty
          ? 'safe'
          : alertStatus,
      latestEmergencyAlertTime: latestAlertTime,
      syncedAt: DateTime.now(),
    );
    await cache.writeMap(_cacheKey(user.id), snapshot.toJson());
    return snapshot;
  }
}
