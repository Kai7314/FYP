class CheckinRepository {
  final supabase = Supabase.instance.client;

  Future<void> addCheckin(String userId) async {
    await supabase.from('checkins').insert({
      'user_id': userId,
      'checkin_time': DateTime.now().toIso8601String(),
      'status': 'active',
    });
  }
}
