import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/strings.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screen/auth/auth_gate.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://mekiduxpnrorkfphjgpc.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1la2lkdXhwbnJvcmtmcGhqZ3BjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYyNjExMzYsImV4cCI6MjA5MTgzNzEzNn0.5DEkGIghSMVXVQWj3WBCNQFXUSYCPbtSWyVHlrRDd4A',
  );
  await NotificationService.instance.initialize();
  await NotificationService.instance.scheduleDailyCheckInReminder();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}
