import 'package:supabase_flutter/supabase_flutter.dart';

class RewardRepository {
  RewardRepository({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  final SupabaseClient client;

  Future<int> getLatestCatalogVersion() async {
    final rows = await client
        .from('reward_catalog')
        .select('catalog_version')
        .eq('active', true)
        .order('catalog_version', ascending: false)
        .limit(1);
    return rows.isEmpty
        ? 0
        : int.tryParse(rows.first['catalog_version']?.toString() ?? '') ?? 0;
  }

  Future<List<Map<String, dynamic>>> getActiveCatalog() async {
    final rows = await client
        .from('reward_catalog')
        .select()
        .eq('active', true)
        .order('milestone_days', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> getEarnedRewards(String userId) async {
    final rows = await client.from('rewards').select().eq('user_id', userId);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> synchronizeEarnedRewards() async {
    await client.rpc('sync_current_user_rewards');
  }
}
