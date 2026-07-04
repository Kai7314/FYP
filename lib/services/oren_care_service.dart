import '../dataAccessLayer/repositories/auth_repository.dart';
import '../models/oren_care_model.dart';
import 'local_cache_service.dart';

class OrenCareService {
  OrenCareService({
    AuthRepository? authRepository,
    LocalCacheService? cache,
  }) : authRepository = authRepository ?? AuthRepository(),
       cache = cache ?? LocalCacheService();

  final AuthRepository authRepository;
  final LocalCacheService cache;

  static const dailyLoginTokenReward = 5;
  static const dailyCheckInTokenReward = 3;

  static const toyCatalog = <OrenToy>[
    OrenToy(
      id: 'yarn_ball',
      name: 'Yarn Ball',
      description: 'A soft rolling toy for gentle play.',
      price: 8,
      iconCodePoint: 0xe3e6,
      imageAsset: 'lib/assets/images/oren_toy_yarn_ball.png',
    ),
    OrenToy(
      id: 'fish_plush',
      name: 'Fish Plush',
      description: 'Oren can nap beside this tiny fish.',
      price: 12,
      iconCodePoint: 0xe545,
      imageAsset: 'lib/assets/images/oren_toy_fish_plush.png',
    ),
    OrenToy(
      id: 'feather_wand',
      name: 'Feather Wand',
      description: 'A playful wand for quick energy boosts.',
      price: 16,
      iconCodePoint: 0xe3b7,
      imageAsset: 'lib/assets/images/oren_toy_feather_wand.png',
    ),
  ];

  String _cacheKey(String userId) => 'oren_care_v1_$userId';

  Future<OrenCareState> load() async {
    final user = authRepository.currentUser;
    if (user == null) return OrenCareState.initial();
    final cached = await cache.readMap(_cacheKey(user.id));
    return cached == null
        ? OrenCareState.initial()
        : OrenCareState.fromJson(cached);
  }

  Future<OrenCareState> claimDailyLoginToken() async {
    final state = await load();
    final today = _todayKey();
    if (state.lastDailyTokenDate == today) return state;
    return _save(
      state.copyWith(
        tokens: state.tokens + dailyLoginTokenReward,
        lastDailyTokenDate: today,
        mood: 'Happy',
        energy: (state.energy + 5).clamp(0, 100),
        lastAction:
            'Daily login bonus earned: $dailyLoginTokenReward Oren tokens.',
      ),
    );
  }

  Future<OrenCareState> awardDailyCheckInTokens() async {
    final state = await load();
    final today = _todayKey();
    if (state.lastCheckInTokenDate == today) {
      return state.copyWith(
        lastAction: 'Daily check-in bonus already claimed today.',
      );
    }
    return _save(
      state.copyWith(
        tokens: state.tokens + dailyCheckInTokenReward,
        lastCheckInTokenDate: today,
        mood: 'Happy',
        energy: (state.energy + 8).clamp(0, 100),
        lastAction:
            'Daily check-in bonus earned: $dailyCheckInTokenReward Oren tokens.',
      ),
    );
  }

  Future<OrenCareState> feedFish() async {
    final state = await load();
    return _save(
      state.copyWith(
        mood: 'Eating',
        energy: (state.energy + 12).clamp(0, 100),
        lastAction: 'Oren enjoyed a fish snack.',
      ),
    );
  }

  Future<OrenCareState> pet() async {
    final state = await load();
    return _save(
      state.copyWith(
        mood: 'Loved',
        energy: (state.energy + 6).clamp(0, 100),
        lastAction: 'Oren liked the gentle pet.',
      ),
    );
  }

  Future<OrenCareState> buyToy(OrenToy toy) async {
    final state = await load();
    if (state.ownedToyIds.contains(toy.id)) {
      return state.copyWith(lastAction: '${toy.name} is already owned.');
    }
    if (state.tokens < toy.price) {
      return state.copyWith(
        lastAction: 'Not enough Oren tokens for ${toy.name}.',
      );
    }
    return _save(
      state.copyWith(
        tokens: state.tokens - toy.price,
        ownedToyIds: {...state.ownedToyIds, toy.id},
        mood: 'Curious',
        lastAction: '${toy.name} added to Oren inventory.',
      ),
    );
  }

  Future<OrenCareState> playWithToy(OrenToy toy) async {
    final state = await load();
    if (!state.ownedToyIds.contains(toy.id)) {
      return state.copyWith(lastAction: 'Buy ${toy.name} before using it.');
    }
    return _save(
      state.copyWith(
        mood: 'Playful',
        energy: (state.energy + 10).clamp(0, 100),
        lastAction: 'Oren played with ${toy.name}.',
      ),
    );
  }

  Future<OrenCareState> resetMood() async {
    final state = await load();
    return _save(
      state.copyWith(
        mood: 'Calm',
        lastAction: 'Oren is ready for today.',
      ),
    );
  }

  Future<OrenCareState> _save(OrenCareState state) async {
    final user = authRepository.currentUser;
    if (user == null) return state;
    final next = state.copyWith(updatedAt: DateTime.now());
    await cache.writeMap(_cacheKey(user.id), next.toJson());
    return next;
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
