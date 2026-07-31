import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../core/config/supabase_config.dart';
import '../services/inactivity_service.dart';

class PlatformBackgroundScheduler {
  static const uniqueInactivityTask = 'ethernacare.periodicInactivityCheck';
  static const inactivityTask = 'ethernacare.inactivityCheck';
  static const taskTag = 'ethernacare.safety';
  static bool _initialized = false;

  Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    if (!_initialized) {
      await Workmanager().initialize(ethernaCareWorkmanagerCallbackDispatcher);
      _initialized = true;
    }

    await Workmanager().registerPeriodicTask(
      uniqueInactivityTask,
      inactivityTask,
      frequency: const Duration(minutes: 15),
      initialDelay: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      tag: taskTag,
    );
  }
}

@pragma('vm:entry-point')
void ethernaCareWorkmanagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != PlatformBackgroundScheduler.inactivityTask &&
        task != Workmanager.iOSBackgroundTask) {
      return true;
    }

    try {
      await ensureSupabaseInitialized();
      await InactivityService().checkInactivity();
      return true;
    } catch (error) {
      debugPrint('EthernaCare background check failed: $error');
      return false;
    }
  });
}
