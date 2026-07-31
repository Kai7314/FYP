import '../dataAccessLayer/repositories/auth_repository.dart';
import '../models/oren_care_model.dart';
import 'local_cache_service.dart';

class OrenCareService {
  OrenCareService({AuthRepository? authRepository, LocalCacheService? cache})
    : authRepository = authRepository ?? AuthRepository(),
      cache = cache ?? LocalCacheService();

  final AuthRepository authRepository;
  final LocalCacheService cache;

  static const dailyLoginTokenReward = 5;
  static const dailyCheckInTokenReward = 3;
  static const energyDecayInterval = Duration(hours: 1);
  static const energyDecayPerInterval = 1;

  static const toyCatalog = <OrenToy>[
    OrenToy(
      id: 'yarn_ball',
      name: 'Yarn Ball',
      description: 'A soft rolling toy for gentle play.',
      price: 8,
      iconCodePoint: 0xe3e6,
      imageAsset:
          'lib/assets/images/pixel/oren_pixel_yarn_ball_transparent.png',
    ),
    OrenToy(
      id: 'fish_plush',
      name: 'Fish Plush',
      description: 'Oren can nap beside this tiny fish.',
      price: 12,
      iconCodePoint: 0xe545,
      imageAsset:
          'lib/assets/images/pixel/oren_pixel_fish_plush_transparent.png',
    ),
    OrenToy(
      id: 'feather_wand',
      name: 'Feather Wand',
      description: 'A playful wand for quick energy boosts.',
      price: 16,
      iconCodePoint: 0xe3b7,
      imageAsset:
          'lib/assets/images/pixel/oren_pixel_feather_wand_transparent.png',
    ),
  ];

  static String cacheKeyForUser(String userId) => 'oren_care_v1_$userId';

  Future<OrenCareState> load() async {
    final user = authRepository.currentUser;
    if (user == null) return OrenCareState.initial();
    final cached = await cache.readMap(cacheKeyForUser(user.id));
    final restored = cached == null
        ? OrenCareState.initial()
        : OrenCareState.fromJson(cached);
    final decayed = applyEnergyDecay(restored, DateTime.now());
    if (decayed.updatedAt != restored.updatedAt) {
      await cache.writeMap(cacheKeyForUser(user.id), decayed.toJson());
    }
    return decayed;
  }

  static OrenCareState applyEnergyDecay(OrenCareState state, DateTime now) {
    final elapsed = now.difference(state.updatedAt);
    if (elapsed.isNegative) return state;

    final elapsedIntervals = elapsed.inSeconds ~/ energyDecayInterval.inSeconds;
    if (elapsedIntervals <= 0) return state;

    final nextEnergy =
        (state.energy - elapsedIntervals * energyDecayPerInterval)
            .clamp(0, 100)
            .toInt();
    final decayedThrough = state.updatedAt.add(
      Duration(seconds: elapsedIntervals * energyDecayInterval.inSeconds),
    );
    return state.copyWith(
      energy: nextEnergy,
      mood: _moodForEnergy(nextEnergy),
      lastAction: _actionForEnergy(nextEnergy),
      updatedAt: decayedThrough,
    );
  }

  Future<OrenCareState> claimDailyLoginToken() async {
    final state = await load();
    final today = _todayKey();
    if (state.lastDailyTokenDate == today) return state;
    final nextEnergy = (state.energy + 5).clamp(0, 100);
    return _save(
      state.copyWith(
        tokens: state.tokens + dailyLoginTokenReward,
        lastDailyTokenDate: today,
        mood: nextEnergy >= 90 ? 'Energetic' : 'Happy',
        energy: nextEnergy,
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
    final nextEnergy = (state.energy + 8).clamp(0, 100);
    return _save(
      state.copyWith(
        tokens: state.tokens + dailyCheckInTokenReward,
        lastCheckInTokenDate: today,
        mood: nextEnergy >= 90 ? 'Energetic' : 'Happy',
        energy: nextEnergy,
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
        selectedToyId: state.selectedToyId.isEmpty
            ? toy.id
            : state.selectedToyId,
        mood: 'Curious',
        lastAction: '${toy.name} added to Oren inventory.',
      ),
    );
  }

  Future<OrenCareState> selectToy(OrenToy toy) async {
    final state = await load();
    if (!state.ownedToyIds.contains(toy.id)) {
      return state.copyWith(lastAction: 'Buy ${toy.name} before selecting it.');
    }
    return _save(
      state.copyWith(
        selectedToyId: toy.id,
        mood: 'Curious',
        lastAction: '${toy.name} is ready for playtime.',
      ),
    );
  }

  Future<OrenCareState> playWithToy(OrenToy toy) async {
    final state = await load();
    if (!state.ownedToyIds.contains(toy.id)) {
      return state.copyWith(lastAction: 'Buy ${toy.name} before using it.');
    }
    if (state.energy <= 15) {
      return _save(
        state.copyWith(
          mood: 'Tired',
          lastAction: 'Oren is too tired to play. Feed Oren first.',
        ),
      );
    }

    final fullEnergy = state.energy >= 90;
    final nextEnergy = (state.energy - (fullEnergy ? 16 : 10)).clamp(0, 100);
    final nextMood = fullEnergy
        ? 'Energetic'
        : nextEnergy <= 25
        ? 'Tired'
        : 'Playful';
    final action = fullEnergy
        ? 'Oren zoomed around with ${toy.name}.'
        : nextEnergy <= 25
        ? 'Oren played with ${toy.name} and got sleepy.'
        : 'Oren played with ${toy.name}.';

    return _save(
      state.copyWith(mood: nextMood, energy: nextEnergy, lastAction: action),
    );
  }

  Future<OrenCareState> resetMood() async {
    final state = await load();
    return _save(
      state.copyWith(
        mood: _restingMoodForEnergy(state.energy),
        lastAction: _restingActionForEnergy(state.energy),
      ),
    );
  }

  Future<OrenCareState> _save(OrenCareState state) async {
    final user = authRepository.currentUser;
    if (user == null) return state;
    final next = state.copyWith(updatedAt: DateTime.now());
    await cache.writeMap(cacheKeyForUser(user.id), next.toJson());
    return next;
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _restingMoodForEnergy(int energy) {
    return _moodForEnergy(energy);
  }

  String _restingActionForEnergy(int energy) {
    return _actionForEnergy(energy);
  }

  static String _moodForEnergy(int energy) {
    if (energy >= 90) return 'Energetic';
    if (energy <= 25) return 'Tired';
    return 'Calm';
  }

  static String _actionForEnergy(int energy) {
    if (energy >= 90) return 'Oren is full of energy.';
    if (energy <= 25) return 'Oren is sleepy. A snack would help.';
    return 'Oren is ready for today.';
  }
}
