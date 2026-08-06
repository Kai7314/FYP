import 'package:flutter_test/flutter_test.dart';
import 'package:fyp/models/oren_care_model.dart';
import 'package:fyp/services/dashboard_service.dart';
import 'package:fyp/services/emergency_service.dart';
import 'package:fyp/services/inactivity_service.dart';
import 'package:fyp/services/oren_care_service.dart';

void main() {
  group('rolling inactivity thresholds', () {
    final lastCheckIn = DateTime.utc(2026, 8, 1, 8);

    test('thresholds below 24 hours normalize to one full day', () {
      expect(
        InactivityService.calculateMissedCheckIns(
          lastCheckIn: lastCheckIn,
          now: lastCheckIn.add(const Duration(hours: 23, minutes: 59)),
          thresholdHours: 1,
        ),
        0,
      );
      expect(
        InactivityService.calculateMissedCheckIns(
          lastCheckIn: lastCheckIn,
          now: lastCheckIn.add(const Duration(hours: 24)),
          thresholdHours: 1,
        ),
        1,
      );
      expect(
        InactivityService.calculateMissedCheckIns(
          lastCheckIn: lastCheckIn,
          now: lastCheckIn.add(const Duration(hours: 48)),
          thresholdHours: 1,
        ),
        InactivityService.userSmsReminderMiss,
      );
    });

    test('24-hour threshold expires exactly after 24 hours', () {
      expect(
        InactivityService.isCheckInCurrent(
          lastCheckIn: lastCheckIn,
          now: lastCheckIn.add(const Duration(hours: 23, minutes: 59)),
          thresholdHours: 24,
        ),
        isTrue,
      );
      expect(
        InactivityService.isCheckInCurrent(
          lastCheckIn: lastCheckIn,
          now: lastCheckIn.add(const Duration(hours: 24)),
          thresholdHours: 24,
        ),
        isFalse,
      );
    });

    test('user reminder message describes the two missed windows', () {
      final message = EmergencyService.inactivityUserSmsMessage(
        thresholdHours: 1,
      );

      expect(message, contains('missed two 24-hour check-in windows'));
      expect(message, contains('primary trusted contact'));
    });

    test('user SMS retries only after its cooldown', () {
      final now = DateTime.utc(2026, 8, 1, 10);

      expect(
        InactivityService.shouldAttemptUserSms(
          missedCheckIns: 1,
          userSmsAccepted: false,
          now: now,
        ),
        isFalse,
      );
      expect(
        InactivityService.shouldAttemptUserSms(
          missedCheckIns: 2,
          userSmsAccepted: false,
          now: now,
        ),
        isTrue,
      );
      expect(
        InactivityService.shouldAttemptUserSms(
          missedCheckIns: 2,
          userSmsAccepted: false,
          now: now,
          lastAttemptAt: now.subtract(const Duration(minutes: 29)),
        ),
        isFalse,
      );
      expect(
        InactivityService.shouldAttemptUserSms(
          missedCheckIns: 2,
          userSmsAccepted: false,
          now: now,
          lastAttemptAt: now.subtract(const Duration(minutes: 30)),
        ),
        isTrue,
      );
      expect(
        InactivityService.shouldAttemptUserSms(
          missedCheckIns: 3,
          userSmsAccepted: true,
          now: now,
        ),
        isFalse,
      );
    });

    test('trusted contact escalation occurs once at the third window', () {
      expect(
        InactivityService.shouldEscalateToTrustedContact(
          missedCheckIns: 2,
          alreadyEscalated: false,
          alertAlreadyRecordedForCheckIn: false,
        ),
        isFalse,
      );
      expect(
        InactivityService.shouldEscalateToTrustedContact(
          missedCheckIns: 3,
          alreadyEscalated: false,
          alertAlreadyRecordedForCheckIn: false,
        ),
        isTrue,
      );
      expect(
        InactivityService.shouldEscalateToTrustedContact(
          missedCheckIns: 4,
          alreadyEscalated: true,
          alertAlreadyRecordedForCheckIn: false,
        ),
        isFalse,
      );
      expect(
        InactivityService.shouldEscalateToTrustedContact(
          missedCheckIns: 4,
          alreadyEscalated: false,
          alertAlreadyRecordedForCheckIn: true,
        ),
        isFalse,
      );
    });

    test('dashboard cache upgrades an obsolete threshold', () {
      final snapshot = DashboardSnapshot(
        userName: 'Kai',
        checkinTimes: [lastCheckIn],
        emergencyStatus: 'safe',
        latestEmergencyAlertTime: null,
        syncedAt: DateTime.utc(2026, 8, 1, 9),
        inactivityThresholdHours: 1,
      );

      final restored = DashboardSnapshot.fromJson(snapshot.toJson());

      expect(restored.inactivityThresholdHours, 24);
      expect(restored.lastCheckin, lastCheckIn);
    });
  });

  group('Oren energy decay', () {
    final updatedAt = DateTime.utc(2026, 8, 1, 8);

    test('subtracts one energy per complete inactive hour', () {
      final state = OrenCareState.initial().copyWith(
        energy: 65,
        updatedAt: updatedAt,
      );

      final beforeOneHour = OrenCareService.applyEnergyDecay(
        state,
        updatedAt.add(const Duration(minutes: 59)),
      );
      final afterThreeAndHalfHours = OrenCareService.applyEnergyDecay(
        state,
        updatedAt.add(const Duration(hours: 3, minutes: 30)),
      );

      expect(beforeOneHour.energy, 65);
      expect(beforeOneHour.updatedAt, updatedAt);
      expect(afterThreeAndHalfHours.energy, 62);
      expect(
        afterThreeAndHalfHours.updatedAt,
        updatedAt.add(const Duration(hours: 3)),
      );
    });

    test('stops at zero and changes Oren to tired', () {
      final state = OrenCareState.initial().copyWith(
        energy: 2,
        updatedAt: updatedAt,
      );

      final decayed = OrenCareService.applyEnergyDecay(
        state,
        updatedAt.add(const Duration(hours: 10)),
      );

      expect(decayed.energy, 0);
      expect(decayed.mood, 'Tired');
    });

    test('preserves partial hours between repeated decay checks', () {
      final state = OrenCareState.initial().copyWith(
        energy: 65,
        updatedAt: updatedAt,
      );
      final first = OrenCareService.applyEnergyDecay(
        state,
        updatedAt.add(const Duration(hours: 3, minutes: 30)),
      );
      final second = OrenCareService.applyEnergyDecay(
        first,
        updatedAt.add(const Duration(hours: 4)),
      );

      expect(first.energy, 62);
      expect(second.energy, 61);
      expect(second.updatedAt, updatedAt.add(const Duration(hours: 4)));
    });

    test('does not decay when the saved timestamp is in the future', () {
      final state = OrenCareState.initial().copyWith(
        energy: 65,
        updatedAt: updatedAt,
      );

      final unchanged = OrenCareService.applyEnergyDecay(
        state,
        updatedAt.subtract(const Duration(minutes: 1)),
      );

      expect(unchanged.energy, 65);
      expect(unchanged.updatedAt, updatedAt);
    });
  });
}
