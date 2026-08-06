import 'package:flutter/foundation.dart';

import 'local_cache_service.dart';

enum AppTextSize { system, large }

class AppSettings {
  const AppSettings({
    this.localRemindersEnabled = true,
    this.orenSoundsEnabled = true,
    this.reduceMotion = false,
    this.textSize = AppTextSize.system,
  });

  static const defaults = AppSettings();

  final bool localRemindersEnabled;
  final bool orenSoundsEnabled;
  final bool reduceMotion;
  final AppTextSize textSize;

  double get textScaleMultiplier => textSize == AppTextSize.large ? 1.15 : 1;

  AppSettings copyWith({
    bool? localRemindersEnabled,
    bool? orenSoundsEnabled,
    bool? reduceMotion,
    AppTextSize? textSize,
  }) {
    return AppSettings(
      localRemindersEnabled:
          localRemindersEnabled ?? this.localRemindersEnabled,
      orenSoundsEnabled: orenSoundsEnabled ?? this.orenSoundsEnabled,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      textSize: textSize ?? this.textSize,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final textSizeName = json['text_size']?.toString();
    final textSize = AppTextSize.values.where(
      (value) => value.name == textSizeName,
    );
    return AppSettings(
      localRemindersEnabled: json['local_reminders_enabled'] != false,
      orenSoundsEnabled: json['oren_sounds_enabled'] != false,
      reduceMotion: json['reduce_motion'] == true,
      textSize: textSize.isEmpty ? AppTextSize.system : textSize.first,
    );
  }

  Map<String, dynamic> toJson() => {
    'local_reminders_enabled': localRemindersEnabled,
    'oren_sounds_enabled': orenSoundsEnabled,
    'reduce_motion': reduceMotion,
    'text_size': textSize.name,
  };
}

class AppSettingsService {
  AppSettingsService({LocalCacheService? cache})
    : cache = cache ?? LocalCacheService();

  static final instance = AppSettingsService();
  static const cacheKey = 'app_settings_v1';

  final LocalCacheService cache;
  final ValueNotifier<AppSettings> settings = ValueNotifier(
    AppSettings.defaults,
  );

  bool loaded = false;
  Future<void>? loadingFuture;

  AppSettings get current => settings.value;

  Future<void> load() {
    if (loaded) return Future.value();
    return loadingFuture ??= _load();
  }

  Future<void> _load() async {
    try {
      final cached = await cache.readMap(cacheKey);
      settings.value = cached == null
          ? AppSettings.defaults
          : AppSettings.fromJson(cached);
    } catch (_) {
      settings.value = AppSettings.defaults;
    } finally {
      loaded = true;
    }
  }

  Future<void> setLocalRemindersEnabled(bool enabled) {
    return _save(current.copyWith(localRemindersEnabled: enabled));
  }

  Future<void> setOrenSoundsEnabled(bool enabled) {
    return _save(current.copyWith(orenSoundsEnabled: enabled));
  }

  Future<void> setReduceMotion(bool enabled) {
    return _save(current.copyWith(reduceMotion: enabled));
  }

  Future<void> setTextSize(AppTextSize value) {
    return _save(current.copyWith(textSize: value));
  }

  Future<void> resetToDefaults() => _save(AppSettings.defaults);

  Future<bool> areLocalRemindersEnabled() async {
    await load();
    return current.localRemindersEnabled;
  }

  Future<void> _save(AppSettings next) async {
    await load();
    await cache.writeMap(cacheKey, next.toJson());
    settings.value = next;
  }
}
