import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/malaysia_locations.dart';
import '../models/location_model.dart';
import 'local_cache_service.dart';
import 'location_service.dart';
import 'user_service.dart';

class WeatherService {
  WeatherService({
    LocalCacheService? cache,
    LocationService? locationService,
    UserService? userService,
    http.Client? client,
  }) : cache = cache ?? LocalCacheService(),
       locationService = locationService ?? LocationService(),
       userService = userService ?? UserService(),
       client = client ?? http.Client();

  static const cacheKey = 'weather_current_malaysia_v2';
  static const cacheLifetime = Duration(minutes: 30);

  final LocalCacheService cache;
  final LocationService locationService;
  final UserService userService;
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
      final profileWeather = await _getDataGovWeatherFromProfile();
      if (profileWeather != null) {
        await cache.writeMap(cacheKey, profileWeather.toJson());
        return profileWeather;
      }

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

  Future<WeatherSnapshot?> _getDataGovWeatherFromProfile() async {
    final profile = await userService.getCurrentProfile();
    final state = profile['address_state']?.toString();
    final region = profile['address_region']?.toString();
    final location = MalaysiaLocations.find(state, region);
    if (location == null) return null;

    final today = DateTime.now();
    final date = [
      today.year.toString().padLeft(4, '0'),
      today.month.toString().padLeft(2, '0'),
      today.day.toString().padLeft(2, '0'),
    ].join('-');
    final uri = Uri.https('api.data.gov.my', '/weather/forecast/', {
      'contains': '${location.queryName}@location__location_name',
      'date_start': '$date@date',
      'date_end': '$date@date',
    });
    final response = await client.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;

    final rows = jsonDecode(response.body);
    if (rows is! List || rows.isEmpty) return null;
    final row = _bestDataGovRow(rows);
    if (row == null) return null;

    final forecast = row['summary_forecast']?.toString() ?? '';
    final minTemp = double.tryParse(row['min_temp']?.toString() ?? '');
    final maxTemp = double.tryParse(row['max_temp']?.toString() ?? '');
    final weatherCode = _weatherCodeForDataGovForecast(forecast);
    final locationMap = row['location'] is Map
        ? Map<String, dynamic>.from(row['location'] as Map)
        : const <String, dynamic>{};

    return WeatherSnapshot(
      temperatureCelsius: maxTemp ?? minTemp ?? 0,
      weatherCode: weatherCode,
      isDay: DateTime.now().hour >= 7 && DateTime.now().hour < 19,
      latitude: 0,
      longitude: 0,
      fetchedAt: DateTime.now(),
      locationName: locationMap['location_name']?.toString() ?? location.region,
      summaryForecast: forecast,
      summaryWhen: row['summary_when']?.toString(),
      minTemperatureCelsius: minTemp,
      maxTemperatureCelsius: maxTemp,
    );
  }

  Map<String, dynamic>? _bestDataGovRow(List<dynamic> rows) {
    Map<String, dynamic>? fallback;
    for (final item in rows) {
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      fallback ??= row;
      final location = row['location'];
      final id = location is Map ? location['location_id']?.toString() : null;
      if (id != null && id.startsWith('Ds')) return row;
    }
    return fallback;
  }

  int _weatherCodeForDataGovForecast(String forecast) {
    final text = forecast.toLowerCase();
    if (text.contains('tiada hujan') || text.contains('cerah')) return 0;
    if (text.contains('ribut petir')) return 95;
    if (text.contains('hujan')) return 61;
    if (text.contains('mendung') || text.contains('berawan')) return 3;
    return 2;
  }
}
