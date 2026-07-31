import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fyp/background/inactivity_monitor.dart';
import 'package:fyp/background/platform_background_scheduler.dart';
import 'package:fyp/background/scheduler.dart';
import 'package:fyp/dataAccessLayer/repositories/auth_repository.dart';
import 'package:fyp/dataAccessLayer/repositories/contact_repository.dart';
import 'package:fyp/dataAccessLayer/repositories/document_repository.dart';
import 'package:fyp/dataAccessLayer/repositories/reward_repository.dart';
import 'package:fyp/dataAccessLayer/repositories/user_repository.dart';
import 'package:fyp/models/ai_chat_message.dart';
import 'package:fyp/models/document_model.dart';
import 'package:fyp/models/legacy_note_model.dart';
import 'package:fyp/models/location_model.dart';
import 'package:fyp/models/reward_model.dart';
import 'package:fyp/presentation/screen/admin/admin_reward_editor_screen.dart';
import 'package:fyp/services/ai_chat_history_service.dart';
import 'package:fyp/services/background_service.dart';
import 'package:fyp/services/contact_service.dart';
import 'package:fyp/services/document_service.dart';
import 'package:fyp/services/inactivity_service.dart';
import 'package:fyp/services/local_cache_service.dart';
import 'package:fyp/services/location_service.dart';
import 'package:fyp/services/notification_service.dart';
import 'package:fyp/services/onboarding_service.dart';
import 'package:fyp/services/oren_care_service.dart';
import 'package:fyp/services/reward_service.dart';
import 'package:fyp/services/reward_admin_service.dart';
import 'package:fyp/services/user_service.dart';
import 'package:fyp/services/weather_service.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockContactRepository extends Mock implements ContactRepository {}

class _MockDocumentRepository extends Mock implements DocumentRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockRewardRepository extends Mock implements RewardRepository {}

class _MockRewardAdminService extends Mock implements RewardAdminService {}

class _MockCache extends Mock implements LocalCacheService {}

class _MockUser extends Mock implements User {}

class _MockScheduler extends Mock implements AppScheduler {}

class _MockMonitor extends Mock implements InactivityMonitor {}

class _MockPlatformScheduler extends Mock
    implements PlatformBackgroundScheduler {}

class _MockInactivityService extends Mock implements InactivityService {}

class _MockNotificationService extends Mock implements NotificationService {}

class _MockLocationService extends Mock implements LocationService {}

class _MockUserService extends Mock implements UserService {}

class _MockPosition extends Mock implements Position {}

class _FakeLegacyNote extends Fake implements LegacyNote {}

