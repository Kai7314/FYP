import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fyp/dataAccessLayer/repositories/auth_repository.dart';
import 'package:fyp/dataAccessLayer/repositories/checkin_repository.dart';
import 'package:fyp/dataAccessLayer/repositories/contact_repository.dart';
import 'package:fyp/dataAccessLayer/repositories/emergency_repository.dart';
import 'package:fyp/dataAccessLayer/repositories/oren_care_repository.dart';
import 'package:fyp/dataAccessLayer/repositories/user_repository.dart';
import 'package:fyp/models/oren_care_model.dart';
import 'package:fyp/services/checkin_service.dart';
import 'package:fyp/services/dashboard_service.dart';
import 'package:fyp/services/direct_sms_service.dart';
import 'package:fyp/services/emergency_service.dart';
import 'package:fyp/services/inactivity_service.dart';
import 'package:fyp/services/local_cache_service.dart';
import 'package:fyp/services/location_service.dart';
import 'package:fyp/services/notification_service.dart';
import 'package:fyp/services/oren_care_service.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockCheckinRepository extends Mock implements CheckinRepository {}

class _MockEmergencyRepository extends Mock implements EmergencyRepository {}

class _MockOrenCareRepository extends Mock implements OrenCareRepository {}

class _MockContactRepository extends Mock implements ContactRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockEmergencyService extends Mock implements EmergencyService {}

class _MockNotificationService extends Mock implements NotificationService {}

class _MockLocalCacheService extends Mock implements LocalCacheService {}

class _MockDirectSmsService extends Mock implements DirectSmsService {}

class _MockLocationService extends Mock implements LocationService {}

class _MockUser extends Mock implements User {}

class _MockPosition extends Mock implements Position {}

