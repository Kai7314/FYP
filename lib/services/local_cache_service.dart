import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalCacheService {
  Future<Map<String, dynamic>?> readMap(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(key);
    if (raw == null) return null;

    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      await preferences.remove(key);
      return null;
    }
  }

  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, jsonEncode(value));
  }

  Future<void> remove(String key) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(key);
  }

  Future<void> removeUserData(
    String userId, {
    Set<String> preservedKeys = const {},
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final suffix = '_$userId';
    final keys = preferences
        .getKeys()
        .where((key) => key.endsWith(suffix) && !preservedKeys.contains(key))
        .toList();
    for (final key in keys) {
      await preferences.remove(key);
    }
  }
}
