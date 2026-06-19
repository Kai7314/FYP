import 'package:supabase_flutter/supabase_flutter.dart';

import 'emergency_service.dart';

class InactivityService {
  final supabase = Supabase.instance.client;

  Future<void> checkInactivity() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final results = await Future.wait([
      supabase
          .from('checkins')
          .select()
          .eq('user_id', user.id)
          .order('checkin_time', ascending: false)
          .limit(1),
      supabase.from('users').select().eq('id', user.id).limit(1),
      supabase
          .from('emergency_alerts')
          .select()
          .eq('user_id', user.id)
          .order('triggered_time', ascending: false)
          .limit(1),
    ]);

    final checkins = results[0];
    if (checkins.isEmpty) return;
    final profiles = results[1];
    final alerts = results[2];
    final threshold =
        int.tryParse(
          profiles.isEmpty
              ? ''
              : profiles.first['inactivity_threshold']?.toString() ?? '',
        ) ??
        24;
    final lastCheckin = DateTime.tryParse(
      checkins.first['checkin_time'].toString(),
    );
    if (lastCheckin == null ||
        DateTime.now().difference(lastCheckin).inHours <= threshold) {
      return;
    }

    final lastAlert = alerts.isEmpty
        ? null
        : DateTime.tryParse(alerts.first['triggered_time'].toString());
    if (lastAlert != null &&
        DateTime.now().difference(lastAlert).inHours < threshold) {
      return;
    }

    await EmergencyService().triggerEmergency();
  }
}
