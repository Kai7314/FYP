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
    final response = await client.rpc('record_threshold_checkin');
    final row = response is List && response.isNotEmpty
        ? response.first
        : response;
    if (row is Map && row.containsKey('created')) {
      return row['created'] == true;
    }
    throw StateError('Supabase did not return the check-in result.');
  }
}
