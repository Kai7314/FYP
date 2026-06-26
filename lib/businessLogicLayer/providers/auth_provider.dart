import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/auth_controller.dart';

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController();
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authControllerProvider).authChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authControllerProvider).currentUser;
});
