class WeatherSnapshot {
  const WeatherSnapshot({
    required this.temperatureCelsius,
    required this.weatherCode,
    required this.isDay,
    required this.latitude,
    required this.longitude,
    required this.fetchedAt,
  });

  final double temperatureCelsius;
  final int weatherCode;
  final bool isDay;
  final double latitude;
  final double longitude;
  final DateTime fetchedAt;

  bool get isRainy => const {
    51,
    53,
    55,
    56,
    57,
    61,
    63,
    65,
    66,
    67,
    80,
    81,
    82,
    95,
    96,
    99,
  }.contains(weatherCode);

  String get description {
    if (isRainy) return 'Rainy';
    if (weatherCode == 0) return 'Clear';
    if (weatherCode <= 3) return 'Cloudy';
    if (weatherCode == 45 || weatherCode == 48) return 'Foggy';
    return 'Current weather';
  }

  String get backgroundAsset {
    if (isRainy) return 'lib/assets/images/raining.jpg';
    if (!isDay) return 'lib/assets/images/night.jpg';

    final hour = DateTime.now().hour;
    if (hour >= 17 && hour < 20) return 'lib/assets/images/sunset.jpg';
    return 'lib/assets/images/day.jpg';
  }

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    return WeatherSnapshot(
      temperatureCelsius:
          double.tryParse(json['temperature_celsius']?.toString() ?? '') ?? 0,
      weatherCode: int.tryParse(json['weather_code']?.toString() ?? '') ?? 0,
      isDay: json['is_day'] == true || json['is_day']?.toString() == '1',
      latitude: double.tryParse(json['latitude']?.toString() ?? '') ?? 0,
      longitude: double.tryParse(json['longitude']?.toString() ?? '') ?? 0,
      fetchedAt:
          DateTime.tryParse(json['fetched_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
    'temperature_celsius': temperatureCelsius,
    'weather_code': weatherCode,
    'is_day': isDay,
    'latitude': latitude,
    'longitude': longitude,
    'fetched_at': fetchedAt.toIso8601String(),
  };
}
