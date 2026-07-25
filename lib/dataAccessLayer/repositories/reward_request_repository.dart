import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/reward_request_model.dart';

class RewardRequestRepository {
  RewardRequestRepository({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  final SupabaseClient client;

  Future<bool> isCurrentUserAdmin() async {
    final response = await client.rpc('is_current_user_reward_admin');
    return response == true;
  }

  Future<List<Map<String, dynamic>>> getOwnRequests(String userId) async {
    final rows = await client
        .from('reward_requests')
        .select()
        .eq('user_id', userId)
        .order('requested_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> createRequest({
    required String rewardCode,
    required RewardDeliveryDetails delivery,
  }) async {
    final response = await client.rpc(
      'request_current_user_reward',
      params: {
        'p_reward_code': rewardCode,
        'p_recipient_name': delivery.recipientName,
        'p_contact_phone': delivery.contactPhone,
        'p_delivery_address': delivery.address,
        'p_delivery_state': delivery.state,
        'p_delivery_region': delivery.region,
      },
    );
    return _singleRow(response);
  }

  Future<List<Map<String, dynamic>>> getAdminRequests() async {
    final response = await client.rpc('list_reward_requests_admin');
    if (response is! List) return const [];
    return response
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<Map<String, dynamic>> updateAdminRequest({
    required String requestId,
    required String status,
    String? trackingReference,
    String? adminNotes,
  }) async {
    final response = await client.rpc(
      'update_reward_request_admin',
      params: {
        'p_request_id': requestId,
        'p_status': status,
        'p_tracking_reference': trackingReference,
        'p_admin_notes': adminNotes,
      },
    );
    return _singleRow(response);
  }

  Map<String, dynamic> _singleRow(dynamic response) {
    if (response is Map) return Map<String, dynamic>.from(response);
    if (response is List && response.isNotEmpty) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    throw StateError('The reward request was not returned by the server.');
  }
}
