import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../dataAccessLayer/repositories/auth_repository.dart';
import '../dataAccessLayer/repositories/reward_repository.dart';
import '../models/reward_model.dart';
import 'local_cache_service.dart';

class RewardService {
  RewardService({
    LocalCacheService? cache,
    AuthRepository? authRepository,
    RewardRepository? rewardRepository,
  }) : cache = cache ?? LocalCacheService(),
       authRepository = authRepository ?? AuthRepository(),
       rewardRepository = rewardRepository ?? RewardRepository();

  final LocalCacheService cache;
  final AuthRepository authRepository;
  final RewardRepository rewardRepository;
  RealtimeChannel? _catalogChannel;

  static const fallbackCatalogVersion = 2;

  static const fallbackCatalog = <RewardCatalogItem>[
    RewardCatalogItem(
      code: 'oren_sprout_badge',
      title: 'Oren Sprout Badge',
      sponsor: 'EthernaCare',
      description: 'A fresh start badge for building your check-in habit.',
      milestoneDays: 3,
      rewardKind: 'virtual',
      catalogVersion: fallbackCatalogVersion,
    ),
    RewardCatalogItem(
      code: 'oren_companion_badge',
      title: 'Caring Companion Badge',
      sponsor: 'EthernaCare',
      description: 'A virtual badge celebrating one week with Oren.',
      milestoneDays: 7,
      rewardKind: 'virtual',
      catalogVersion: fallbackCatalogVersion,
    ),
    RewardCatalogItem(
      code: 'oren_safety_star_badge',
      title: 'Safety Star Badge',
      sponsor: 'EthernaCare',
      description: 'A virtual star for ten consistent safety check-ins.',
      milestoneDays: 10,
      rewardKind: 'virtual',
      catalogVersion: fallbackCatalogVersion,
    ),
    RewardCatalogItem(
      code: 'oren_guardian_badge',
      title: 'Trusted Guardian Badge',
      sponsor: 'EthernaCare',
      description: 'A virtual badge for two dependable check-in weeks.',
      milestoneDays: 14,
      rewardKind: 'virtual',
      catalogVersion: fallbackCatalogVersion,
    ),
    RewardCatalogItem(
      code: 'oren_golden_badge',
      title: 'Golden Oren Badge',
      sponsor: 'EthernaCare',
      description: 'The highest virtual badge for a 30-day check-in streak.',
      milestoneDays: 30,
      rewardKind: 'virtual',
      catalogVersion: fallbackCatalogVersion,
    ),
  ];

  String _cacheKey(String userId) => 'rewards_snapshot_v3_$userId';

  Future<RewardSnapshot?> loadCached() async {
    final user = authRepository.currentUser;
    if (user == null) return null;
    final value = await cache.readMap(_cacheKey(user.id));
    return value == null ? null : RewardSnapshot.fromJson(value);
  }

  void startCatalogRealtime(void Function() onChange) {
    final previous = _catalogChannel;
    if (previous != null) {
      unawaited(rewardRepository.unsubscribeFromCatalogChanges(previous));
    }
    _catalogChannel = rewardRepository.subscribeToCatalogChanges(onChange);
  }

  Future<void> stopCatalogRealtime() async {
    final channel = _catalogChannel;
    _catalogChannel = null;
    if (channel != null) {
      await rewardRepository.unsubscribeFromCatalogChanges(channel);
    }
  }

