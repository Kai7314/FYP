import 'package:flutter_test/flutter_test.dart';
import 'package:fyp/services/home_address_service.dart';

void main() {
  group('HomeAddressService', () {
    test('accepts an address matched to its Malaysian state and region', () async {
      String? requestedQuery;
      final verifiedAt = DateTime.utc(2026, 8, 5, 4, 30);
      final service = HomeAddressService(
        clock: () => verifiedAt,
        lookup: (query) async {
          requestedQuery = query;
          return const [
            HomeAddressCandidate(
              latitude: 1.4927,
              longitude: 103.7414,
              countryCode: 'MY',
              administrativeArea: 'Johor',
              regionParts: ['Johor Bahru District', 'Johor Bahru'],
              addressParts: ['12 Jalan Sutera 1'],
            ),
          ];
        },
      );

      final result = await service.validate(
        address: '  12 Jalan Sutera 1  ',
        state: 'Johor',
        region: 'Johor Bahru',
      );

      expect(
        requestedQuery,
        '12 Jalan Sutera 1, Johor Bahru, Johor, Malaysia',
      );
      expect(result.address, '12 Jalan Sutera 1');
      expect(result.latitude, 1.4927);
      expect(result.longitude, 103.7414);
      expect(result.verifiedAt, verifiedAt);
      expect(result.toProfileValues(), containsPair('address_state', 'Johor'));
      expect(
        result.toProfileValues(),
        containsPair('address_validation_provider', 'platform_geocoder'),
      );
    });

    test('rejects a result outside the selected state and region', () async {
      final service = HomeAddressService(
        lookup: (_) async => const [
          HomeAddressCandidate(
            latitude: 3.139,
            longitude: 101.6869,
            countryCode: 'MY',
            administrativeArea: 'Kuala Lumpur',
            regionParts: ['Kuala Lumpur'],
            addressParts: ['12 Jalan Sutera 1'],
          ),
        ],
      );

      expect(
        () => service.validate(
          address: '12 Jalan Sutera 1',
          state: 'Johor',
          region: 'Johor Bahru',
        ),
        throwsA(isA<HomeAddressValidationException>()),
      );
    });

    test('rejects a result outside Malaysia', () async {
      final service = HomeAddressService(
        lookup: (_) async => const [
          HomeAddressCandidate(
            latitude: 1.3521,
            longitude: 103.8198,
            countryCode: 'SG',
            administrativeArea: 'Johor',
            regionParts: ['Johor Bahru'],
            addressParts: ['12 Jalan Sutera 1'],
          ),
        ],
      );

      expect(
        () => service.validate(
          address: '12 Jalan Sutera 1',
          state: 'Johor',
          region: 'Johor Bahru',
        ),
        throwsA(isA<HomeAddressValidationException>()),
      );
    });

    test('rejects an incomplete numeric address before geocoding', () async {
      var lookupCalled = false;
      final service = HomeAddressService(
        lookup: (_) async {
          lookupCalled = true;
          return const [];
        },
      );

      await expectLater(
        service.validate(address: '42', state: 'Johor', region: 'Johor Bahru'),
        throwsA(
          isA<HomeAddressValidationException>().having(
            (error) => error.message,
            'message',
            contains('complete address'),
          ),
        ),
      );
      expect(lookupCalled, isFalse);
    });

    test('rejects a district fallback that does not match the address', () async {
      final service = HomeAddressService(
        lookup: (_) async => const [
          HomeAddressCandidate(
            latitude: 1.4927,
            longitude: 103.7414,
            countryCode: 'MY',
            administrativeArea: 'Johor',
            regionParts: ['Johor Bahru District', 'Johor Bahru'],
            addressParts: ['25 Jalan Wong Ah Fook'],
          ),
        ],
      );

      await expectLater(
        service.validate(
          address: '12 Jalan Sutera 1',
          state: 'Johor',
          region: 'Johor Bahru',
        ),
        throwsA(isA<HomeAddressValidationException>()),
      );
    });

    test('restores only complete verified profile values', () {
      final profile = {
        'address': '12 Jalan Sutera 1',
        'address_state': 'Johor',
        'address_region': 'Johor Bahru',
        'address_latitude': 1.4927,
        'address_longitude': 103.7414,
        'address_verified_at': '2026-08-05T04:30:00.000Z',
        'address_validation_provider': 'platform_geocoder',
      };

      expect(HomeAddressService.fromProfile(profile), isNotNull);
      expect(
        HomeAddressService.fromProfile({...profile}..remove('address_latitude')),
        isNull,
      );
      expect(
        HomeAddressService.fromProfile({...profile, 'address': '42'}),
        isNull,
      );
    });
  });
}
