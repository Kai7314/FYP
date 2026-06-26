import '../../models/reward_model.dart';
import '../../services/reward_service.dart';

class RewardController {
  RewardController({RewardService? rewardService})
    : rewardService = rewardService ?? RewardService();

  final RewardService rewardService;

  Future<RewardSnapshot?> cached() => rewardService.loadCached();
  Future<RewardSnapshot> sync({bool forceCatalogRefresh = false}) {
    return rewardService.synchronize(forceCatalogRefresh: forceCatalogRefresh);
  }
}
