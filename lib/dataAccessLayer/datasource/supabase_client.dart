import 'package:supabase_flutter/supabase_flutter.dart';

class AppSupabaseClient {
  const AppSupabaseClient._();

  static SupabaseClient get instance => Supabase.instance.client;
}
