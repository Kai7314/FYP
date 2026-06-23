import '../dataAccessLayer/repositories/auth_repository.dart';
import '../dataAccessLayer/repositories/user_repository.dart';
import 'local_cache_service.dart';

class UserService {
  UserService({
    AuthRepository? authRepository,
    UserRepository? userRepository,
    LocalCacheService? cache,
  }) : authRepository = authRepository ?? AuthRepository(),
       userRepository = userRepository ?? UserRepository(),
       cache = cache ?? LocalCacheService();

  final AuthRepository authRepository;
  final UserRepository userRepository;
  final LocalCacheService cache;

  String _cacheKey(String userId) => 'profile_snapshot_v1_$userId';

  Future<Map<String, dynamic>> getCurrentProfile({
    bool forceRefresh = false,
  }) async {
    final user = authRepository.currentUser;
    if (user == null) return {};
    if (!forceRefresh) {
      final cached = await cache.readMap(_cacheKey(user.id));
      if (cached != null) return cached;
    }
    final profile =
        await userRepository.getProfile(user.id) ?? <String, dynamic>{};
    profile['email'] ??= user.email;
    await cache.writeMap(_cacheKey(user.id), profile);
    return profile;
  }

  Future<void> updateCurrentProfile(Map<String, dynamic> values) async {
    final user = authRepository.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    await userRepository.updateProfile(userId: user.id, values: values);
    await getCurrentProfile(forceRefresh: true);
  }

  Future<void> signOut() async {
    final userId = authRepository.currentUser?.id;
    await authRepository.signOut();
    if (userId != null) await cache.removeUserData(userId);
  }
}
