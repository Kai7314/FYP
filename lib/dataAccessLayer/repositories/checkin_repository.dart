import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/checkin_model.dart';

class CheckinRepository {
  CheckinRepository({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> getCheckins(String userId) async {
    final rows = await client
        .from('checkins')
        .select()
        .eq('user_id', userId)
        .order('checkin_time', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<CheckinModel>> getCheckinModels(String userId) async {
    final rows = await getCheckins(userId);
    return rows.map(CheckinModel.fromJson).toList();
  }

  Future<List<DateTime>> getCheckinTimes(String userId) async {
    final rows = await client
        .from('checkins')
        .select('checkin_time')
        .eq('user_id', userId)
        .order('checkin_time', ascending: false);
    return rows
        .map<DateTime?>(
          (row) => DateTime.tryParse(row['checkin_time'].toString()),
        )
        .whereType<DateTime>()
        .toList();
  }

  Future<Map<String, dynamic>?> getLatestCheckin(String userId) async {
    final rows = await client
        .from('checkins')
        .select()
        .eq('user_id', userId)
        .order('checkin_time', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  Future<bool> addThresholdCheckin({
    required String userId,
    required DateTime now,
    required int thresholdHours,
  }) async {
    try {
      final response = await client.rpc('record_threshold_checkin');
      final row = response is List && response.isNotEmpty
          ? response.first
          : response;
      if (row is Map && row.containsKey('created')) {
        return row['created'] == true;
      }
    } on PostgrestException catch (error) {
      if (!_isMissingThresholdCheckinRpc(error)) rethrow;
    }

    final threshold = thresholdHours.clamp(1, 168).toInt();
    final latest = await getLatestCheckin(userId);
    final latestTime = latest == null
        ? null
        : DateTime.tryParse(latest['checkin_time'].toString());
    if (latestTime != null &&
        now.difference(latestTime) < Duration(hours: threshold)) {
      return false;
    }

    await client.from('checkins').insert({
      'user_id': userId,
      'checkin_time': now.toIso8601String(),
      'status': 'active',
    });
    return true;
  }

  bool _isMissingThresholdCheckinRpc(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == 'PGRST202' ||
        error.code == '42883' ||
        (message.contains('record_threshold_checkin') &&
            (message.contains('function') || message.contains('schema cache')));
  }
}
