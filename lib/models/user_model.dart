import 'emergency_escalation_target.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.bloodType,
    this.inactivityThreshold = 24,
    this.emergencyEscalationTarget = EmergencyEscalationTarget.primaryContact,
    this.termsAcceptedAt,
  });

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? bloodType;
  final int inactivityThreshold;
  final String emergencyEscalationTarget;
  final DateTime? termsAcceptedAt;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'EthernaCare User',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      bloodType: json['blood_type']?.toString(),
      inactivityThreshold:
          int.tryParse(json['inactivity_threshold']?.toString() ?? '') ?? 24,
      emergencyEscalationTarget: EmergencyEscalationTarget.normalize(
        json['emergency_escalation_target'],
      ),
      termsAcceptedAt: DateTime.tryParse(
        json['terms_accepted_at']?.toString() ?? '',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (email != null) 'email': email,
    if (phone != null) 'phone': phone,
    if (address != null) 'address': address,
    if (bloodType != null) 'blood_type': bloodType,
    'inactivity_threshold': inactivityThreshold,
    'emergency_escalation_target': emergencyEscalationTarget,
    if (termsAcceptedAt != null)
      'terms_accepted_at': termsAcceptedAt!.toIso8601String(),
  };
}
