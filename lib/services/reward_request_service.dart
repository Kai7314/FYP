import '../dataAccessLayer/repositories/auth_repository.dart';
import '../dataAccessLayer/repositories/reward_request_repository.dart';
import '../models/reward_request_model.dart';

class RewardRequestService {
  RewardRequestService({
    AuthRepository? authRepository,
    RewardRequestRepository? repository,
  }) : authRepository = authRepository ?? AuthRepository(),
       repository = repository ?? RewardRequestRepository();

  final AuthRepository authRepository;
  final RewardRequestRepository repository;

  Future<bool> isCurrentUserAdmin() => repository.isCurrentUserAdmin();

  Future<List<RewardRequest>> getOwnRequests() async {
    final user = authRepository.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    final rows = await repository.getOwnRequests(user.id);
    return rows.map(RewardRequest.fromJson).toList();
  }

  Future<RewardRequest> requestReward({
    required String rewardCode,
    required RewardDeliveryDetails delivery,
  }) async {
    final row = await repository.createRequest(
      rewardCode: rewardCode,
      delivery: delivery,
    );
    return RewardRequest.fromJson(row);
  }

  Future<List<RewardRequest>> getAdminRequests() async {
    final rows = await repository.getAdminRequests();
    return rows.map(RewardRequest.fromJson).toList();
  }

  Future<RewardRequest> updateAdminRequest({
    required String requestId,
    required String status,
    String? trackingReference,
    String? adminNotes,
  }) async {
    final row = await repository.updateAdminRequest(
      requestId: requestId,
      status: status,
      trackingReference: trackingReference,
      adminNotes: adminNotes,
    );
    return RewardRequest.fromJson(row);
  }
}
