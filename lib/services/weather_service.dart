import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/location_model.dart';
import 'local_cache_service.dart';
import 'location_service.dart';

class WeatherService {
  WeatherService({
    LocalCacheService? cache,
    LocationService? locationService,
    http.Client? client,
  }) : cache = cache ?? LocalCacheService(),
       locationService = locationService ?? LocationService(),
       client = client ?? http.Client();

  static const cacheKey = 'weather_current_malaysia_v2';
  static const cacheLifetime = Duration(minutes: 30);

  final LocalCacheService cache;
  final LocationService locationService;
  final http.Client client;

  Future<WeatherSnapshot?> loadCached() async {
    final value = await cache.readMap(cacheKey);
    return value == null ? null : WeatherSnapshot.fromJson(value);
  }

  Future<WeatherSnapshot?> getCurrentWeather({
    bool forceRefresh = false,
  }) async {
    final cached = await loadCached();
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.fetchedAt) < cacheLifetime) {
      return cached;
    }

    try {
      final position = await locationService.getBestAvailablePosition();
      if (position == null) return cached;

      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': position.latitude.toString(),
        'longitude': position.longitude.toString(),
        'current': 'temperature_2m,weather_code,is_day',
        'timezone': 'auto',
      });
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return cached;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final current = Map<String, dynamic>.from(data['current'] as Map);
      final snapshot = WeatherSnapshot(
        temperatureCelsius:
            double.tryParse(current['temperature_2m'].toString()) ?? 0,
        weatherCode: int.tryParse(current['weather_code'].toString()) ?? 0,
        isDay: current['is_day'].toString() == '1',
        latitude: position.latitude,
        longitude: position.longitude,
        fetchedAt: DateTime.now(),
      );
      await cache.writeMap(cacheKey, snapshot.toJson());
      return snapshot;
    } catch (_) {
      return cached;
    }
  }
}