  Future<RewardSnapshot> synchronize({bool forceCatalogRefresh = false}) async {
    final user = authRepository.currentUser;
    if (user == null) {
      return RewardSnapshot(
        catalog: fallbackCatalog,
        earnedCodes: const {},
        catalogVersion: fallbackCatalogVersion,
        syncedAt: DateTime.now(),
      );
    }

    final cached = await loadCached();
    try {
      var catalog = cached?.catalog ?? fallbackCatalog;
      var catalogVersion = cached?.catalogVersion ?? 0;

      try {
        final remoteVersion = await rewardRepository.getLatestCatalogVersion();

        if (forceCatalogRefresh ||
            cached == null ||
            remoteVersion != catalogVersion) {
          final catalogRows = await rewardRepository.getActiveCatalog();
          final remoteCatalog = catalogRows
              .map(
                (row) =>
                    RewardCatalogItem.fromJson(Map<String, dynamic>.from(row)),
              )
              .where((item) => item.code.isNotEmpty)
              .toList();
          catalog = remoteCatalog;
          catalogVersion = remoteVersion;
        }
      } catch (_) {
        if (catalog.isEmpty) catalog = fallbackCatalog;
        if (catalogVersion == 0) {
          catalogVersion = fallbackCatalogVersion;
        }
      }

      await rewardRepository.synchronizeEarnedRewards();
      final earnedRows = await rewardRepository.getEarnedRewards(user.id);
      final earnedCodes = earnedRows
          .map((row) => _resolveEarnedCode(row, catalog))
          .whereType<String>()
          .toSet();
      final catalogByCode = {for (final item in catalog) item.code: item};
      final claimedBadgeCodes = earnedRows
          .where((row) => row['status']?.toString() == 'claimed')
          .map((row) => _resolveEarnedCode(row, catalog))
          .whereType<String>()
          .where((code) => catalogByCode[code]?.isVoucher == false)
          .toSet();
      final redemptionCodes = <String, String>{};
      for (final row in earnedRows) {
        final code = _resolveEarnedCode(row, catalog);
        final redemptionCode = row['redeem_code']?.toString().trim() ?? '';
        if (code != null && redemptionCode.isNotEmpty) {
          redemptionCodes[code] = redemptionCode;
        }
      }

      final snapshot = RewardSnapshot(
        catalog: catalog,
        earnedCodes: earnedCodes,
        claimedBadgeCodes: claimedBadgeCodes,
        redemptionCodes: redemptionCodes,
        catalogVersion: catalogVersion,
        syncedAt: DateTime.now(),
      );
      await cache.writeMap(_cacheKey(user.id), snapshot.toJson());
      return snapshot;
    } catch (_) {
      return cached ??
          RewardSnapshot(
            catalog: fallbackCatalog,
            earnedCodes: const {},
            catalogVersion: fallbackCatalogVersion,
            syncedAt: DateTime.now(),
          );
    }
  }

  String? _resolveEarnedCode(
    Map<String, dynamic> row,
    List<RewardCatalogItem> catalog,
  ) {
    final code = row['reward_code']?.toString();
    if (code != null && code.isNotEmpty) {
      return catalog.any((item) => item.code == code) ? code : null;
    }

    final type = row['reward_type']?.toString();
    if (type == null) return null;
    for (final item in catalog) {
      if (item.title == type || item.code == type) return item.code;
    }
    return type;
  }

  Future<void> checkReward() async {
    final user = authRepository.currentUser;
    if (user == null) return;

    final snapshot = await synchronize(forceCatalogRefresh: true);
    await cache.writeMap(_cacheKey(user.id), snapshot.toJson());
  }

  Future<RewardSnapshot> claimBadge(String rewardCode) async {
    final user = authRepository.currentUser;
    if (user == null) {
      throw StateError('Sign in to collect this badge.');
    }

    await rewardRepository.claimBadge(rewardCode);
    return synchronize();
  }

  static int calculateStreak(List<DateTime> times) {
    final days =
        times
            .map((date) => DateTime(date.year, date.month, date.day))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    if (days.isEmpty) return 0;

    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    var count = 0;
    for (final day in days) {
      if (day == cursor) {
        count++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else if (count == 0 &&
          day == cursor.subtract(const Duration(days: 1))) {
        count++;
        cursor = day.subtract(const Duration(days: 1));
      } else if (day.isBefore(cursor)) {
        break;
      }
    }
    return count;
  }
}
