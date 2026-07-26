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

  Future<void> claimBadge(String rewardCode) async {
    await client.rpc(
      'claim_current_user_badge',
      params: {'p_reward_code': rewardCode},
    );
  }

  RealtimeChannel subscribeToCatalogChanges(void Function() onChange) {
    final userId = client.auth.currentUser?.id ?? 'signed-out';
    final channel = client.channel(
      'reward-catalog-$userId-${DateTime.now().microsecondsSinceEpoch}',
    );
    return channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reward_catalog',
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<void> unsubscribeFromCatalogChanges(RealtimeChannel channel) async {
    await client.removeChannel(channel);
  }

  Future<bool> isCurrentUserAdmin() async {
    final response = await client.rpc('is_current_user_reward_admin');
    return response == true;
  }

  Future<List<Map<String, dynamic>>> getAdminCatalog() async {
    final rows = await client.rpc('list_virtual_rewards_admin');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>> saveAdminReward({
    required String code,
    required String title,
    required String description,
    required int milestoneDays,
    required bool active,
    required String rewardKind,
    String? voucherValue,
  }) async {
    final rows = await client.rpc(
      'upsert_virtual_reward_admin',
      params: {
        'p_code': code,
        'p_title': title,
        'p_description': description,
        'p_milestone_days': milestoneDays,
        'p_active': active,
        'p_reward_kind': rewardKind,
        'p_voucher_value': voucherValue,
      },
    );
    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) {
      throw StateError('The saved virtual reward was not returned.');
    }
    return list.first;
  }

  Future<int> deleteAdminRewards(Set<String> codes) async {
    final response = await client.rpc(
      'delete_virtual_rewards_admin',
      params: {'p_codes': codes.toList()},
    );
    return int.tryParse(response?.toString() ?? '') ?? 0;
  }
}
