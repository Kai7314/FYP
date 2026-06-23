import 'package:supabase_flutter/supabase_flutter.dart';

class EmergencyRepository {
  EmergencyRepository({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;

  final SupabaseClient client;

  Future<Map<String, dynamic>> createAlert(String userId) async {
    final row = await client
        .from('emergency_alerts')
        .insert({
          'user_id': userId,
          'triggered_time': DateTime.now().toIso8601String(),
          'status': 'triggered',
        })
        .select()
        .single();
    return Map<String, dynamic>.from(row);
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

  Future<void> addLocation({
    required dynamic alertId,
    required double latitude,
    required double longitude,
  }) {
    return client.from('locations').insert({
      'alert_id': alertId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> createDeliveryOutbox({
    required dynamic alertId,
    required String userId,
    required List<Map<String, dynamic>> contacts,
  }) async {
    if (contacts.isEmpty) return;
    final rows = contacts
        .map(
          (contact) => {
            'alert_id': alertId.toString(),
            'user_id': userId,
            'contact_name': contact['name'],
            'contact_phone': contact['phone'],
            'status': 'pending',
            'attempt_count': 0,
          },
        )
        .toList();
    await client.from('emergency_delivery_outbox').insert(rows);
  }
}
