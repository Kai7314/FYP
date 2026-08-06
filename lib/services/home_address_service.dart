import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

import '../utils/validators.dart';

class HomeAddressValidationException implements Exception {
  const HomeAddressValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HomeAddressCandidate {
  const HomeAddressCandidate({
    required this.latitude,
    required this.longitude,
    required this.countryCode,
    required this.administrativeArea,
    required this.regionParts,
    required this.addressParts,
  });

  final double latitude;
  final double longitude;
  final String countryCode;
  final String administrativeArea;
  final List<String> regionParts;
  final List<String> addressParts;
}

class HomeAddressValidationResult {
  const HomeAddressValidationResult({
    required this.address,
    required this.state,
    required this.region,
    required this.latitude,
    required this.longitude,
    required this.verifiedAt,
  });

  final String address;
  final String state;
  final String region;
  final double latitude;
  final double longitude;
  final DateTime verifiedAt;

  Map<String, dynamic> toProfileValues() => {
    'address': address,
    'address_state': state,
    'address_region': region,
    'address_latitude': latitude,
    'address_longitude': longitude,
    'address_verified_at': verifiedAt.toUtc().toIso8601String(),
    'address_validation_provider': 'platform_geocoder',
  };
}

typedef HomeAddressLookup =
    Future<List<HomeAddressCandidate>> Function(String query);

class HomeAddressService {
  HomeAddressService({HomeAddressLookup? lookup, DateTime Function()? clock})
    : _lookup = lookup ?? _platformLookup,
      _clock = clock ?? DateTime.now;

  final HomeAddressLookup _lookup;
  final DateTime Function() _clock;

  static HomeAddressValidationResult? fromProfile(
    Map<String, dynamic> profile,
  ) {
    final address = AppValidators.normalizeSpaces(
      profile['address']?.toString() ?? '',
    );
    final state = profile['address_state']?.toString().trim() ?? '';
    final region = profile['address_region']?.toString().trim() ?? '';
    final latitude = _asDouble(profile['address_latitude']);
    final longitude = _asDouble(profile['address_longitude']);
    final verifiedAt = DateTime.tryParse(
      profile['address_verified_at']?.toString() ?? '',
    );
    final provider =
        profile['address_validation_provider']?.toString().trim() ?? '';

    if (AppValidators.address(address, required: true) != null ||
        state.isEmpty ||
        region.isEmpty ||
        latitude == null ||
        longitude == null ||
        verifiedAt == null ||
        provider.isEmpty ||
        !_isInsideMalaysia(latitude, longitude)) {
      return null;
    }

    return HomeAddressValidationResult(
      address: address,
      state: state,
      region: region,
      latitude: latitude,
      longitude: longitude,
      verifiedAt: verifiedAt.toUtc(),
    );
  }

  static String signature({
    required String address,
    required String? state,
    required String? region,
  }) {
    return [
      AppValidators.normalizeSpaces(address).toLowerCase(),
      state?.trim().toLowerCase() ?? '',
      region?.trim().toLowerCase() ?? '',
    ].join('|');
  }

  Future<HomeAddressValidationResult> validate({
    required String address,
    required String? state,
    required String? region,
  }) async {
    final normalizedAddress = AppValidators.normalizeSpaces(address);
    final normalizedState = state?.trim() ?? '';
    final normalizedRegion = region?.trim() ?? '';
    final addressError = AppValidators.address(
      normalizedAddress,
      required: true,
    );
    if (addressError != null) {
      throw HomeAddressValidationException(addressError);
    }
    if (normalizedState.isEmpty || normalizedRegion.isEmpty) {
      throw const HomeAddressValidationException(
        'Select the state and region before validating the address.',
      );
    }

    final query = [
      normalizedAddress,
      normalizedRegion,
      normalizedState,
      'Malaysia',
    ].join(', ');
    final candidates = await _lookup(query);
    final valid = candidates.where((candidate) {
      return _isInsideMalaysia(candidate.latitude, candidate.longitude) &&
          candidate.countryCode.trim().toUpperCase() == 'MY' &&
          _looselyMatches(candidate.administrativeArea, normalizedState) &&
          candidate.regionParts.any(
            (part) => _looselyMatches(part, normalizedRegion),
          ) &&
          _matchesAddress(normalizedAddress, candidate.addressParts);
    }).toList();
    if (valid.isEmpty) {
      throw const HomeAddressValidationException(
        'This address could not be matched to the selected Malaysian state and region. Check the house, street, state, and district.',
      );
    }

    final match = valid.first;
    return HomeAddressValidationResult(
      address: normalizedAddress,
      state: normalizedState,
      region: normalizedRegion,
      latitude: match.latitude,
      longitude: match.longitude,
      verifiedAt: _clock().toUtc(),
    );
  }

  static Future<List<HomeAddressCandidate>> _platformLookup(
    String query,
  ) async {
    if (kIsWeb ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        }.contains(defaultTargetPlatform)) {
      throw const HomeAddressValidationException(
        'Address validation is available in the Android, iOS, or macOS app.',
      );
    }

    try {
      final platformGeocoder = geocoding.Geocoding();
      final locations = await platformGeocoder.locationFromAddress(query);
      final candidates = <HomeAddressCandidate>[];
      for (final location in locations.take(3)) {
        final placemarks = await platformGeocoder.placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );
        if (placemarks.isEmpty) continue;
        final placemark = placemarks.first;
        candidates.add(
          HomeAddressCandidate(
            latitude: location.latitude,
            longitude: location.longitude,
            countryCode: placemark.isoCountryCode ?? '',
            administrativeArea: placemark.administrativeArea ?? '',
            regionParts: [
              placemark.subAdministrativeArea ?? '',
              placemark.locality ?? '',
              placemark.subLocality ?? '',
            ],
            addressParts: [
              placemark.street ?? '',
              placemark.name ?? '',
              placemark.subLocality ?? '',
            ],
          ),
        );
      }
      return candidates;
    } catch (error) {
      if (error is HomeAddressValidationException) rethrow;
      throw const HomeAddressValidationException(
        'The address service is unavailable right now. Check your internet connection and try again.',
      );
    }
  }

  static bool _isInsideMalaysia(double latitude, double longitude) {
    return latitude >= 0.8 &&
        latitude <= 7.6 &&
        longitude >= 99.5 &&
        longitude <= 119.5;
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static bool _looselyMatches(String actual, String expected) {
    final actualTokens = _tokens(actual);
    final expectedTokens = _tokens(expected);
    if (actualTokens.isEmpty || expectedTokens.isEmpty) return false;
    return expectedTokens.every(actualTokens.contains) ||
        actualTokens.every(expectedTokens.contains);
  }

  static bool _matchesAddress(String expected, List<String> actualParts) {
    final expectedTokens = _specificAddressTokens(expected);
    if (expectedTokens.isEmpty) return false;
    final actualTokens = actualParts
        .expand(_specificAddressTokens)
        .toSet();
    return expectedTokens.intersection(actualTokens).isNotEmpty;
  }

  static Set<String> _specificAddressTokens(String value) {
    const genericAddressTokens = {
      'jalan',
      'jln',
      'lorong',
      'taman',
      'kampung',
      'unit',
      'nombor',
      'building',
      'bangunan',
      'road',
      'street',
      'malaysia',
    };
    return _tokens(value).where((token) {
      return token.length >= 3 &&
          int.tryParse(token) == null &&
          !genericAddressTokens.contains(token);
    }).toSet();
  }

  static Set<String> _tokens(String value) {
    const ignored = {'daerah', 'district', 'wilayah', 'persekutuan'};
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty && !ignored.contains(token))
        .toSet();
  }
}
