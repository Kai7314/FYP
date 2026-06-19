import 'package:supabase_flutter/supabase_flutter.dart';

import 'location_service.dart';

class EmergencyService {
  final supabase = Supabase.instance.client;

  Future<bool> triggerEmergency() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to send an emergency alert.');
    }

    final contacts = await supabase
        .from('contacts')
        .select()
        .eq('user_id', user.id)
        .limit(1);
    if (contacts.isEmpty) return false;

    final alert = await supabase
        .from('emergency_alerts')
        .insert({
          'user_id': user.id,
          'triggered_time': DateTime.now().toIso8601String(),
          'status': 'triggered',
        })
        .select()
        .single();

    final position = await LocationService().getCurrentPosition();
    final alertId = alert['id'] ?? alert['alert_id'];
    if (position != null && alertId != null) {
      try {
        await supabase.from('locations').insert({
          'alert_id': alertId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        // The emergency alert remains valid even when location persistence
        // is unavailable or the optional locations table is not configured.
      }
    }
    return true;
  }
}
