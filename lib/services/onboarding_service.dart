import '../dataAccessLayer/repositories/auth_repository.dart';
import 'local_cache_service.dart';

class OnboardingService {
  OnboardingService({AuthRepository? authRepository, LocalCacheService? cache})
    : authRepository = authRepository ?? AuthRepository(),
      cache = cache ?? LocalCacheService();

  static const tutorialVersion = 2;
  static const accountCompletionKey = 'ethernacare_feature_guide_completed_at';

  final AuthRepository authRepository;
  final LocalCacheService cache;

  static String cacheKeyForUser(String userId) => 'tutorial_completed_$userId';

  static String _versionedCacheKeyForUser(String userId) =>
      'tutorial_completed_v${tutorialVersion}_$userId';

  static Set<String> preservedCacheKeysForUser(String userId) => {
    cacheKeyForUser(userId),
    _versionedCacheKeyForUser(userId),
  };

  Future<bool> hasCompletedTutorial() async {
    final user = authRepository.currentUser;
    if (user == null) return true;

    final accountCompletedAt = user.userMetadata?[accountCompletionKey]
        ?.toString()
        .trim();
    if (accountCompletedAt != null && accountCompletedAt.isNotEmpty) {
      await _writeLocalCompletion(user.id, accountCompletedAt);
      return true;
    }

    final cached = await cache.readMap(cacheKeyForUser(user.id));
    if (cached?['completed'] == true) {
      await _syncAccountCompletion(cached?['completed_at']?.toString());
      return true;
    }

    final versioned = await cache.readMap(_versionedCacheKeyForUser(user.id));
    if (versioned?['completed'] != true) return false;

    await _writeLocalCompletion(
      user.id,
      versioned?['completed_at']?.toString(),
    );
    await _syncAccountCompletion(versioned?['completed_at']?.toString());
    return true;
  }

  Future<void> markTutorialComplete() async {
    final user = authRepository.currentUser;
    if (user == null) return;
    final completedAt = DateTime.now().toUtc().toIso8601String();
    await _writeLocalCompletion(user.id, completedAt);
    await _syncAccountCompletion(completedAt);
  }

  Future<void> _writeLocalCompletion(String userId, String? completedAt) {
    return cache.writeMap(cacheKeyForUser(userId), {
      'completed': true,
      'completed_at': completedAt?.trim().isNotEmpty == true
          ? completedAt!.trim()
          : DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _syncAccountCompletion(String? completedAt) async {
    try {
      await authRepository.updateUserMetadata({
        accountCompletionKey: completedAt?.trim().isNotEmpty == true
            ? completedAt!.trim()
            : DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // The local marker still prevents repeat guides and is retried at login.
    }
  }
}
