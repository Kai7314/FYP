import '../dataAccessLayer/repositories/auth_repository.dart';
import '../dataAccessLayer/repositories/contact_repository.dart';
import '../dataAccessLayer/repositories/emergency_repository.dart';
import 'location_service.dart';

class EmergencyService {
  EmergencyService({
    AuthRepository? authRepository,
    ContactRepository? contactRepository,
    EmergencyRepository? emergencyRepository,
    LocationService? locationService,
  }) : authRepository = authRepository ?? AuthRepository(),
       contactRepository = contactRepository ?? ContactRepository(),
       emergencyRepository = emergencyRepository ?? EmergencyRepository(),
       locationService = locationService ?? LocationService();

  final AuthRepository authRepository;
  final ContactRepository contactRepository;
  final EmergencyRepository emergencyRepository;
  final LocationService locationService;

  Future<bool> triggerEmergency() async {
    final user = authRepository.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to send an emergency alert.');
    }

    final contacts = await contactRepository.getAlertRecipients(user.id);
    if (contacts.isEmpty) return false;
    final alert = await _retry(
      () => emergencyRepository.createAlert(user.id),
      attempts: 3,
    );
    final position = await locationService.getCurrentPosition();
    final alertId = alert['id'] ?? alert['alert_id'];
    if (alertId != null) {
      try {
        await _retry(
          () => emergencyRepository.createDeliveryOutbox(
            alertId: alertId,
            userId: user.id,
            contacts: contacts,
          ),
          attempts: 3,
        );
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
    return true;
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
}
