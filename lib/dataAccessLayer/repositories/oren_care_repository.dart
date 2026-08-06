import 'package:supabase_flutter/supabase_flutter.dart';

class OrenCareRepository {
  OrenCareRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get client => _client ?? Supabase.instance.client;

  Future<Map<String, dynamic>> loadState({
    Map<String, dynamic>? legacyState,
  }) async {
    final response = legacyState == null
        ? await client.rpc('get_current_user_oren_state')
        : await client.rpc(
            'migrate_current_user_oren_state',
            params: {'p_legacy': legacyState},
          );
    return _singleRow(response);
  }

  Future<Map<String, dynamic>> performAction(
    String action, {
    String? toyId,
  }) async {
    final response = await client.rpc(
      'perform_current_user_oren_action',
      params: {'p_action': action, 'p_toy_id': toyId},
    );
    return _singleRow(response);
  }

  Map<String, dynamic> _singleRow(Object? response) {
    final row = response is List
        ? (response.isEmpty ? null : response.first)
        : response;
    if (row is! Map) {
      throw StateError('Supabase did not return Oren care state.');
    }
    return Map<String, dynamic>.from(row);
  }
}
