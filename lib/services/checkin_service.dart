import 'dart:async';

import '../core/constants/inactivity_rules.dart';
import '../dataAccessLayer/repositories/auth_repository.dart';
import '../dataAccessLayer/repositories/checkin_repository.dart';
import '../dataAccessLayer/repositories/user_repository.dart';
import 'local_cache_service.dart';

class CheckinService {
  CheckinService({
    AuthRepository? authRepository,
    CheckinRepository? checkinRepository,
    UserRepository? userRepository,
    LocalCacheService? cache,
  }) : authRepository = authRepository ?? AuthRepository(),
       checkinRepository = checkinRepository ?? CheckinRepository(),
       userRepository = userRepository ?? UserRepository(),
       cache = cache ?? LocalCacheService();

  final AuthRepository authRepository;
  final CheckinRepository checkinRepository;
  final UserRepository userRepository;
  final LocalCacheService cache;

  static final StreamController<void> _updates =
      StreamController<void>.broadcast();

  static Stream<void> get updates => _updates.stream;

  static String cacheKeyForUser(String userId) =>
      'checkins_snapshot_v1_$userId';

  String _cacheKey(String userId) => cacheKeyForUser(userId);

  Future<List<Map<String, dynamic>>> getCachedCheckins() async {
    final user = authRepository.currentUser;
    if (user == null) return [];
    final cached = await cache.readMap(_cacheKey(user.id));
    final rows = cached?['rows'] as List?;
    if (rows == null) return [];
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<DateTime?> getLatestCachedCheckinTime() async {
    final rows = await getCachedCheckins();
    DateTime? latest;
    for (final row in rows) {
      final parsed = DateTime.tryParse(row['checkin_time']?.toString() ?? '');
      if (parsed != null && (latest == null || parsed.isAfter(latest))) {
        latest = parsed;
      }
    }
    return latest;
  }

  Future<List<Map<String, dynamic>>> getCheckins({
    bool forceRefresh = false,
  }) async {
    final user = authRepository.currentUser;
    if (user == null) return [];
    if (!forceRefresh) {
      final rows = await getCachedCheckins();
      if (rows.isNotEmpty) return rows;
    }
    final rows = await checkinRepository.getCheckins(user.id);
    await cache.writeMap(_cacheKey(user.id), {'rows': rows});
    return rows;
  }

  Future<bool> addCheckin() async {
    final user = authRepository.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to check in.');
    }

    final checkedAt = DateTime.now();
    final profile = await userRepository.getProfile(user.id);
    final configuredThreshold = InactivityRules.normalizeThresholdHours(
      profile?['inactivity_threshold'],
    );
    final created = await checkinRepository.addThresholdCheckin(
      userId: user.id,
      now: checkedAt,
      thresholdHours: configuredThreshold,
    );
    if (created) {
      await _cacheCreatedCheckin(user.id, checkedAt);
      _updates.add(null);
    }

    try {
      await getCheckins(forceRefresh: true);
    } catch (_) {
      // The insert already succeeded. Keep the optimistic cache until the
      // next server refresh instead of reporting the check-in as failed.
    }
    _updates.add(null);
    return created;
  }

  Future<void> _cacheCreatedCheckin(String userId, DateTime checkedAt) async {
    final rows = await getCachedCheckins();
    final alreadyCached = rows.any((row) {
      final parsed = DateTime.tryParse(row['checkin_time'].toString());
      if (parsed == null) return false;
      return parsed.difference(checkedAt).abs() < const Duration(seconds: 1);
    });
    if (alreadyCached) return;

    rows.insert(0, {
      'id': 'local-${checkedAt.microsecondsSinceEpoch}',
      'user_id': userId,
      'checkin_time': checkedAt.toIso8601String(),
      'status': 'active',
    });
    await cache.writeMap(_cacheKey(userId), {'rows': rows});
  }
}
