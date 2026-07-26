import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../dataAccessLayer/repositories/auth_repository.dart';
import '../dataAccessLayer/repositories/reward_repository.dart';
import '../models/reward_model.dart';

class RewardAdminService {
  RewardAdminService({
    AuthRepository? authRepository,
    RewardRepository? rewardRepository,
  }) : authRepository = authRepository ?? AuthRepository(),
       rewardRepository = rewardRepository ?? RewardRepository();

  final AuthRepository authRepository;
  final RewardRepository rewardRepository;
  RealtimeChannel? _catalogChannel;

  Future<bool> isCurrentUserAdmin() {
    return rewardRepository.isCurrentUserAdmin();
  }

  Future<List<RewardCatalogItem>> getCatalog() async {
    final rows = await rewardRepository.getAdminCatalog();
    return rows.map(RewardCatalogItem.fromJson).toList();
  }

  Future<RewardCatalogItem> saveReward({
    required String code,
    required String title,
    required String description,
    required int milestoneDays,
    required bool active,
    required String rewardKind,
    String? voucherValue,
  }) async {
    final row = await rewardRepository.saveAdminReward(
      code: code,
      title: title,
      description: description,
      milestoneDays: milestoneDays,
      active: active,
      rewardKind: rewardKind,
      voucherValue: voucherValue,
    );
    return RewardCatalogItem.fromJson(row);
  }

  Future<int> deleteRewards(Set<String> codes) {
    return rewardRepository.deleteAdminRewards(codes);
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

  Future<void> signOut() => authRepository.signOut();
}