class _MemoryCacheService extends Fake implements LocalCacheService {
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

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

void main() {
  late _MockAuthRepository authRepository;
  late _MockUser user;

  setUpAll(() {
    registerFallbackValue(DateTime.utc(2026, 8, 1));
  });

  setUp(() {
    authRepository = _MockAuthRepository();
    user = _MockUser();
    when(() => user.id).thenReturn('user-1');
    when(() => user.email).thenReturn('kai@example.com');
    when(() => authRepository.currentUser).thenReturn(user);
  });

  group('CheckinService', () {
    test('restores the newest cached check-in after the app reopens', () async {
      final cache = _MemoryCacheService();
      final older = DateTime.utc(2026, 8, 1, 8);
      final newest = DateTime.utc(2026, 8, 1, 10);
      cache.values[CheckinService.cacheKeyForUser('user-1')] = {
        'rows': [
          {'checkin_time': older.toIso8601String()},
          {'checkin_time': newest.toIso8601String()},
        ],
      };

      final restored = await CheckinService(
        authRepository: authRepository,
        checkinRepository: _MockCheckinRepository(),
        userRepository: _MockUserRepository(),
        cache: cache,
      ).getLatestCachedCheckinTime();

      expect(restored, newest);
    });

    test(
      'uses the configured rolling threshold and refreshes the cache',
      () async {
        final checkins = _MockCheckinRepository();
        final users = _MockUserRepository();
        final cache = _MockLocalCacheService();
        when(
          () => users.getProfile('user-1'),
        ).thenAnswer((_) async => {'inactivity_threshold': 1});
        when(
          () => checkins.addThresholdCheckin(
            userId: 'user-1',
            now: any(named: 'now'),
            thresholdHours: 1,
          ),
        ).thenAnswer((_) async => true);
        when(() => cache.readMap(any())).thenAnswer((_) async => null);
        when(() => cache.writeMap(any(), any())).thenAnswer((_) async {});
        when(
          () => checkins.getCheckins('user-1'),
        ).thenAnswer((_) async => <Map<String, dynamic>>[]);

        final created = await CheckinService(
          authRepository: authRepository,
          checkinRepository: checkins,
          userRepository: users,
          cache: cache,
        ).addCheckin();

        expect(created, isTrue);
        verify(
          () => checkins.addThresholdCheckin(
            userId: 'user-1',
            now: any(named: 'now'),
            thresholdHours: 1,
          ),
        ).called(1);
        verify(() => checkins.getCheckins('user-1')).called(1);
        verify(
          () => cache.writeMap(any(), any()),
        ).called(greaterThanOrEqualTo(1));
      },
    );

    test('requires an authenticated user', () async {
      when(() => authRepository.currentUser).thenReturn(null);

      final service = CheckinService(
        authRepository: authRepository,
        checkinRepository: _MockCheckinRepository(),
        userRepository: _MockUserRepository(),
        cache: _MockLocalCacheService(),
      );

      expect(service.addCheckin, throwsStateError);
    });
  });

  group('InactivityService orchestration', () {
    late _MockCheckinRepository checkins;
    late _MockUserRepository users;
    late _MockEmergencyRepository emergencies;
    late _MockEmergencyService emergencyService;
    late _MockNotificationService notifications;
    late _MockLocalCacheService cache;
    final lastCheckIn = DateTime.utc(2026, 8, 1, 8);

    setUp(() {
      checkins = _MockCheckinRepository();
      users = _MockUserRepository();
      emergencies = _MockEmergencyRepository();
      emergencyService = _MockEmergencyService();
      notifications = _MockNotificationService();
      cache = _MockLocalCacheService();
      when(() => checkins.getLatestCheckin('user-1')).thenAnswer(
        (_) async => {'checkin_time': lastCheckIn.toIso8601String()},
      );
      when(
        () => users.getProfile('user-1'),
      ).thenAnswer((_) async => {'inactivity_threshold': 1});
      when(
        () => emergencies.getLatestInactivityAlert('user-1'),
      ).thenAnswer((_) async => null);
      when(
        () => notifications.showMissedCheckInReminder(
          missedCheckIns: any(named: 'missedCheckIns'),
          requiredMissedCheckIns: any(named: 'requiredMissedCheckIns'),
        ),
      ).thenAnswer((_) async {});
      when(() => cache.writeMap(any(), any())).thenAnswer((_) async {});
    });

    InactivityService serviceAt(DateTime now) => InactivityService(
      authRepository: authRepository,
      checkinRepository: checkins,
      userRepository: users,
      emergencyRepository: emergencies,
      emergencyService: emergencyService,
      cache: cache,
      notificationService: notifications,
      clock: () => now,
    );

    test('first missed window sends only the local reminder', () async {
      when(() => cache.readMap(any())).thenAnswer((_) async => null);

      await serviceAt(
        lastCheckIn.add(const Duration(hours: 1)),
      ).checkInactivity();

      verify(
        () => notifications.showMissedCheckInReminder(
          missedCheckIns: 1,
          requiredMissedCheckIns: 3,
        ),
      ).called(1);
      verifyNever(
        () => emergencyService.sendUserInactivityReminder(
          lastCheckIn: any(named: 'lastCheckIn'),
          thresholdHours: any(named: 'thresholdHours'),
          allowDirectSms: false,
        ),
      );
      verifyNever(
        () => emergencyService.triggerEmergencyDetailed(
          allow999Dialer: false,
          sendAutomatedSms: true,
          allowDirectSms: false,
          alertStatus: 'inactivity_triggered',
        ),
      );
    });

    test('second missed window leaves SMS delivery to the server', () async {
      when(() => cache.readMap(any())).thenAnswer(
        (_) async => {
          'last_checkin_at': lastCheckIn.toIso8601String(),
          'last_notified_miss': 1,
          'escalated': false,
          'user_sms_accepted': false,
        },
      );
      await serviceAt(
        lastCheckIn.add(const Duration(hours: 2)),
      ).checkInactivity();

      verify(
        () => notifications.showMissedCheckInReminder(
          missedCheckIns: 2,
          requiredMissedCheckIns: 3,
        ),
      ).called(1);
      verifyNever(
        () => emergencyService.sendUserInactivityReminder(
          lastCheckIn: any(named: 'lastCheckIn'),
          thresholdHours: any(named: 'thresholdHours'),
          allowDirectSms: false,
        ),
      );
    });

    test(
      'third missed window leaves contact escalation to the server',
      () async {
        when(() => cache.readMap(any())).thenAnswer(
          (_) async => {
            'last_checkin_at': lastCheckIn.toIso8601String(),
            'last_notified_miss': 2,
            'escalated': false,
            'user_sms_accepted': true,
          },
        );
        await serviceAt(
          lastCheckIn.add(const Duration(hours: 3)),
        ).checkInactivity();

        verifyNever(
          () => emergencyService.triggerEmergencyDetailed(
            allow999Dialer: false,
            sendAutomatedSms: true,
            allowDirectSms: false,
            alertStatus: 'inactivity_triggered',
          ),
        );
        verify(
          () => notifications.showMissedCheckInReminder(
            missedCheckIns: 3,
            requiredMissedCheckIns: 3,
          ),
        ).called(1);
      },
    );

    test('a current check-in clears the old warning', () async {
      when(() => cache.remove(any())).thenAnswer((_) async {});

      await serviceAt(
        lastCheckIn.add(const Duration(minutes: 59)),
      ).checkInactivity();

      verify(() => cache.remove(any())).called(1);
      verifyNever(
        () => notifications.showMissedCheckInReminder(
          missedCheckIns: any(named: 'missedCheckIns'),
          requiredMissedCheckIns: any(named: 'requiredMissedCheckIns'),
        ),
      );
    });
  });

  group('EmergencyService user reminder', () {
    test('sends directly to a verified user phone when available', () async {
      final users = _MockUserRepository();
      final emergencies = _MockEmergencyRepository();
      final directSms = _MockDirectSmsService();
      when(() => users.getProfile('user-1')).thenAnswer(
        (_) async => {
          'name': 'Kai',
          'phone': '+60123456789',
          'phone_verified_at': DateTime.utc(2026, 7, 1).toIso8601String(),
        },
      );
      when(
        () => directSms.send(
          phone: '+60123456789',
          message: any(named: 'message'),
        ),
      ).thenAnswer((_) async => const DirectSmsResult(sent: true));

      final result =
          await EmergencyService(
            authRepository: authRepository,
            contactRepository: _MockContactRepository(),
            emergencyRepository: emergencies,
            userRepository: users,
            locationService: _MockLocationService(),
            directSmsService: directSms,
          ).sendUserInactivityReminder(
            lastCheckIn: DateTime.utc(2026, 8, 1, 8),
            thresholdHours: 1,
            allowDirectSms: true,
          );

      expect(result.sent, isTrue);
      expect(result.queued, isFalse);
      verifyNever(
        () => emergencies.queueInactivityUserSms(
          userId: any(named: 'userId'),
          lastCheckIn: any(named: 'lastCheckIn'),
          recipientName: any(named: 'recipientName'),
          recipientPhone: any(named: 'recipientPhone'),
          messageBody: any(named: 'messageBody'),
        ),
      );
    });

    test(
      'queues and processes SMS when direct Android delivery fails',
      () async {
        final users = _MockUserRepository();
        final emergencies = _MockEmergencyRepository();
        final directSms = _MockDirectSmsService();
        when(() => users.getProfile('user-1')).thenAnswer(
          (_) async => {
            'name': 'Kai',
            'phone': '+60123456789',
            'phone_verified_at': DateTime.utc(2026, 7, 1).toIso8601String(),
          },
        );
        when(
          () => directSms.send(
            phone: '+60123456789',
            message: any(named: 'message'),
          ),
        ).thenAnswer(
          (_) async => const DirectSmsResult(
            sent: false,
            error: 'Direct SMS unavailable',
          ),
        );
        when(
          () => emergencies.queueInactivityUserSms(
            userId: 'user-1',
            lastCheckIn: any(named: 'lastCheckIn'),
            recipientName: 'Kai',
            recipientPhone: '+60123456789',
            messageBody: any(named: 'messageBody'),
          ),
        ).thenAnswer((_) async => true);
        when(
          emergencies.processPendingSms,
        ).thenAnswer((_) async => {'sent': 1, 'failed': 0});

        final result =
            await EmergencyService(
              authRepository: authRepository,
              contactRepository: _MockContactRepository(),
              emergencyRepository: emergencies,
              userRepository: users,
              locationService: _MockLocationService(),
              directSmsService: directSms,
            ).sendUserInactivityReminder(
              lastCheckIn: DateTime.utc(2026, 8, 1, 8),
              thresholdHours: 1,
              allowDirectSms: true,
            );

        expect(result.sent, isTrue);
        verify(emergencies.processPendingSms).called(1);
      },
    );

    test('automatic reminders always use the server SMS worker', () async {
      final users = _MockUserRepository();
      final emergencies = _MockEmergencyRepository();
      final directSms = _MockDirectSmsService();
      when(() => users.getProfile('user-1')).thenAnswer(
        (_) async => {
          'name': 'Kai',
          'phone': '+60123456789',
          'phone_verified_at': DateTime.utc(2026, 7, 1).toIso8601String(),
        },
      );
      when(
        () => emergencies.queueInactivityUserSms(
          userId: 'user-1',
          lastCheckIn: any(named: 'lastCheckIn'),
          recipientName: 'Kai',
          recipientPhone: '+60123456789',
          messageBody: any(named: 'messageBody'),
        ),
      ).thenAnswer((_) async => true);
      when(
        emergencies.processPendingSms,
      ).thenAnswer((_) async => {'sent': 1, 'failed': 0});

      final result =
          await EmergencyService(
            authRepository: authRepository,
            contactRepository: _MockContactRepository(),
            emergencyRepository: emergencies,
            userRepository: users,
            locationService: _MockLocationService(),
            directSmsService: directSms,
          ).sendUserInactivityReminder(
            lastCheckIn: DateTime.utc(2026, 8, 1, 8),
            thresholdHours: 1,
            allowDirectSms: false,
          );

      expect(result.sent, isTrue);
      verifyNever(
        () => directSms.send(
          phone: any(named: 'phone'),
          message: any(named: 'message'),
        ),
      );
      verify(emergencies.processPendingSms).called(1);
    });

    test('does not report success when the outbox insert fails', () async {
      final users = _MockUserRepository();
      final emergencies = _MockEmergencyRepository();
      final directSms = _MockDirectSmsService();
      when(() => users.getProfile('user-1')).thenAnswer(
        (_) async => {
          'name': 'Kai',
          'phone': '+60123456789',
          'phone_verified_at': DateTime.utc(2026, 7, 1).toIso8601String(),
        },
      );
      when(
        () => directSms.send(
          phone: '+60123456789',
          message: any(named: 'message'),
        ),
      ).thenAnswer(
        (_) async =>
            const DirectSmsResult(sent: false, error: 'Direct SMS unavailable'),
      );
      when(
        () => emergencies.queueInactivityUserSms(
          userId: 'user-1',
          lastCheckIn: any(named: 'lastCheckIn'),
          recipientName: 'Kai',
          recipientPhone: '+60123456789',
          messageBody: any(named: 'messageBody'),
        ),
      ).thenThrow(Exception('outbox unavailable'));

      final result =
          await EmergencyService(
            authRepository: authRepository,
            contactRepository: _MockContactRepository(),
            emergencyRepository: emergencies,
            userRepository: users,
            locationService: _MockLocationService(),
            directSmsService: directSms,
          ).sendUserInactivityReminder(
            lastCheckIn: DateTime.utc(2026, 8, 1, 8),
            thresholdHours: 1,
          );

      expect(result.accepted, isFalse);
      expect(result.queued, isFalse);
      expect(result.error, contains('outbox unavailable'));
    });

    test(
      'keeps a successfully queued SMS when worker invocation fails',
      () async {
        final users = _MockUserRepository();
        final emergencies = _MockEmergencyRepository();
        final directSms = _MockDirectSmsService();
        when(() => users.getProfile('user-1')).thenAnswer(
          (_) async => {
            'name': 'Kai',
            'phone': '+60123456789',
            'phone_verified_at': DateTime.utc(2026, 7, 1).toIso8601String(),
          },
        );
        when(
          () => directSms.send(
            phone: '+60123456789',
            message: any(named: 'message'),
          ),
        ).thenAnswer(
          (_) async => const DirectSmsResult(
            sent: false,
            error: 'Direct SMS unavailable',
          ),
        );
        when(
          () => emergencies.queueInactivityUserSms(
            userId: 'user-1',
            lastCheckIn: any(named: 'lastCheckIn'),
            recipientName: 'Kai',
            recipientPhone: '+60123456789',
            messageBody: any(named: 'messageBody'),
          ),
        ).thenAnswer((_) async => true);
        when(
          emergencies.processPendingSms,
        ).thenThrow(Exception('worker unavailable'));

        final result =
            await EmergencyService(
              authRepository: authRepository,
              contactRepository: _MockContactRepository(),
              emergencyRepository: emergencies,
              userRepository: users,
              locationService: _MockLocationService(),
              directSmsService: directSms,
            ).sendUserInactivityReminder(
              lastCheckIn: DateTime.utc(2026, 8, 1, 8),
              thresholdHours: 1,
            );

        expect(result.accepted, isTrue);
        expect(result.sent, isFalse);
        expect(result.queued, isTrue);
        expect(result.error, contains('worker unavailable'));
      },
    );

    test(
      'reports a provider failure instead of claiming it is queued',
      () async {
        final users = _MockUserRepository();
        final emergencies = _MockEmergencyRepository();
        final directSms = _MockDirectSmsService();
        when(() => users.getProfile('user-1')).thenAnswer(
          (_) async => {
            'name': 'Kai',
            'phone': '+60123456789',
            'phone_verified_at': DateTime.utc(2026, 7, 1).toIso8601String(),
          },
        );
        when(
          () => directSms.send(
            phone: '+60123456789',
            message: any(named: 'message'),
          ),
        ).thenAnswer((_) async => const DirectSmsResult(sent: false));
        when(
          () => emergencies.queueInactivityUserSms(
            userId: 'user-1',
            lastCheckIn: any(named: 'lastCheckIn'),
            recipientName: 'Kai',
            recipientPhone: '+60123456789',
            messageBody: any(named: 'messageBody'),
          ),
        ).thenAnswer((_) async => true);
        when(emergencies.processPendingSms).thenAnswer(
          (_) async => {
            'sent': 0,
            'failed': 1,
            'exhausted': 0,
            'error': 'Twilio rejected the message',
          },
        );

        final result =
            await EmergencyService(
              authRepository: authRepository,
              contactRepository: _MockContactRepository(),
              emergencyRepository: emergencies,
              userRepository: users,
              locationService: _MockLocationService(),
              directSmsService: directSms,
            ).sendUserInactivityReminder(
              lastCheckIn: DateTime.utc(2026, 8, 1, 8),
              thresholdHours: 1,
            );

        expect(result.accepted, isFalse);
        expect(result.error, 'Twilio rejected the message');
      },
    );

    test('rejects SMS when the user phone is not verified', () async {
      final users = _MockUserRepository();
      final directSms = _MockDirectSmsService();
      when(
        () => users.getProfile('user-1'),
      ).thenAnswer((_) async => {'phone': '+60123456789'});

      final result =
          await EmergencyService(
            authRepository: authRepository,
            contactRepository: _MockContactRepository(),
            emergencyRepository: _MockEmergencyRepository(),
            userRepository: users,
            locationService: _MockLocationService(),
            directSmsService: directSms,
          ).sendUserInactivityReminder(
            lastCheckIn: DateTime.utc(2026, 8, 1, 8),
            thresholdHours: 1,
          );

      expect(result.accepted, isFalse);
      expect(result.error, contains('verify your phone'));
      verifyNever(
        () => directSms.send(
          phone: any(named: 'phone'),
          message: any(named: 'message'),
        ),
      );
    });
  });

  group('EmergencyService escalation', () {
    test('does not create an alert without a primary contact', () async {
      final contacts = _MockContactRepository();
      final emergencies = _MockEmergencyRepository();
      when(
        () => contacts.getPrimaryContact('user-1'),
      ).thenAnswer((_) async => null);

      final result = await EmergencyService(
        authRepository: authRepository,
        contactRepository: contacts,
        emergencyRepository: emergencies,
        userRepository: _MockUserRepository(),
        locationService: _MockLocationService(),
        directSmsService: _MockDirectSmsService(),
      ).triggerEmergencyDetailed(escalationTarget: 'primary_contact');

      expect(result.alertRecorded, isFalse);
      verifyNever(
        () => emergencies.createAlert(any(), status: any(named: 'status')),
      );
    });

    test(
      'sends the alert with a maps location to the primary contact',
      () async {
        final contacts = _MockContactRepository();
        final emergencies = _MockEmergencyRepository();
        final directSms = _MockDirectSmsService();
        final locations = _MockLocationService();
        final position = _MockPosition();
        when(
          () => contacts.getPrimaryContact('user-1'),
        ).thenAnswer((_) async => {'id': 'contact-1', 'phone': '+60123456789'});
        when(
          () => contacts.hasPrimaryContact('user-1'),
        ).thenAnswer((_) async => true);
        when(
          () => emergencies.createAlert('user-1', status: 'triggered'),
        ).thenAnswer((_) async => {'id': 'alert-1'});
        when(locations.getCurrentPosition).thenAnswer((_) async => position);
        when(() => position.latitude).thenReturn(3.139);
        when(() => position.longitude).thenReturn(101.6869);
        when(
          () => directSms.send(
            phone: '+60123456789',
            message: any(named: 'message'),
          ),
        ).thenAnswer((_) async => const DirectSmsResult(sent: true));
        when(
          () => emergencies.addLocation(
            alertId: 'alert-1',
            latitude: 3.139,
            longitude: 101.6869,
          ),
        ).thenAnswer((_) async {});

        final result = await EmergencyService(
          authRepository: authRepository,
          contactRepository: contacts,
          emergencyRepository: emergencies,
          userRepository: _MockUserRepository(),
          locationService: locations,
          directSmsService: directSms,
        ).triggerEmergencyDetailed(
          escalationTarget: 'primary_contact',
          allowDirectSms: true,
        );

        expect(result.alertRecorded, isTrue);
        expect(result.autoSmsAttempted, isTrue);
        expect(result.autoSmsSent, 1);
        expect(result.locationIncluded, isTrue);
        final message =
            verify(
                  () => directSms.send(
                    phone: '+60123456789',
                    message: captureAny(named: 'message'),
                  ),
                ).captured.single
                as String;
        expect(message, contains('maps.google.com/?q=3.139,101.6869'));
        verifyNever(
          () => emergencies.createDeliveryOutbox(
            alertId: any(named: 'alertId'),
            userId: any(named: 'userId'),
            contacts: any(named: 'contacts'),
            messageBody: any(named: 'messageBody'),
          ),
        );
      },
    );

    test('falls back to the server outbox when direct SMS fails', () async {
      final contacts = _MockContactRepository();
      final emergencies = _MockEmergencyRepository();
      final directSms = _MockDirectSmsService();
      final locations = _MockLocationService();
      final position = _MockPosition();
      when(
        () => contacts.getPrimaryContact('user-1'),
      ).thenAnswer((_) async => {'id': 'contact-1', 'phone': '+60123456789'});
      when(
        () => contacts.hasPrimaryContact('user-1'),
      ).thenAnswer((_) async => true);
      when(
        () => emergencies.createAlert('user-1', status: 'triggered'),
      ).thenAnswer((_) async => {'id': 'alert-1'});
      when(locations.getCurrentPosition).thenAnswer((_) async => position);
      when(() => position.latitude).thenReturn(3.139);
      when(() => position.longitude).thenReturn(101.6869);
      when(
        () => directSms.send(
          phone: '+60123456789',
          message: any(named: 'message'),
        ),
      ).thenAnswer(
        (_) async =>
            const DirectSmsResult(sent: false, error: 'No SIM available'),
      );
      when(
        () => emergencies.createDeliveryOutbox(
          alertId: 'alert-1',
          userId: 'user-1',
          contacts: any(named: 'contacts'),
          messageBody: any(named: 'messageBody'),
        ),
      ).thenAnswer((_) async {});
      when(
        emergencies.processPendingSms,
      ).thenAnswer((_) async => {'sent': 1, 'failed': 0});
      when(
        () => emergencies.addLocation(
          alertId: 'alert-1',
          latitude: 3.139,
          longitude: 101.6869,
        ),
      ).thenAnswer((_) async {});

      final result = await EmergencyService(
        authRepository: authRepository,
        contactRepository: contacts,
        emergencyRepository: emergencies,
        userRepository: _MockUserRepository(),
        locationService: locations,
        directSmsService: directSms,
      ).triggerEmergencyDetailed(
        escalationTarget: 'primary_contact',
        allowDirectSms: true,
      );

      expect(result.alertRecorded, isTrue);
      expect(result.autoSmsSent, 1);
      expect(result.locationIncluded, isTrue);
      expect(result.autoSmsFailed, 0);
      verify(emergencies.processPendingSms).called(1);
      final queuedMessage =
          verify(
                () => emergencies.createDeliveryOutbox(
                  alertId: 'alert-1',
                  userId: 'user-1',
                  contacts: any(named: 'contacts'),
                  messageBody: captureAny(named: 'messageBody'),
                ),
              ).captured.single
              as String;
      expect(queuedMessage, contains('maps.google.com/?q=3.139,101.6869'));
    });

    test('can force emergency delivery through the server outbox', () async {
      final contacts = _MockContactRepository();
      final emergencies = _MockEmergencyRepository();
      final directSms = _MockDirectSmsService();
      final locations = _MockLocationService();
      when(
        () => contacts.getPrimaryContact('user-1'),
      ).thenAnswer((_) async => {'id': 'contact-1', 'phone': '+60123456789'});
      when(
        () => contacts.hasPrimaryContact('user-1'),
      ).thenAnswer((_) async => true);
      when(
        () => emergencies.createAlert('user-1', status: 'inactivity_triggered'),
      ).thenAnswer((_) async => {'id': 'alert-1'});
      when(locations.getCurrentPosition).thenAnswer((_) async => null);
      when(
        () => emergencies.createDeliveryOutbox(
          alertId: 'alert-1',
          userId: 'user-1',
          contacts: any(named: 'contacts'),
          messageBody: any(named: 'messageBody'),
        ),
      ).thenAnswer((_) async {});
      when(
        emergencies.processPendingSms,
      ).thenAnswer((_) async => {'sent': 1, 'failed': 0});

      final result = await EmergencyService(
        authRepository: authRepository,
        contactRepository: contacts,
        emergencyRepository: emergencies,
        userRepository: _MockUserRepository(),
        locationService: locations,
        directSmsService: directSms,
      ).triggerEmergencyDetailed(
        escalationTarget: 'primary_contact',
        alertStatus: 'inactivity_triggered',
        allowDirectSms: false,
      );

      expect(result.alertRecorded, isTrue);
      expect(result.autoSmsSent, 1);
      verifyNever(
        () => directSms.send(
          phone: any(named: 'phone'),
          message: any(named: 'message'),
        ),
      );
      verify(emergencies.processPendingSms).called(1);
    });

    test(
      'official 999 mode records an alert without contacting a user',
      () async {
        final contacts = _MockContactRepository();
        final emergencies = _MockEmergencyRepository();
        final locations = _MockLocationService();
        when(
          () => emergencies.createAlert('user-1', status: 'triggered'),
        ).thenAnswer((_) async => {'id': 'alert-1'});
        when(locations.getCurrentPosition).thenAnswer((_) async => null);

        final result =
            await EmergencyService(
              authRepository: authRepository,
              contactRepository: contacts,
              emergencyRepository: emergencies,
              userRepository: _MockUserRepository(),
              locationService: locations,
              directSmsService: _MockDirectSmsService(),
            ).triggerEmergencyDetailed(
              escalationTarget: 'official_999',
              allow999Dialer: false,
            );

        expect(result.alertRecorded, isTrue);
        expect(result.official999Selected, isTrue);
        expect(result.dialerOpened, isFalse);
        expect(result.autoSmsAttempted, isFalse);
        verifyNever(() => contacts.getPrimaryContact(any()));
      },
    );
  });

  group('Dashboard and Oren persistence', () {
    test(
      'dashboard refresh stores the profile threshold and latest alert',
      () async {
        final checkins = _MockCheckinRepository();
        final users = _MockUserRepository();
        final emergencies = _MockEmergencyRepository();
        final cache = _MockLocalCacheService();
        final checkedAt = DateTime.utc(2026, 8, 1, 8);
        when(
          () => checkins.getCheckinTimes('user-1'),
        ).thenAnswer((_) async => [checkedAt]);
        when(
          () => users.getProfile('user-1'),
        ).thenAnswer((_) async => {'name': 'Kai', 'inactivity_threshold': 1});
        when(() => emergencies.getLatestAlert('user-1')).thenAnswer(
          (_) async => {
            'status': 'inactivity_triggered',
            'triggered_time': DateTime.utc(2026, 8, 1, 10).toIso8601String(),
          },
        );
        when(() => cache.writeMap(any(), any())).thenAnswer((_) async {});

        final snapshot = await DashboardService(
          cache: cache,
          authRepository: authRepository,
          checkinRepository: checkins,
          userRepository: users,
          emergencyRepository: emergencies,
        ).refresh();

        expect(snapshot.userName, 'Kai');
        expect(snapshot.inactivityThresholdHours, 1);
        expect(snapshot.emergencyStatus, 'inactivity_triggered');
        expect(snapshot.lastCheckin, checkedAt);
        verify(() => cache.writeMap(any(), any())).called(1);
      },
    );

    test('feeding Oren persists the energy and mood change', () async {
      final cache = _MockLocalCacheService();
      final initial = OrenCareState.initial().copyWith(
        energy: 40,
        updatedAt: DateTime.now(),
      );
      when(
        () => cache.readMap(OrenCareService.cacheKeyForUser('user-1')),
      ).thenAnswer((_) async => initial.toJson());
      when(() => cache.writeMap(any(), any())).thenAnswer((_) async {});

      final state = await OrenCareService(
        authRepository: authRepository,
        cache: cache,
      ).feedFish();

      expect(state.energy, 52);
      expect(state.mood, 'Eating');
      final saved =
          verify(() => cache.writeMap(any(), captureAny())).captured.single
              as Map<String, dynamic>;
      expect(saved['energy'], 52);
      expect(saved['mood'], 'Eating');
    });

    test('concurrent Oren actions do not overwrite each other', () async {
      final cache = _MemoryCacheService();
      final key = OrenCareService.cacheKeyForUser('user-1');
      cache.values[key] = OrenCareState.initial()
          .copyWith(energy: 40, updatedAt: DateTime.now())
          .toJson();
      final service = OrenCareService(
        authRepository: authRepository,
        cache: cache,
      );

      await Future.wait([service.feedFish(), service.pet()]);
      final state = await service.load();

      expect(state.energy, 58);
      expect(cache.values[key]?['energy'], 58);
    });

    test('buying a toy deducts tokens and adds it to inventory', () async {
      final cache = _MockLocalCacheService();
      final initial = OrenCareState.initial().copyWith(
        tokens: 20,
        updatedAt: DateTime.now(),
      );
      when(
        () => cache.readMap(OrenCareService.cacheKeyForUser('user-1')),
      ).thenAnswer((_) async => initial.toJson());
      when(() => cache.writeMap(any(), any())).thenAnswer((_) async {});

      final state = await OrenCareService(
        authRepository: authRepository,
        cache: cache,
      ).buyToy(OrenCareService.toyCatalog.first);

      expect(state.tokens, 12);
      expect(state.ownedToyIds, contains('yarn_ball'));
      expect(state.selectedToyId, 'yarn_ball');
    });

    test('daily login and check-in tokens can only be claimed once', () async {
      final cache = _MemoryCacheService();
      final service = OrenCareService(
        authRepository: authRepository,
        cache: cache,
      );

      final firstLogin = await service.claimDailyLoginToken();
      final secondLogin = await service.claimDailyLoginToken();
      final firstCheckIn = await service.awardDailyCheckInTokens();
      final secondCheckIn = await service.awardDailyCheckInTokens();

      expect(firstLogin.tokens, OrenCareService.dailyLoginTokenReward);
      expect(secondLogin.tokens, OrenCareService.dailyLoginTokenReward);
      expect(
        firstCheckIn.tokens,
        OrenCareService.dailyLoginTokenReward +
            OrenCareService.dailyCheckInTokenReward,
      );
      expect(secondCheckIn.tokens, firstCheckIn.tokens);
      expect(secondCheckIn.lastAction, contains('already claimed'));
    });

    test('an unaffordable toy is not added to inventory', () async {
      final cache = _MemoryCacheService();
      final service = OrenCareService(
        authRepository: authRepository,
        cache: cache,
      );

      final state = await service.buyToy(OrenCareService.toyCatalog.last);

      expect(state.tokens, 0);
      expect(state.ownedToyIds, isEmpty);
      expect(state.lastAction, contains('Not enough'));
    });

    test('an owned toy can be selected and playing consumes energy', () async {
      final cache = _MemoryCacheService();
      final toy = OrenCareService.toyCatalog.first;
      cache.values[OrenCareService.cacheKeyForUser(
        'user-1',
      )] = OrenCareState.initial()
          .copyWith(
            energy: 80,
            ownedToyIds: {toy.id},
            updatedAt: DateTime.now(),
          )
          .toJson();
      final service = OrenCareService(
        authRepository: authRepository,
        cache: cache,
      );

      final selected = await service.selectToy(toy);
      final played = await service.playWithToy(toy);

      expect(selected.selectedToyId, toy.id);
      expect(played.energy, 70);
      expect(played.mood, 'Playful');
      expect(played.lastAction, contains(toy.name));
    });

    test('Oren refuses play when tired and keeps the same energy', () async {
      final cache = _MemoryCacheService();
      final toy = OrenCareService.toyCatalog.first;
      cache.values[OrenCareService.cacheKeyForUser(
        'user-1',
      )] = OrenCareState.initial()
          .copyWith(
            energy: 15,
            ownedToyIds: {toy.id},
            selectedToyId: toy.id,
            updatedAt: DateTime.now(),
          )
          .toJson();

      final state = await OrenCareService(
        authRepository: authRepository,
        cache: cache,
      ).playWithToy(toy);

      expect(state.energy, 15);
      expect(state.mood, 'Tired');
      expect(state.lastAction, contains('too tired'));
    });

    test('production Oren state is refreshed from the server', () async {
      final cache = _MockLocalCacheService();
      final repository = _MockOrenCareRepository();
      final cached = OrenCareState.initial().copyWith(
        tokens: 4,
        updatedAt: DateTime.now(),
      );
      final remote = cached.copyWith(tokens: 11, mood: 'Happy');
      when(
        () => cache.readMap(OrenCareService.cacheKeyForUser('user-1')),
      ).thenAnswer((_) async => cached.toJson());
      when(
        () => repository.loadState(
          legacyState: any(named: 'legacyState'),
        ),
      ).thenAnswer((_) async => remote.toJson());
      when(() => cache.writeMap(any(), any())).thenAnswer((_) async {});

      final state = await OrenCareService(
        authRepository: authRepository,
        cache: cache,
        repository: repository,
      ).load();

      expect(state.tokens, 11);
      expect(state.mood, 'Happy');
      verify(
        () => repository.loadState(
          legacyState: any(named: 'legacyState'),
        ),
      ).called(1);
      verify(() => cache.writeMap(any(), remote.toJson())).called(1);
    });

    test('production Oren purchases are authorized by the server', () async {
      final cache = _MockLocalCacheService();
      final repository = _MockOrenCareRepository();
      final toy = OrenCareService.toyCatalog.first;
      final remote = OrenCareState.initial().copyWith(
        tokens: 7,
        ownedToyIds: {toy.id},
        selectedToyId: toy.id,
      );
      when(
        () => repository.performAction('buy_toy', toyId: toy.id),
      ).thenAnswer((_) async => remote.toJson());
      when(() => cache.writeMap(any(), any())).thenAnswer((_) async {});

      final state = await OrenCareService(
        authRepository: authRepository,
        cache: cache,
        repository: repository,
      ).buyToy(toy);

      expect(state.ownedToyIds, contains(toy.id));
      verify(
        () => repository.performAction('buy_toy', toyId: toy.id),
      ).called(1);
      verify(() => cache.writeMap(any(), remote.toJson())).called(1);
    });
  });
}
