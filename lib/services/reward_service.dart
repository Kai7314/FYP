import '../dataAccessLayer/repositories/auth_repository.dart';
import '../dataAccessLayer/repositories/checkin_repository.dart';
import '../dataAccessLayer/repositories/reward_repository.dart';
import '../models/reward_model.dart';
import 'local_cache_service.dart';

class RewardService {
  RewardService({
    LocalCacheService? cache,
    AuthRepository? authRepository,
    CheckinRepository? checkinRepository,
    RewardRepository? rewardRepository,
  }) : cache = cache ?? LocalCacheService(),
       authRepository = authRepository ?? AuthRepository(),
       checkinRepository = checkinRepository ?? CheckinRepository(),
       rewardRepository = rewardRepository ?? RewardRepository();

  final LocalCacheService cache;
  final AuthRepository authRepository;
  final CheckinRepository checkinRepository;
  final RewardRepository rewardRepository;

  static const fallbackCatalog = <RewardCatalogItem>[
    RewardCatalogItem(
      code: 'tealive_bogo',
      title: 'Tealive Buy 1 Free 1',
      sponsor: 'Tealive',
      description: 'A virtual buy-one-free-one beverage voucher.',
      milestoneDays: 3,
      rewardKind: 'voucher',
      voucherValue: 'Buy 1 Free 1',
      catalogVersion: 1,
    ),
    RewardCatalogItem(
      code: 'milo_400g',
      title: 'Milo Chocolate Drink',
      sponsor: 'Nestle',
      description: 'One Milo 400g tin.',
      milestoneDays: 7,
      rewardKind: 'physical',
      catalogVersion: 1,
    ),
    RewardCatalogItem(
      code: 'shopee_rm5',
      title: 'Shopee RM5 Voucher',
      sponsor: 'Shopee',
      description: 'A virtual RM5 shopping voucher.',
      milestoneDays: 10,
      rewardKind: 'voucher',
      voucherValue: 'RM5',
      catalogVersion: 1,
    ),
    RewardCatalogItem(
      code: 'tissue_bundle',
      title: 'Premium Tissue Bundle',
      sponsor: 'Kleenex',
      description: 'Three premium soft tissue boxes.',
      milestoneDays: 14,
      rewardKind: 'physical',
      catalogVersion: 1,
    ),
    RewardCatalogItem(
      code: 'green_tea',
      title: 'Green Tea Collection',
      sponsor: 'TWG Tea',
      description: 'A calming premium tea collection.',
      milestoneDays: 30,
      rewardKind: 'physical',
      catalogVersion: 1,
    ),
  ];

  String _cacheKey(String userId) => 'rewards_snapshot_v2_$userId';

  Future<RewardSnapshot?> loadCached() async {
    final user = authRepository.currentUser;
    if (user == null) return null;
    final value = await cache.readMap(_cacheKey(user.id));
    return value == null ? null : RewardSnapshot.fromJson(value);
  }

  Future<RewardSnapshot> synchronize({bool forceCatalogRefresh = false}) async {
    final user = authRepository.currentUser;
    if (user == null) {
      return RewardSnapshot(
        catalog: fallbackCatalog,
        earnedCodes: const {},
        catalogVersion: 1,
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
            remoteVersion > catalogVersion) {
          final catalogRows = await rewardRepository.getActiveCatalog();
          final remoteCatalog = catalogRows
              .map(
                (row) =>
                    RewardCatalogItem.fromJson(Map<String, dynamic>.from(row)),
              )
              .where((item) => item.code.isNotEmpty)
              .toList();
          if (remoteCatalog.isNotEmpty) {
            catalog = remoteCatalog;
            catalogVersion = remoteVersion;
          }
        }
      } catch (_) {
        if (catalog.isEmpty) catalog = fallbackCatalog;
        if (catalogVersion == 0) catalogVersion = 1;
      }

      final earnedRows = await rewardRepository.getEarnedRewards(user.id);
      final earnedCodes = earnedRows
          .map((row) => _resolveEarnedCode(row, catalog))
          .whereType<String>()
          .toSet();

      final snapshot = RewardSnapshot(
        catalog: catalog,
        earnedCodes: earnedCodes,
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
            catalogVersion: 1,
            syncedAt: DateTime.now(),
          );
    }
  }

  String? _resolveEarnedCode(
    Map<String, dynamic> row,
    List<RewardCatalogItem> catalog,
  ) {
    final code = row['reward_code']?.toString();
    if (code != null && code.isNotEmpty) return code;

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

    final streak = calculateStreak(
      await checkinRepository.getCheckinTimes(user.id),
    );

    var snapshot = await synchronize();
    for (final item in snapshot.catalog) {
      if (streak < item.milestoneDays ||
          snapshot.earnedCodes.contains(item.code)) {
        continue;
      }

      await rewardRepository.addEarnedReward(
        userId: user.id,
        code: item.code,
        title: item.title,
        milestoneDays: item.milestoneDays,
      );
    }
    snapshot = await synchronize(forceCatalogRefresh: true);
    await cache.writeMap(_cacheKey(user.id), snapshot.toJson());
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
