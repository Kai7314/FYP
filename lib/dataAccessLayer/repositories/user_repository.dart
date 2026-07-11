import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_model.dart';

class UserRepository {
  UserRepository({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  final SupabaseClient client;

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final rows = await client.from('users').select().eq('id', userId).limit(1);
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  Future<UserModel?> getUserModel(String userId) async {
    final row = await getProfile(userId);
    return row == null ? null : UserModel.fromJson(row);
  }

  Future<void> createProfileIfMissing({
    required String userId,
    required String name,
  }) async {
    try {
      await client.rpc('ensure_current_user_profile');
    } on PostgrestException catch (error) {
      if (!_isMissingEnsureProfileRpc(error)) rethrow;
    }

    final profile = await getProfile(userId);
    if (profile != null) return;
    await client.from('users').upsert({'id': userId, 'name': name});
  }

  Future<void> updateProfile({
    required String userId,
    required Map<String, dynamic> values,
  }) {
    return client.from('users').upsert({'id': userId, ...values});
  }

  bool _isMissingEnsureProfileRpc(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == 'PGRST202' ||
        error.code == '42883' ||
        (message.contains('ensure_current_user_profile') &&
            (message.contains('function') || message.contains('schema cache')));
  }
}
