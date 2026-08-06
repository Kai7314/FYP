import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mekiduxpnrorkfphjgpc.supabase.co',
  );
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1la2lkdXhwbnJvcmtmcGhqZ3BjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyNjExMzYsImV4cCI6MjA5MTgzNzEzNn0.5DEkGIghSMVXVQWj3WBCNQFXUSYCPbtSWyVHlrRDd4A',
  );
}

Future<void> ensureSupabaseInitialized({
  Duration timeout = const Duration(seconds: 20),
}) async {
  Future<void> initialize() async {
    try {
      Supabase.instance.client;
      return;
    } catch (_) {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
    }
  }

  await initialize().timeout(timeout);
}
