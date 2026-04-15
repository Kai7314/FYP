import 'package:supabase_flutter/supabase_flutter.dart';

class EmergencyService {
  final supabase = Supabase.instance.client;

  Future<void> triggerEmergency() async {
    final user = supabase.auth.currentUser;

    await supabase.from('emergency_alerts').insert({
      'user_id': user!.id,
      'triggered_time': DateTime.now().toIso8601String(),
      'status': 'triggered',
    });
  }
}
