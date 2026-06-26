import '../../services/emergency_service.dart';

class EmergencyController {
  EmergencyController({EmergencyService? emergencyService})
    : emergencyService = emergencyService ?? EmergencyService();

  final EmergencyService emergencyService;

  Future<bool> triggerSos() => emergencyService.triggerEmergency();
}
