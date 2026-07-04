class WeatherSnapshot {
  const WeatherSnapshot({
    required this.temperatureCelsius,
    required this.weatherCode,
    required this.isDay,
    required this.latitude,
    required this.longitude,
    required this.fetchedAt,
    this.locationName,
    this.summaryForecast,
    this.summaryWhen,
    this.minTemperatureCelsius,
    this.maxTemperatureCelsius,
  });

  final double temperatureCelsius;
  final int weatherCode;
  final bool isDay;
  final double latitude;
  final double longitude;
  final DateTime fetchedAt;
  final String? locationName;
  final String? summaryForecast;
  final String? summaryWhen;
  final double? minTemperatureCelsius;
  final double? maxTemperatureCelsius;

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
    if (summaryForecast != null && summaryForecast!.trim().isNotEmpty) {
      return summaryForecast!;
    }
    if (isRainy) return 'Rainy';
    if (weatherCode == 0) return 'Clear';
    if (weatherCode <= 3) return 'Cloudy';
    if (weatherCode == 45 || weatherCode == 48) return 'Foggy';
    return 'Current weather';
  }

  String get malaysiaRegion {
    final lat = latitude;
    final lng = longitude;
    if (locationName != null && locationName!.trim().isNotEmpty) {
      return locationName!;
    }
    if (!_isInMalaysia) return 'Current location';

    if (lat >= 5.8 && lng < 100.8) return 'Kedah / Perlis';
    if (lat >= 5.1 && lng < 101.0) return 'Penang';
    if (lat >= 4.0 && lng < 101.8) return 'Perak';
    if (lat >= 2.6 && lng >= 101.0 && lng < 102.0) {
      return 'Klang Valley';
    }
    if (lat >= 1.9 && lng >= 102.0 && lng < 103.1) return 'Melaka / Johor';
    if (lat < 2.2 && lng >= 103.0 && lng < 104.6) return 'Johor';
    if (lat >= 2.4 && lng >= 102.0 && lng < 103.8) {
      return 'Negeri Sembilan / Pahang';
    }
    if (lat >= 3.0 && lng >= 102.0 && lng < 104.5) return 'Pahang';
    if (lat >= 4.0 && lng >= 102.0 && lng < 103.8) return 'Terengganu';
    if (lat >= 4.5 && lng >= 101.8 && lng < 102.8) return 'Kelantan';
    if (lng >= 109.0 && lng < 115.8) return 'Sarawak';
    if (lng >= 115.0 && lng <= 119.5) return 'Sabah / Labuan';
    return 'Malaysia';
  }

  String get compactMalaysiaRegion {
    final region = malaysiaRegion.trim();
    if (region.isEmpty) return 'MY';
    const aliases = {
      'Current location': 'Current',
      'Kedah / Perlis': 'KD/PLS',
      'Melaka / Johor': 'MLK/JHR',
      'Negeri Sembilan / Pahang': 'NS/PHG',
      'Sabah / Labuan': 'SBH/LBN',
      'Klang Valley': 'KV',
      'Kuala Lumpur': 'KL',
      'Johor Bahru': 'JB',
      'Batu Pahat': 'BP',
      'Kota Tinggi': 'KTG',
      'Alor Setar': 'AS',
      'Sungai Petani': 'SP',
      'Gua Musang': 'GM',
      'Kota Bharu': 'KB',
      'Kuala Krai': 'KK',
      'Pasir Mas': 'PM',
      'Tanah Merah': 'TM',
      'Alor Gajah': 'AG',
      'Melaka Tengah': 'MT',
      'Negeri Sembilan': 'NS',
      'Kuala Pilah': 'KP',
      'Port Dickson': 'PD',
      'Cameron Highlands': 'CH',
      'Bukit Mertajam': 'BM',
      'George Town': 'GT',
      'Nibong Tebal': 'NT',
      'Kuala Kangsar': 'KKG',
      'Teluk Intan': 'TI',
      'Padang Besar': 'PB',
      'Kota Kinabalu': 'KK',
      'Lahad Datu': 'LD',
      'Sri Aman': 'SA',
      'Kuala Selangor': 'KS',
      'Petaling Jaya': 'PJ',
      'Shah Alam': 'SA',
      'Kuala Terengganu': 'KT',
    };
    final alias = aliases[region];
    if (alias != null) return alias;
    if (region.length <= 10) return region;
    if (region.contains('/')) {
      return region
          .split('/')
          .map((part) => _abbreviatePlace(part.trim()))
          .join('/');
    }
    return _abbreviatePlace(region);
  }

  String _abbreviatePlace(String value) {
    final words = value
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();
    if (words.length >= 2) {
      final abbreviation = words.map((word) => word[0].toUpperCase()).join();
      return abbreviation.length <= 4
          ? abbreviation
          : abbreviation.substring(0, 4);
    }
    return value.length <= 10 ? value : value.substring(0, 10);
  }

  bool get _isInMalaysia {
    final inPeninsular =
        latitude >= 0.8 &&
        latitude <= 7.5 &&
        longitude >= 99.0 &&
        longitude <= 104.8;
    final inBorneo =
        latitude >= 0.5 &&
        latitude <= 7.8 &&
        longitude >= 108.0 &&
        longitude <= 119.5;
    return inPeninsular || inBorneo;
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
      locationName: json['location_name']?.toString(),
      summaryForecast: json['summary_forecast']?.toString(),
      summaryWhen: json['summary_when']?.toString(),
      minTemperatureCelsius: double.tryParse(
        json['min_temperature_celsius']?.toString() ?? '',
      ),
      maxTemperatureCelsius: double.tryParse(
        json['max_temperature_celsius']?.toString() ?? '',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'temperature_celsius': temperatureCelsius,
    'weather_code': weatherCode,
    'is_day': isDay,
    'latitude': latitude,
    'longitude': longitude,
    'fetched_at': fetchedAt.toIso8601String(),
    'location_name': locationName,
    'summary_forecast': summaryForecast,
    'summary_when': summaryWhen,
    'min_temperature_celsius': minTemperatureCelsius,
    'max_temperature_celsius': maxTemperatureCelsius,
  };
}
