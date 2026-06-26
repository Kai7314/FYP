import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/user_service.dart';

final userServiceProvider = Provider<UserService>((ref) {
  return UserService();
});

final currentProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
      return ref.watch(userServiceProvider).getCurrentProfile();
    });
