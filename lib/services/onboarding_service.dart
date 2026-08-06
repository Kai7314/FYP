import '../dataAccessLayer/repositories/auth_repository.dart';
import 'local_cache_service.dart';

class OnboardingService {
  OnboardingService({
    AuthRepository? authRepository,
    LocalCacheService? cache,
  }) : authRepository = authRepository ?? AuthRepository(),
       cache = cache ?? LocalCacheService();

  static const tutorialVersion = 2;

  final AuthRepository authRepository;
  final LocalCacheService cache;

  static String cacheKeyForUser(String userId) =>
      'tutorial_completed_$userId';

  static String _versionedCacheKeyForUser(String userId) =>
      'tutorial_completed_v${tutorialVersion}_$userId';

  static Set<String> preservedCacheKeysForUser(String userId) => {
    cacheKeyForUser(userId),
    _versionedCacheKeyForUser(userId),
  };

  Future<bool> hasCompletedTutorial() async {
    final user = authRepository.currentUser;
    if (user == null) return true;
    final cached = await cache.readMap(cacheKeyForUser(user.id));
    if (cached?['completed'] == true) return true;

    final versioned = await cache.readMap(_versionedCacheKeyForUser(user.id));
    if (versioned?['completed'] != true) return false;

    await cache.writeMap(cacheKeyForUser(user.id), versioned!);
    return true;
  }

  Future<void> markTutorialComplete() async {
    final user = authRepository.currentUser;
    if (user == null) return;
    await cache.writeMap(cacheKeyForUser(user.id), {
      'completed': true,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
