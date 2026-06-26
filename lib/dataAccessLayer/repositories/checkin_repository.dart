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

  Future<bool> addDailyCheckin(String userId, DateTime now) async {
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final existing = await client
        .from('checkins')
        .select('checkin_time')
        .eq('user_id', userId)
        .gte('checkin_time', today.toUtc().toIso8601String())
        .lt('checkin_time', tomorrow.toUtc().toIso8601String())
        .limit(1);
    if (existing.isNotEmpty) return false;

    await client.from('checkins').insert({
      'user_id': userId,
      'checkin_time': now.toIso8601String(),
      'status': 'active',
    });
    return true;
  }
}
