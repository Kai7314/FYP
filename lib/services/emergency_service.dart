import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../dataAccessLayer/repositories/auth_repository.dart';
import '../dataAccessLayer/repositories/contact_repository.dart';
import '../dataAccessLayer/repositories/emergency_repository.dart';
import '../dataAccessLayer/repositories/user_repository.dart';
import '../models/emergency_escalation_target.dart';
import 'direct_sms_service.dart';
import 'location_service.dart';

class EmergencyTriggerResult {
  const EmergencyTriggerResult({
    required this.alertRecorded,
    required this.primarySmsComposerOpened,
    this.official999Selected = false,
    this.dialerOpened = false,
    this.autoSmsAttempted = false,
    this.autoSmsSent = 0,
    this.autoSmsFailed = 0,
    this.autoSmsError,
  });

  final bool alertRecorded;
  final bool primarySmsComposerOpened;
  final bool official999Selected;
  final bool dialerOpened;
  final bool autoSmsAttempted;
  final int autoSmsSent;
  final int autoSmsFailed;
  final String? autoSmsError;
}

class InactivityUserSmsResult {
  const InactivityUserSmsResult({
    required this.sent,
    required this.queued,
    this.error,
  });

  final bool sent;
  final bool queued;
  final String? error;

  bool get accepted => sent || queued;
}

class EmergencyService {
  static const emergencySmsMessage =
      'Emergency alert from EthernaCare. The user may need help. Please contact them immediately.';
  static const testEmergencySmsMessage =
      'TEST - $emergencySmsMessage This is a test after three check-in reminders. No real emergency alert was sent and 999 was not contacted.';

  static String inactivityUserSmsMessage({
    required int thresholdHours,
    bool testMode = false,
  }) {
    final prefix = testMode ? 'TEST - ' : '';
    final unit = thresholdHours == 1 ? 'hour' : 'hours';
    return '${prefix}EthernaCare check-in reminder: you have missed two '
        '$thresholdHours-$unit check-in windows. Open EthernaCare and tap '
        'Oren now. If inactivity continues, your configured emergency '
        'escalation may notify your primary trusted contact.';
  }

  EmergencyService({
    AuthRepository? authRepository,
    ContactRepository? contactRepository,
    EmergencyRepository? emergencyRepository,
    UserRepository? userRepository,
    LocationService? locationService,
    DirectSmsService? directSmsService,
  }) : authRepository = authRepository ?? AuthRepository(),
       contactRepository = contactRepository ?? ContactRepository(),
       emergencyRepository = emergencyRepository ?? EmergencyRepository(),
       userRepository = userRepository ?? UserRepository(),
       locationService = locationService ?? LocationService(),
       directSmsService = directSmsService ?? DirectSmsService();

  final AuthRepository authRepository;
  final ContactRepository contactRepository;
  final EmergencyRepository emergencyRepository;
  final UserRepository userRepository;
  final LocationService locationService;
  final DirectSmsService directSmsService;

