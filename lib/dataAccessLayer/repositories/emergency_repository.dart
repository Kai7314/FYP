import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/emergency_alert_model.dart';

class EmergencyRepository {
  EmergencyRepository({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  final SupabaseClient client;

  Future<Map<String, dynamic>> createAlert(
    String userId, {
    String status = 'triggered',
  }) async {
    final response = await client.rpc(
      'create_current_user_emergency_alert',
      params: {'p_status': status},
    );
    return _singleRow(response, 'emergency alert');
  }

  Future<EmergencyAlertModel> createAlertModel(String userId) async {
    final row = await createAlert(userId);
    return EmergencyAlertModel.fromJson(row);
  }

  Future<Map<String, dynamic>?> getLatestAlert(String userId) async {
    final rows = await client
        .from('emergency_alerts')
        .select()
        .eq('user_id', userId)
        .order('triggered_time', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  Future<Map<String, dynamic>?> getLatestTriggeredAlert(String userId) async {
    final rows = await client
        .from('emergency_alerts')
        .select()
        .eq('user_id', userId)
        .eq('status', 'triggered')
        .order('triggered_time', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  Future<Map<String, dynamic>?> getLatestInactivityAlert(String userId) async {
    final rows = await client
        .from('emergency_alerts')
        .select()
        .eq('user_id', userId)
        .eq('status', 'inactivity_triggered')
        .order('triggered_time', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  Future<Map<String, dynamic>?> getInactivityMonitorStatus(
    String userId,
  ) async {
    try {
      final rows = await client
          .from('inactivity_monitor_status')
          .select()
          .eq('user_id', userId)
          .limit(1);
      return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (error.code == 'PGRST205' ||
          error.code == '42P01' ||
          message.contains('inactivity_monitor_status')) {
        return null;
      }
      rethrow;
    }
  }

  Future<EmergencyAlertModel?> getLatestAlertModel(String userId) async {
    final row = await getLatestAlert(userId);
    return row == null ? null : EmergencyAlertModel.fromJson(row);
  }

  Future<void> addLocation({
    required dynamic alertId,
    required double latitude,
    required double longitude,
  }) {
    return client.rpc(
      'attach_current_user_alert_location',
      params: {
        'p_alert_id': alertId,
        'p_latitude': latitude,
        'p_longitude': longitude,
      },
    );
  }

  Future<void> createDeliveryOutbox({
    required dynamic alertId,
    required String userId,
    required List<Map<String, dynamic>> contacts,
    String? messageBody,
  }) async {
    if (contacts.isEmpty) return;
    await client.rpc(
      'queue_current_user_emergency_sms',
      params: {'p_alert_id': alertId},
    );
  }

  Future<bool> queueInactivityUserSms({
    required String userId,
    required DateTime lastCheckIn,
    required String recipientName,
    required String recipientPhone,
    required String messageBody,
  }) async {
    final response = await client.rpc(
      'queue_current_user_inactivity_sms',
      params: {
        'p_last_checkin': lastCheckIn.toUtc().toIso8601String(),
        'p_test_mode': messageBody.startsWith('TEST - '),
      },
    );
    return response == true;
  }

  Future<bool> queuePrimaryContactTestSms() async {
    final response = await client.rpc('queue_current_user_primary_test_sms');
    return response == true;
  }

  Future<Map<String, dynamic>> processPendingSms() async {
    final response = await client.functions
        .invoke('send-emergency-sms')
        .timeout(const Duration(seconds: 30));
    final data = response.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _singleRow(Object? response, String label) {
    final row = response is List
        ? (response.isEmpty ? null : response.first)
        : response;
    if (row is! Map) {
      throw StateError('Supabase did not return the $label.');
    }
    return Map<String, dynamic>.from(row);
  }
}