void main() {
  late _MockAuthRepository auth;
  late _MockUser user;

  setUpAll(() {
    registerFallbackValue(_FakeLegacyNote());
  });

  setUp(() {
    auth = _MockAuthRepository();
    user = _MockUser();
    when(() => user.id).thenReturn('user-1');
    when(() => user.email).thenReturn('kai@example.com');
    when(() => auth.currentUser).thenReturn(user);
  });

  group('ContactService', () {
    test('returns cached contacts without querying the repository', () async {
      final contacts = _MockContactRepository();
      final cache = _MockCache();
      when(() => cache.readMap('contacts_snapshot_v1_user-1')).thenAnswer(
        (_) async => {
          'rows': [
            {'id': 'contact-1', 'name': 'Jerome', 'is_primary': true},
          ],
        },
      );

      final rows = await ContactService(
        authRepository: auth,
        contactRepository: contacts,
        cache: cache,
      ).getContacts();

      expect(rows.single['name'], 'Jerome');
      verifyNever(() => contacts.getContacts(any()));
    });

    test('force refresh queries and caches current contacts', () async {
      final contacts = _MockContactRepository();
      final cache = _MockCache();
      when(() => contacts.getContacts('user-1')).thenAnswer(
        (_) async => [
          {'id': 'contact-2', 'name': 'Primary'},
        ],
      );
      when(() => cache.writeMap(any(), any())).thenAnswer((_) async {});

      final rows = await ContactService(
        authRepository: auth,
        contactRepository: contacts,
        cache: cache,
      ).getContacts(forceRefresh: true);

      expect(rows.single['id'], 'contact-2');
      verify(
        () => cache.writeMap('contacts_snapshot_v1_user-1', {'rows': rows}),
      ).called(1);
    });

    test(
      'checks the repository when cached contacts have no primary',
      () async {
        final contacts = _MockContactRepository();
        final cache = _MockCache();
        when(() => cache.readMap(any())).thenAnswer(
          (_) async => {
            'rows': [
              {'id': 'contact-1', 'is_primary': false},
            ],
          },
        );
        when(
          () => contacts.hasPrimaryContact('user-1'),
        ).thenAnswer((_) async => true);

        final result = await ContactService(
          authRepository: auth,
          contactRepository: contacts,
          cache: cache,
        ).hasPrimaryContact();

        expect(result, isTrue);
        verify(() => contacts.hasPrimaryContact('user-1')).called(1);
      },
    );

    test('adding a contact refreshes the cached list', () async {
      final contacts = _MockContactRepository();
      final cache = _MockCache();
      when(
        () => contacts.addContact(
          userId: 'user-1',
          name: 'Jerome',
          phone: '+60123456789',
          email: 'jerome@example.com',
          relationship: 'Friend',
          address: null,
          addressState: null,
          addressRegion: null,
          isPrimary: true,
        ),
      ).thenAnswer((_) async {});
      when(() => contacts.getContacts('user-1')).thenAnswer(
        (_) async => [
          {'id': 'contact-1', 'name': 'Jerome'},
        ],
      );
      when(() => cache.writeMap(any(), any())).thenAnswer((_) async {});

      await ContactService(
        authRepository: auth,
        contactRepository: contacts,
        cache: cache,
      ).addContact(
        name: 'Jerome',
        relationship: 'Friend',
        phone: '+60123456789',
        email: 'jerome@example.com',
        isPrimary: true,
      );

      verify(() => contacts.getContacts('user-1')).called(1);
      verify(() => cache.writeMap(any(), any())).called(1);
    });

    test(
      'updates, promotes, and deletes contacts even if cache refresh fails',
      () async {
        final contacts = _MockContactRepository();
        final cache = _MockCache();
        final row = <String, dynamic>{'id': 'contact-1'};
        when(
          () => contacts.updateContact(
            userId: 'user-1',
            row: row,
            name: 'Jerome',
            relationship: 'Friend',
            phone: '+60123456789',
            email: 'jerome@example.com',
            address: '1 Main Street',
            addressState: 'Johor',
            addressRegion: 'Johor Bahru',
            isPrimary: true,
          ),
        ).thenAnswer((_) async {});
        when(
          () => contacts.setPrimaryContact(userId: 'user-1', row: row),
        ).thenAnswer((_) async {});
        when(
          () => contacts.deleteContact(userId: 'user-1', row: row),
        ).thenAnswer((_) async {});
        when(
          () => contacts.getContacts('user-1'),
        ).thenThrow(Exception('refresh offline'));
        final service = ContactService(
          authRepository: auth,
          contactRepository: contacts,
          cache: cache,
        );

        await service.updateContact(
          row: row,
          name: 'Jerome',
          relationship: 'Friend',
          phone: '+60123456789',
          email: 'jerome@example.com',
          address: '1 Main Street',
          addressState: 'Johor',
          addressRegion: 'Johor Bahru',
          isPrimary: true,
        );
        await service.setPrimaryContact(row);
        await service.deleteContact(row);

        verify(
          () => contacts.updateContact(
            userId: 'user-1',
            row: row,
            name: 'Jerome',
            relationship: 'Friend',
            phone: '+60123456789',
            email: 'jerome@example.com',
            address: '1 Main Street',
            addressState: 'Johor',
            addressRegion: 'Johor Bahru',
            isPrimary: true,
          ),
        ).called(1);
        verify(
          () => contacts.setPrimaryContact(userId: 'user-1', row: row),
        ).called(1);
        verify(
          () => contacts.deleteContact(userId: 'user-1', row: row),
        ).called(1);
      },
    );

    test('requires authentication before loading contacts', () async {
      when(() => auth.currentUser).thenReturn(null);
      final service = ContactService(
        authRepository: auth,
        contactRepository: _MockContactRepository(),
        cache: _MockCache(),
      );

      expect(service.getContacts, throwsStateError);
    });
  });

  group('UserService', () {
    test(
      'loads a profile from the repository and supplies auth email',
      () async {
        final users = _MockUserRepository();
        final cache = _MockCache();
        when(() => cache.readMap(any())).thenAnswer((_) async => null);
        when(
          () => users.getProfile('user-1'),
        ).thenAnswer((_) async => {'name': 'Kai'});
        when(() => cache.writeMap(any(), any())).thenAnswer((_) async {});

        final profile = await UserService(
          authRepository: auth,
          userRepository: users,
          cache: cache,
        ).getCurrentProfile();

        expect(profile['name'], 'Kai');
        expect(profile['email'], 'kai@example.com');
        verify(() => cache.writeMap(any(), profile)).called(1);
      },
    );

    test('profile update forces a fresh cached snapshot', () async {
      final users = _MockUserRepository();
      final cache = _MockCache();
      when(
        () =>
            users.updateProfile(userId: 'user-1', values: {'name': 'Updated'}),
      ).thenAnswer((_) async {});
      when(
        () => users.getProfile('user-1'),
      ).thenAnswer((_) async => {'name': 'Updated'});
      when(() => cache.writeMap(any(), any())).thenAnswer((_) async {});

      await UserService(
        authRepository: auth,
        userRepository: users,
        cache: cache,
      ).updateCurrentProfile({'name': 'Updated'});

      verify(() => users.getProfile('user-1')).called(1);
      verify(() => cache.writeMap(any(), any())).called(1);
    });

    test('sign out clears user cache but preserves Oren state', () async {
      final cache = _MockCache();
      when(auth.signOut).thenAnswer((_) async {});
      when(
        () => cache.removeUserData(
          'user-1',
          preservedKeys: any(named: 'preservedKeys'),
        ),
      ).thenAnswer((_) async {});

      await UserService(
        authRepository: auth,
        userRepository: _MockUserRepository(),
        cache: cache,
      ).signOut();

      final captured =
          verify(
                () => cache.removeUserData(
                  'user-1',
                  preservedKeys: captureAny(named: 'preservedKeys'),
                ),
              ).captured.single
              as Set<String>;
      expect(captured, contains(OrenCareService.cacheKeyForUser('user-1')));
    });

    test('first-login setup preserves existing terms acceptance', () async {
      final users = _MockUserRepository();
      final cache = _MockCache();
      when(() => users.getProfile('user-1')).thenAnswer(
        (_) async => {
          'name': 'Kai',
          'terms_version': 'existing-version',
          'terms_accepted_at': '2026-07-01T00:00:00.000Z',
        },
      );
      when(
        () => users.updateProfile(
          userId: 'user-1',
          values: any(named: 'values'),
        ),
      ).thenAnswer((_) async {});
      when(() => cache.writeMap(any(), any())).thenAnswer((_) async {});

      await UserService(
        authRepository: auth,
        userRepository: users,
        cache: cache,
      ).completeFirstLoginSetup({'phone': '+60123456789'});

      final values =
          verify(
                () => users.updateProfile(
                  userId: 'user-1',
                  values: captureAny(named: 'values'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(values['terms_version'], 'existing-version');
      expect(values['terms_accepted_at'], '2026-07-01T00:00:00.000Z');
      expect(DateTime.tryParse(values['profile_completed_at']), isNotNull);
    });
  });

  group('Local account services', () {
    test(
      'chat history filters empty entries and keeps only 40 messages',
      () async {
        final cache = _MockCache();
        when(() => cache.readMap('ai_chat_history_v1_user-1')).thenAnswer(
          (_) async => {
            'messages': [
              {
                'role': 'user',
                'text': 'Hello',
                'created_at': DateTime.utc(2026, 8, 1).toIso8601String(),
              },
              {
                'role': 'assistant',
                'text': '  ',
                'created_at': DateTime.utc(2026, 8, 1).toIso8601String(),
              },
            ],
          },
        );
        when(() => cache.writeMap(any(), any())).thenAnswer((_) async {});
        final service = AiChatHistoryService(
          authRepository: auth,
          cache: cache,
        );

        final loaded = await service.load();
        await service.save(
          List.generate(45, (index) => AiChatMessage.user('Message $index')),
        );

        expect(loaded.map((message) => message.text), ['Hello']);
        final saved =
            verify(() => cache.writeMap(any(), captureAny())).captured.single
                as Map<String, dynamic>;
        expect((saved['messages'] as List), hasLength(40));
        expect((saved['messages'] as List).first['text'], 'Message 5');
      },
    );

    test('onboarding is complete for guests and persists for users', () async {
      final cache = _MockCache();
      when(() => auth.currentUser).thenReturn(null);
      final guestService = OnboardingService(
        authRepository: auth,
        cache: cache,
      );
      expect(await guestService.hasCompletedTutorial(), isTrue);

      when(() => auth.currentUser).thenReturn(user);
      when(
        () => cache.readMap(any()),
      ).thenAnswer((_) async => {'completed': false});
      when(() => cache.writeMap(any(), any())).thenAnswer((_) async {});
      final userService = OnboardingService(authRepository: auth, cache: cache);
      expect(await userService.hasCompletedTutorial(), isFalse);
      await userService.markTutorialComplete();
      verify(() => cache.writeMap(any(), any())).called(1);
    });
  });

  group('Background orchestration', () {
    test('background service initializes all workers in order', () async {
      final scheduler = _MockScheduler();
      final monitor = _MockMonitor();
      final platform = _MockPlatformScheduler();
      when(scheduler.initializeDailyTasks).thenAnswer((_) async {});
      when(platform.initialize).thenAnswer((_) async {});
      when(monitor.checkNow).thenAnswer((_) async {});

      await BackgroundService(
        scheduler: scheduler,
        inactivityMonitor: monitor,
        platformBackgroundScheduler: platform,
      ).initialize();

      verifyInOrder([
        scheduler.initializeDailyTasks,
        platform.initialize,
        monitor.checkNow,
      ]);
    });

    test('monitor delegates to inactivity service', () async {
      final inactivity = _MockInactivityService();
      when(inactivity.checkInactivity).thenAnswer((_) async {});

      await InactivityMonitor(inactivityService: inactivity).checkNow();

      verify(inactivity.checkInactivity).called(1);
    });

    test(
      'scheduler initializes notifications and cancels old daily job',
      () async {
        final notifications = _MockNotificationService();
        when(notifications.initialize).thenAnswer((_) async {});
        when(notifications.cancelDailyCheckInReminder).thenAnswer((_) async {});

        await AppScheduler(
          notificationService: notifications,
        ).initializeDailyTasks();

        verifyInOrder([
          notifications.initialize,
          notifications.cancelDailyCheckInReminder,
        ]);
      },
    );
  });

  group('DocumentService', () {
    final createdAt = DateTime.utc(2026, 8, 1);
    final preferences = const FuneralPreferences(
      religion: 'Buddhism',
      serviceType: 'Cremation',
      authorizedContact: 'contact-1',
    );

    test('loads the complete legacy planning snapshot', () async {
      final documents = _MockDocumentRepository();
      final document = LegacyDocument(
        id: 'document-1',
        name: 'will.pdf',
        storagePath: 'user-1/will.pdf',
        uploadedAt: createdAt,
      );
      final note = LegacyNote(
        id: 'note-1',
        title: 'Message',
        content: 'Thank you.',
        createdAt: createdAt,
        updatedAt: createdAt,
      );
      when(
        () => documents.getPreferences('user-1'),
      ).thenAnswer((_) async => preferences);
      when(
        () => documents.getDocuments('user-1'),
      ).thenAnswer((_) async => [document]);
      when(() => documents.getNotes('user-1')).thenAnswer((_) async => [note]);
      when(
        () => documents.getLegacyAccessEnabled('user-1'),
      ).thenAnswer((_) async => true);
      when(
        () => documents.getLegacyTestingAccessEnabled('user-1'),
      ).thenAnswer((_) async => false);

      final snapshot = await DocumentService(
        authRepository: auth,
        documentRepository: documents,
        cache: _MockCache(),
      ).load();

      expect(snapshot.preferences.religion, 'Buddhism');
      expect(snapshot.documents.single.id, 'document-1');
      expect(snapshot.notes.single.id, 'note-1');
      expect(snapshot.legacyAccessEnabled, isTrue);
      expect(snapshot.legacyTestingAccessEnabled, isFalse);
    });

    test('saves access settings and funeral preferences', () async {
      final documents = _MockDocumentRepository();
      when(
        () => documents.setLegacyAccessEnabled(enabled: true),
      ).thenAnswer((_) async {});
      when(
        () => documents.setLegacyTestingAccessEnabled(enabled: true),
      ).thenAnswer((_) async {});
      when(
        () => documents.savePreferences('user-1', preferences),
      ).thenAnswer((_) async {});
      final service = DocumentService(
        authRepository: auth,
        documentRepository: documents,
        cache: _MockCache(),
      );

      await service.setLegacyAccessEnabled(true);
      await service.setLegacyTestingAccessEnabled(true);
      await service.savePreferences(preferences);

      verify(() => documents.setLegacyAccessEnabled(enabled: true)).called(1);
      verify(
        () => documents.setLegacyTestingAccessEnabled(enabled: true),
      ).called(1);
      verify(() => documents.savePreferences('user-1', preferences)).called(1);
    });

    test('trims valid notes and rejects credential content', () async {
      final documents = _MockDocumentRepository();
      when(
        () => documents.createNote(
          userId: 'user-1',
          title: 'Message',
          content: 'A safe personal note.',
        ),
      ).thenAnswer((_) async {});
      final service = DocumentService(
        authRepository: auth,
        documentRepository: documents,
        cache: _MockCache(),
      );

      await service.createNote(
        title: '  Message  ',
        content: '  A safe personal note.  ',
      );

      verify(
        () => documents.createNote(
          userId: 'user-1',
          title: 'Message',
          content: 'A safe personal note.',
        ),
      ).called(1);
      expect(
        () => service.createNote(
          title: 'Account',
          content: 'My password is secret123!',
        ),
        throwsStateError,
      );
    });

    test('updates and deletes an owned note and document', () async {
      final documents = _MockDocumentRepository();
      final note = LegacyNote(
        id: 'note-1',
        title: '  Message  ',
        content: '  Please remember me.  ',
        createdAt: createdAt,
        updatedAt: createdAt,
      );
      final document = LegacyDocument(
        id: 'document-1',
        name: 'will.pdf',
        storagePath: 'user-1/will.pdf',
        uploadedAt: createdAt,
      );
      when(
        () => documents.updateNote(
          userId: 'user-1',
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => documents.deleteNote(userId: 'user-1', noteId: 'note-1'),
      ).thenAnswer((_) async {});
      when(
        () => documents.deleteDocument(
          userId: 'user-1',
          id: 'document-1',
          storagePath: 'user-1/will.pdf',
        ),
      ).thenAnswer((_) async {});
      final service = DocumentService(
        authRepository: auth,
        documentRepository: documents,
        cache: _MockCache(),
      );

      await service.updateNote(note);
      await service.deleteNote(note);
      await service.deleteDocument(document);

      final savedNote =
          verify(
                () => documents.updateNote(
                  userId: 'user-1',
                  note: captureAny(named: 'note'),
                ),
              ).captured.single
              as LegacyNote;
      expect(savedNote.title, 'Message');
      expect(savedNote.content, 'Please remember me.');
      verify(
        () => documents.deleteDocument(
          userId: 'user-1',
          id: 'document-1',
          storagePath: 'user-1/will.pdf',
        ),
      ).called(1);
    });

    test('rejects document paths outside the signed-in user folder', () async {
      final service = DocumentService(
        authRepository: auth,
        documentRepository: _MockDocumentRepository(),
        cache: _MockCache(),
      );
      final document = LegacyDocument(
        id: 'document-1',
        name: 'will.pdf',
        storagePath: 'another-user/will.pdf',
        uploadedAt: createdAt,
      );

      expect(() => service.deleteDocument(document), throwsStateError);
    });
  });

  group('WeatherService', () {
    final now = DateTime.utc(2026, 8, 1, 10);

    test('uses a fresh location-scoped cached forecast', () async {
      final cache = _MockCache();
      final users = _MockUserService();
      final cached = WeatherSnapshot(
        temperatureCelsius: 29,
        weatherCode: 3,
        isDay: true,
        latitude: 1.49,
        longitude: 103.74,
        fetchedAt: now.subtract(const Duration(minutes: 10)),
        locationName: 'Johor Bahru',
      );
      when(() => users.getCurrentProfile()).thenAnswer(
        (_) async => {
          'address_state': 'Johor',
          'address_region': 'Johor Bahru',
        },
      );
      when(
        () => cache.readMap('weather_current_malaysia_v3_johor_johor_bahru'),
      ).thenAnswer((_) async => cached.toJson());
      var requestCount = 0;

      final result = await WeatherService(
        cache: cache,
        locationService: _MockLocationService(),
        userService: users,
        client: MockClient((_) async {
          requestCount++;
          return http.Response('{}', 500);
        }),
        now: () => now,
      ).getCurrentWeather();

      expect(result?.locationName, 'Johor Bahru');
      expect(requestCount, 0);
    });

    test(
      'maps the Malaysia government forecast for the profile region',
      () async {
        final cache = _MockCache();
        final users = _MockUserService();
        when(() => users.getCurrentProfile()).thenAnswer(
          (_) async => {
            'address_state': 'Johor',
            'address_region': 'Johor Bahru',
          },
        );
        when(() => cache.readMap(any())).thenAnswer((_) async => null);
        when(() => cache.writeMap(any(), any())).thenAnswer((_) async {});
        final client = MockClient((request) async {
          expect(request.url.host, 'api.data.gov.my');
          return http.Response('''[
            {
              "location": {
                "location_id": "Ds001",
                "location_name": "Johor Bahru"
              },
              "min_temp": 25,
              "max_temp": 33,
              "morning_forecast": "Berawan",
              "afternoon_forecast": "Ribut petir",
              "night_forecast": "Hujan"
            }
          ]''', 200);
        });

        final result = await WeatherService(
          cache: cache,
          locationService: _MockLocationService(),
          userService: users,
          client: client,
          now: () => now,
        ).getCurrentWeather(forceRefresh: true);

        expect(result?.locationName, 'Johor Bahru');
        expect(result?.weatherCode, 3);
        expect(result?.summaryForecast, 'Berawan');
        expect(result?.summaryWhen, 'Morning');
        expect(result?.temperatureCelsius, 33);
        expect(result?.isCloudy, isTrue);
        verify(() => cache.writeMap(any(), any())).called(1);
      },
    );

    test('falls back to Open-Meteo without a profile region', () async {
      final cache = _MockCache();
      final users = _MockUserService();
      final locations = _MockLocationService();
      final position = _MockPosition();
      when(users.getCurrentProfile).thenAnswer((_) async => {});
      when(() => cache.readMap(any())).thenAnswer((_) async => null);
      when(() => cache.writeMap(any(), any())).thenAnswer((_) async {});
      when(
        locations.getBestAvailablePosition,
      ).thenAnswer((_) async => position);
      when(() => position.latitude).thenReturn(3.139);
      when(() => position.longitude).thenReturn(101.6869);
      final client = MockClient((request) async {
        expect(request.url.host, 'api.open-meteo.com');
        return http.Response(
          '{"current":{"temperature_2m":31.5,"weather_code":0,"is_day":1}}',
          200,
        );
      });

      final result = await WeatherService(
        cache: cache,
        locationService: locations,
        userService: users,
        client: client,
        now: () => now,
      ).getCurrentWeather(forceRefresh: true);

      expect(result?.temperatureCelsius, 31.5);
      expect(result?.weatherCode, 0);
      expect(result?.isDay, isTrue);
      expect(result?.malaysiaRegion, 'Klang Valley');
    });

    test('returns stale cache when both weather sources fail', () async {
      final cache = _MockCache();
      final users = _MockUserService();
      final locations = _MockLocationService();
      final stale = WeatherSnapshot(
        temperatureCelsius: 28,
        weatherCode: 61,
        isDay: true,
        latitude: 3.139,
        longitude: 101.6869,
        fetchedAt: now.subtract(const Duration(hours: 1)),
      );
      when(users.getCurrentProfile).thenAnswer((_) async => {});
      when(() => cache.readMap(any())).thenAnswer((_) async => stale.toJson());
      when(locations.getBestAvailablePosition).thenAnswer((_) async => null);

      final result = await WeatherService(
        cache: cache,
        locationService: locations,
        userService: users,
        client: MockClient((_) async => http.Response('{}', 500)),
        now: () => now,
      ).getCurrentWeather(forceRefresh: true);

      expect(result?.weatherCode, 61);
      expect(result?.isRainy, isTrue);
    });
  });

  group('WeatherSnapshot presentation', () {
    WeatherSnapshot snapshot(double latitude, double longitude) {
      return WeatherSnapshot(
        temperatureCelsius: 30,
        weatherCode: 0,
        isDay: true,
        latitude: latitude,
        longitude: longitude,
        fetchedAt: DateTime.utc(2026, 8, 1),
      );
    }

    test('identifies Malaysian regions from coordinates', () {
      expect(snapshot(6.2, 100.4).malaysiaRegion, 'Kedah / Perlis');
      expect(snapshot(5.4, 100.3).malaysiaRegion, 'Penang');
      expect(snapshot(4.5, 101.0).malaysiaRegion, 'Perak');
      expect(snapshot(3.1, 101.6).malaysiaRegion, 'Klang Valley');
      expect(snapshot(2.2, 102.5).malaysiaRegion, 'Melaka / Johor');
      expect(snapshot(1.5, 103.7).malaysiaRegion, 'Johor');
      expect(snapshot(2.5, 103.3).malaysiaRegion, 'Negeri Sembilan / Pahang');
      expect(snapshot(3.5, 103.0).malaysiaRegion, 'Pahang');
      expect(snapshot(4.2, 103.0).malaysiaRegion, 'Terengganu');
      expect(snapshot(5.0, 102.5).malaysiaRegion, 'Kelantan');
      expect(snapshot(2.0, 110.0).malaysiaRegion, 'Sarawak');
      expect(snapshot(5.0, 116.0).malaysiaRegion, 'Sabah / Labuan');
      expect(snapshot(3.0, 100.0).malaysiaRegion, 'Malaysia');
      expect(snapshot(40.0, -73.0).malaysiaRegion, 'Current location');
    });

    test('uses compact aliases and weather-specific descriptions', () {
      final cloudy = WeatherSnapshot(
        temperatureCelsius: 29,
        weatherCode: 3,
        isDay: true,
        latitude: 1.49,
        longitude: 103.74,
        fetchedAt: DateTime.utc(2026, 8, 1),
        locationName: 'Johor Bahru, Johor',
        summaryForecast: 'Berawan',
      );
      final foggy = WeatherSnapshot(
        temperatureCelsius: 24,
        weatherCode: 45,
        isDay: true,
        latitude: 0,
        longitude: 0,
        fetchedAt: DateTime.utc(2026, 8, 1),
      );
      final rainy = WeatherSnapshot(
        temperatureCelsius: 27,
        weatherCode: 95,
        isDay: false,
        latitude: 0,
        longitude: 0,
        fetchedAt: DateTime.utc(2026, 8, 1),
      );

      expect(cloudy.compactMalaysiaRegion, 'JB');
      expect(cloudy.description, 'Berawan');
      expect(cloudy.backgroundAsset, contains('pixel_cloudy.png'));
      expect(foggy.description, 'Foggy');
      expect(rainy.description, 'Rainy');
      expect(rainy.backgroundAsset, contains('pixel_raining.png'));
    });
  });

  group('RewardService', () {
    test('signed-out users receive the local reward catalog', () async {
      when(() => auth.currentUser).thenReturn(null);

      final snapshot = await RewardService(
        authRepository: auth,
        rewardRepository: _MockRewardRepository(),
        cache: _MockCache(),
      ).synchronize();

      expect(snapshot.catalog, RewardService.fallbackCatalog);
      expect(snapshot.earnedCodes, isEmpty);
    });

    test(
      'synchronizes catalog, badge claim, and voucher redeem code',
      () async {
        final rewards = _MockRewardRepository();
        final cache = _MockCache();
        when(() => cache.readMap(any())).thenAnswer((_) async => null);
        when(rewards.getLatestCatalogVersion).thenAnswer((_) async => 7);
        when(rewards.getActiveCatalog).thenAnswer(
          (_) async => [
            {
              'code': 'badge-1',
              'title': 'Badge One',
              'description': 'Badge',
              'milestone_days': 3,
              'reward_kind': 'virtual',
              'catalog_version': 7,
            },
            {
              'code': 'voucher-1',
              'title': 'Voucher One',
              'description': 'Voucher',
              'milestone_days': 5,
              'reward_kind': 'voucher',
              'catalog_version': 7,
              'voucher_value': 'RM5',
            },
          ],
        );
        when(rewards.synchronizeEarnedRewards).thenAnswer((_) async {});
        when(() => rewards.getEarnedRewards('user-1')).thenAnswer(
          (_) async => [
            {'reward_code': 'badge-1', 'status': 'claimed'},
            {
              'reward_code': 'voucher-1',
              'status': 'earned',
              'redeem_code': 'EC-123456',
            },
          ],
        );
        when(() => cache.writeMap(any(), any())).thenAnswer((_) async {});

        final snapshot = await RewardService(
          authRepository: auth,
          rewardRepository: rewards,
          cache: cache,
        ).synchronize(forceCatalogRefresh: true);

        expect(snapshot.catalogVersion, 7);
        expect(snapshot.earnedCodes, {'badge-1', 'voucher-1'});
        expect(snapshot.isBadgeClaimed('badge-1'), isTrue);
        expect(snapshot.redemptionCodeFor('voucher-1'), 'EC-123456');
        expect(snapshot.nextReward(3), isNull);
        verify(() => cache.writeMap(any(), any())).called(1);
      },
    );

    test('keeps cached rewards when the backend is unavailable', () async {
      final rewards = _MockRewardRepository();
      final cache = _MockCache();
      final cached = RewardSnapshot(
        catalog: RewardService.fallbackCatalog,
        earnedCodes: const {'oren_sprout_badge'},
        catalogVersion: RewardService.fallbackCatalogVersion,
        syncedAt: DateTime.utc(2026, 8, 1),
      );
      when(() => cache.readMap(any())).thenAnswer((_) async => cached.toJson());
      when(rewards.getLatestCatalogVersion).thenThrow(Exception('offline'));
      when(rewards.synchronizeEarnedRewards).thenThrow(Exception('offline'));

      final snapshot = await RewardService(
        authRepository: auth,
        rewardRepository: rewards,
        cache: cache,
      ).synchronize();

      expect(snapshot.earnedCodes, contains('oren_sprout_badge'));
      expect(snapshot.catalogVersion, RewardService.fallbackCatalogVersion);
    });
  });

  group('Admin reward editor', () {
    testWidgets('shows complete validation before a new reward is saved', (
      tester,
    ) async {
      final admin = _MockRewardAdminService();
      await tester.pumpWidget(
        MaterialApp(home: AdminRewardEditorScreen(adminService: admin)),
      );

      await tester.ensureVisible(find.text('Create Reward'));
      await tester.tap(find.text('Create Reward'));
      await tester.pump();

      expect(
        find.text('Use 3-50 lowercase letters, numbers, or underscores.'),
        findsOneWidget,
      );
      expect(find.text('Title must contain 2-80 characters.'), findsOneWidget);
      expect(
        find.text('Description must contain 5-240 characters.'),
        findsOneWidget,
      );
      expect(
        find.text('Enter a milestone from 1 to 365 days.'),
        findsOneWidget,
      );
      verifyNever(
        () => admin.saveReward(
          code: any(named: 'code'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          milestoneDays: any(named: 'milestoneDays'),
          active: any(named: 'active'),
          rewardKind: any(named: 'rewardKind'),
          voucherValue: any(named: 'voucherValue'),
        ),
      );
    });

    testWidgets('saves a valid edited voucher and closes the page', (
      tester,
    ) async {
      final admin = _MockRewardAdminService();
      const voucher = RewardCatalogItem(
        code: 'care_voucher',
        title: 'Care Voucher',
        sponsor: 'EthernaCare',
        description: 'A virtual voucher for consistent check-ins.',
        milestoneDays: 7,
        rewardKind: 'voucher',
        catalogVersion: 2,
        voucherValue: 'RM5',
      );
      when(
        () => admin.saveReward(
          code: 'care_voucher',
          title: 'Care Voucher',
          description: 'A virtual voucher for consistent check-ins.',
          milestoneDays: 7,
          active: true,
          rewardKind: 'voucher',
          voucherValue: 'RM5',
        ),
      ).thenAnswer((_) async => voucher);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AdminRewardEditorScreen(
                    adminService: admin,
                    reward: voucher,
                  ),
                ),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Virtual Reward'), findsOneWidget);
      expect(find.text('Voucher value or offer'), findsOneWidget);
      final codeField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'care_voucher'),
      );
      expect(codeField.enabled, isFalse);
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      verify(
        () => admin.saveReward(
          code: 'care_voucher',
          title: 'Care Voucher',
          description: 'A virtual voucher for consistent check-ins.',
          milestoneDays: 7,
          active: true,
          rewardKind: 'voucher',
          voucherValue: 'RM5',
        ),
      ).called(1);
      expect(find.text('Open editor'), findsOneWidget);
    });
  });
}