  Future<void> callMalaysiaEmergency999() async {
    final uri = Uri(scheme: 'tel', path: '999');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw StateError('Could not open the phone dialer for 999.');
    }
  }

  Future<bool> openPrimaryContactTestSms() async {
    final user = authRepository.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to test SMS.');
    }

    final primaryContact = await contactRepository.getPrimaryContact(user.id);
    if (primaryContact == null) return false;
    return _openSmsComposer(
      phone: primaryContact['phone']?.toString() ?? '',
      message:
          'TEST message from EthernaCare. This is only a test of the emergency SMS flow. No emergency alert has been triggered.',
    );
  }

  Future<bool> sendPrimaryContactTestSms() async {
    final user = authRepository.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to test SMS.');
    }

    final primaryContact = await contactRepository.getPrimaryContact(user.id);
    if (primaryContact == null) return false;

    final result = await directSmsService.send(
      phone: primaryContact['phone']?.toString() ?? '',
      message:
          'TEST message from EthernaCare. This is only a test of the emergency SMS flow. No emergency alert has been triggered.',
    );
    final error = result.error;
    if (!result.sent && error != null) {
      throw StateError(error);
    }
    return result.sent;
  }

  Future<bool> triggerEmergency() async {
    final result = await triggerEmergencyDetailed();
    return result.alertRecorded;
  }

  Future<EmergencyTriggerResult> triggerEmergencyDetailed({
    bool openPrimarySmsComposer = false,
    bool sendAutomatedSms = true,
    bool allow999Dialer = false,
    String? escalationTarget,
    bool testMode = false,
    String? alertStatus,
  }) async {
    final user = authRepository.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to send an emergency alert.');
    }

    final target =
        escalationTarget ??
        EmergencyEscalationTarget.normalize(
          (await userRepository.getProfile(
            user.id,
          ))?['emergency_escalation_target'],
        );
    final useOfficial999 = target == EmergencyEscalationTarget.official999;

    List<Map<String, dynamic>> contacts = const [];
    if (!useOfficial999) {
      final primaryContact = await contactRepository.getPrimaryContact(user.id);
      contacts = primaryContact == null ? const [] : [primaryContact];
      if (contacts.isEmpty) {
        return const EmergencyTriggerResult(
          alertRecorded: false,
          primarySmsComposerOpened: false,
        );
      }
      final hasPrimary = await contactRepository.hasPrimaryContact(user.id);
      if (!hasPrimary) {
        return const EmergencyTriggerResult(
          alertRecorded: false,
          primarySmsComposerOpened: false,
        );
      }
    }

    final alert = await _retry(
      () => emergencyRepository.createAlert(
        user.id,
        status: alertStatus ?? (testMode ? 'test_triggered' : 'triggered'),
      ),
      attempts: 3,
    );
    final position = await locationService.getCurrentPosition();
    final message = testMode
        ? _testEmergencyMessage()
        : _emergencyMessage(position);
    final alertId = alert['id'] ?? alert['alert_id'];
    var autoSmsAttempted = false;
    var autoSmsSent = 0;
    var autoSmsFailed = 0;
    String? autoSmsError;

    if (sendAutomatedSms && !useOfficial999 && contacts.isNotEmpty) {
      autoSmsAttempted = true;
      final directDelivery = await _sendDirectSmsToContacts(contacts, message);
      autoSmsSent += directDelivery.sent;
      autoSmsFailed += directDelivery.failed;
      autoSmsError = directDelivery.error;
    }

    var smsOutboxCreated = false;
    if (alertId != null && !useOfficial999 && autoSmsSent == 0) {
      try {
        await _retry(
          () => emergencyRepository.createDeliveryOutbox(
            alertId: alertId,
            userId: user.id,
            contacts: contacts,
            messageBody: message,
          ),
          attempts: 3,
        );
        smsOutboxCreated = true;
      } catch (_) {
        // The alert remains recorded even if delivery queue creation fails.
      }
    }
    if (position != null && alertId != null) {
      try {
        await emergencyRepository.addLocation(
          alertId: alertId,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } catch (_) {
        // The emergency alert remains valid even when location persistence
        // is unavailable or the optional locations table is not configured.
      }
    }
    var dialerOpened = false;
    String? official999Error;
    if (useOfficial999 && allow999Dialer) {
      try {
        await callMalaysiaEmergency999();
        dialerOpened = true;
      } catch (error) {
        official999Error = error.toString();
      }
    }
    if (smsOutboxCreated && sendAutomatedSms && !useOfficial999) {
      autoSmsAttempted = true;
      try {
        final delivery = await emergencyRepository.processPendingSms();
        autoSmsSent = _intFrom(delivery['sent']);
        autoSmsFailed = _intFrom(delivery['failed']);
        final error = delivery['error']?.toString();
        if (error != null && error.trim().isNotEmpty) {
          autoSmsError = _joinErrors(autoSmsError, error);
        }
      } catch (error) {
        autoSmsError = _joinErrors(autoSmsError, error.toString());
      }
    }
    var primarySmsComposerOpened = false;
    if (openPrimarySmsComposer) {
      final primaryContact = await contactRepository.getPrimaryContact(user.id);
      if (primaryContact != null) {
        primarySmsComposerOpened = await _openSmsComposer(
          phone: primaryContact['phone']?.toString() ?? '',
          message: message,
        );
      }
    }
    return EmergencyTriggerResult(
      alertRecorded: true,
      primarySmsComposerOpened: primarySmsComposerOpened,
      official999Selected: useOfficial999,
      dialerOpened: dialerOpened,
      autoSmsAttempted: autoSmsAttempted,
      autoSmsSent: autoSmsSent,
      autoSmsFailed: autoSmsFailed,
      autoSmsError: official999Error ?? autoSmsError,
    );
  }

  Future<InactivityUserSmsResult> sendUserInactivityReminder({
    required DateTime lastCheckIn,
    required int thresholdHours,
    bool testMode = false,
  }) async {
    final user = authRepository.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to send an inactivity reminder.');
    }

    final profile = await userRepository.getProfile(user.id);
    final phone = profile?['phone']?.toString().trim() ?? '';
    final phoneVerifiedAt = DateTime.tryParse(
      profile?['phone_verified_at']?.toString() ?? '',
    );
    if (phone.isEmpty || phoneVerifiedAt == null) {
      return const InactivityUserSmsResult(
        sent: false,
        queued: false,
        error:
            'Add and verify your phone number before SMS reminders can be sent.',
      );
    }

    final message = inactivityUserSmsMessage(
      thresholdHours: thresholdHours,
      testMode: testMode,
    );
    final direct = await directSmsService.send(phone: phone, message: message);
    if (direct.sent) {
      return const InactivityUserSmsResult(sent: true, queued: false);
    }

    var queued = false;
    try {
      await emergencyRepository.queueInactivityUserSms(
        userId: user.id,
        lastCheckIn: lastCheckIn,
        recipientName: profile?['name']?.toString() ?? 'EthernaCare user',
        recipientPhone: phone,
        messageBody: message,
      );
      queued = true;

      final delivery = await emergencyRepository.processPendingSms();
      final sent = _intFrom(delivery['sent']) > 0;
      final failed = _intFrom(delivery['failed']);
      final exhausted = _intFrom(delivery['exhausted']);
      final error = delivery['error']?.toString();
      if (!sent && (failed > 0 || exhausted > 0)) {
        return InactivityUserSmsResult(
          sent: false,
          queued: false,
          error: error == null || error.trim().isEmpty
              ? 'The SMS provider could not deliver the reminder.'
              : error,
        );
      }
      return InactivityUserSmsResult(
        sent: sent,
        queued: !sent,
        error: sent
            ? null
            : error == null || error.trim().isEmpty
            ? direct.error
            : error,
      );
    } catch (error) {
      return InactivityUserSmsResult(
        sent: false,
        queued: queued,
        error: _joinErrors(direct.error, error.toString()),
      );
    }
  }

  String _emergencyMessage(Position? position) {
    final locationText = position == null
        ? ''
        : '\nLocation: https://maps.google.com/?q=${position.latitude},${position.longitude}';
    return '$emergencySmsMessage$locationText';
  }

  String _testEmergencyMessage() {
    return testEmergencySmsMessage;
  }

  Future<bool> _openSmsComposer({
    required String phone,
    required String message,
  }) async {
    final normalizedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (normalizedPhone.isEmpty) return false;
    final uri = Uri(
      scheme: 'sms',
      path: normalizedPhone,
      queryParameters: {'body': message},
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<_SmsDeliveryAttempt> _sendDirectSmsToContacts(
    List<Map<String, dynamic>> contacts,
    String message,
  ) async {
    var sent = 0;
    var failed = 0;
    final errors = <String>[];
    for (final contact in contacts) {
      final result = await directSmsService.send(
        phone: contact['phone']?.toString() ?? '',
        message: message,
      );
      if (result.sent) {
        sent += 1;
      } else {
        failed += 1;
        final error = result.error;
        if (error != null && error.trim().isNotEmpty) errors.add(error);
      }
    }
    return _SmsDeliveryAttempt(
      sent: sent,
      failed: failed,
      error: errors.isEmpty ? null : errors.join(' '),
    );
  }

  Future<T> _retry<T>(
    Future<T> Function() action, {
    required int attempts,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        return await action();
      } catch (error) {
        lastError = error;
        if (attempt < attempts) {
          await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
        }
      }
    }
    throw lastError!;
  }

  int _intFrom(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String? _joinErrors(String? first, String second) {
    if (first == null || first.trim().isEmpty) return second;
    if (second.trim().isEmpty) return first;
    return '$first $second';
  }
}

class _SmsDeliveryAttempt {
  const _SmsDeliveryAttempt({
    required this.sent,
    required this.failed,
    this.error,
  });

  final int sent;
  final int failed;
  final String? error;
}
