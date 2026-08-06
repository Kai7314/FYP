import 'package:flutter_test/flutter_test.dart';
import 'package:fyp/services/app_settings_service.dart';
import 'package:fyp/services/local_cache_service.dart';

class _MemoryCacheService extends LocalCacheService {
  final Map<String, Map<String, dynamic>> values = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async {
    final value = values[key];
    return value == null ? null : Map<String, dynamic>.from(value);
  }

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    values[key] = Map<String, dynamic>.from(value);
  }
}

void main() {
  test('app settings load saved device preferences', () async {
    final cache = _MemoryCacheService();
    cache.values[AppSettingsService.cacheKey] = {
      'local_reminders_enabled': false,
      'oren_sounds_enabled': false,
      'reduce_motion': true,
      'text_size': 'large',
    };
    final service = AppSettingsService(cache: cache);

    await service.load();

    expect(service.current.localRemindersEnabled, isFalse);
    expect(service.current.orenSoundsEnabled, isFalse);
    expect(service.current.reduceMotion, isTrue);
    expect(service.current.textSize, AppTextSize.large);
    expect(service.current.textScaleMultiplier, 1.15);
  });

  test('app settings persist changes and restore defaults', () async {
    final cache = _MemoryCacheService();
    final service = AppSettingsService(cache: cache);

    await service.setOrenSoundsEnabled(false);
    await service.setReduceMotion(true);
    await service.setTextSize(AppTextSize.large);

    final saved = cache.values[AppSettingsService.cacheKey]!;
    expect(saved['oren_sounds_enabled'], isFalse);
    expect(saved['reduce_motion'], isTrue);
    expect(saved['text_size'], 'large');

    await service.resetToDefaults();

    expect(service.current.localRemindersEnabled, isTrue);
    expect(service.current.orenSoundsEnabled, isTrue);
    expect(service.current.reduceMotion, isFalse);
    expect(service.current.textSize, AppTextSize.system);
  });
}
