import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'presentation/screen/auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://mekiduxpnrorkfphjgpc.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1la2lkdXhwbnJvcmtmcGhqZ3BjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyNjExMzYsImV4cCI6MjA5MTgzNzEzNn0.5DEkGIghSMVXVQWj3WBCNQFXUSYCPbtSWyVHlrRDd4A',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthGate(),
    );
  }
}
