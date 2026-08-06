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

  String _cacheKey(String userId) =>
      'tutorial_completed_v${tutorialVersion}_$userId';

  Future<bool> hasCompletedTutorial() async {
    final user = authRepository.currentUser;
    if (user == null) return true;
    final cached = await cache.readMap(_cacheKey(user.id));
    return cached?['completed'] == true;
  }

  Future<void> markTutorialComplete() async {
    final user = authRepository.currentUser;
    if (user == null) return;
    await cache.writeMap(_cacheKey(user.id), {
      'completed': true,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
