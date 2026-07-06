import '../dataAccessLayer/repositories/auth_repository.dart';
import '../dataAccessLayer/repositories/checkin_repository.dart';
import 'local_cache_service.dart';

class CheckinService {
  CheckinService({
    AuthRepository? authRepository,
    CheckinRepository? checkinRepository,
    LocalCacheService? cache,
  }) : authRepository = authRepository ?? AuthRepository(),
       checkinRepository = checkinRepository ?? CheckinRepository(),
       cache = cache ?? LocalCacheService();

  final AuthRepository authRepository;
  final CheckinRepository checkinRepository;
  final LocalCacheService cache;

  String _cacheKey(String userId) => 'checkins_snapshot_v1_$userId';

  Future<List<Map<String, dynamic>>> getCheckins({
    bool forceRefresh = false,
  }) async {
    final user = authRepository.currentUser;
    if (user == null) return [];
    if (!forceRefresh) {
      final cached = await cache.readMap(_cacheKey(user.id));
      final rows = cached?['rows'] as List?;
      if (rows != null) {
        return rows
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      }
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

    final created = await checkinRepository.addDailyCheckin(
      user.id,
      DateTime.now(),
    );
    await getCheckins(forceRefresh: true);
    return created;
  }
}
