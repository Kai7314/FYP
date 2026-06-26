import '../../services/checkin_service.dart';
import '../../services/reward_service.dart';

class CheckinController {
  CheckinController({
    CheckinService? checkinService,
    RewardService? rewardService,
  }) : checkinService = checkinService ?? CheckinService(),
       rewardService = rewardService ?? RewardService();

  final CheckinService checkinService;
  final RewardService rewardService;

  Future<bool> checkInToday() async {
    final created = await checkinService.addCheckin();
    if (created) await rewardService.checkReward();
    return created;
  }

  Future<List<Map<String, dynamic>>> history({bool refresh = false}) {
    return checkinService.getCheckins(forceRefresh: refresh);
  }
}
