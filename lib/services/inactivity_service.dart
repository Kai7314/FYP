import 'package:supabase_flutter/supabase_flutter.dart';
import 'emergency_service.dart';

class InactivityService {
  final supabase = Supabase.instance.client;

  Future<void> checkInactivity() async {
    final user = supabase.auth.currentUser;

    final data = await supabase
        .from('checkins')
        .select()
        .eq('user_id', user!.id)
        .order('checkin_time', ascending: false)
        .limit(1);

    if (data.isEmpty) return;

    final last = DateTime.parse(data[0]['checkin_time']);
    final now = DateTime.now();

    if (now.difference(last).inHours > 24) {
      await EmergencyService().triggerEmergency();
    }
  }
}
