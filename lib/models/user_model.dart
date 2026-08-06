import 'emergency_escalation_target.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.phoneVerifiedAt,
    this.address,
    this.addressState,
    this.addressRegion,
    this.addressLatitude,
    this.addressLongitude,
    this.addressVerifiedAt,
    this.addressValidationProvider,
    this.bloodType,
    this.inactivityThreshold = 24,
    this.emergencyEscalationTarget = EmergencyEscalationTarget.primaryContact,
    this.termsAcceptedAt,
  });

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final DateTime? phoneVerifiedAt;
  final String? address;
  final String? addressState;
  final String? addressRegion;
  final double? addressLatitude;
  final double? addressLongitude;
  final DateTime? addressVerifiedAt;
  final String? addressValidationProvider;
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
      phoneVerifiedAt: DateTime.tryParse(
        json['phone_verified_at']?.toString() ?? '',
      ),
      address: json['address']?.toString(),
      addressState: json['address_state']?.toString(),
      addressRegion: json['address_region']?.toString(),
      addressLatitude: _asDouble(json['address_latitude']),
      addressLongitude: _asDouble(json['address_longitude']),
      addressVerifiedAt: DateTime.tryParse(
        json['address_verified_at']?.toString() ?? '',
      ),
      addressValidationProvider: json['address_validation_provider']
          ?.toString(),
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
    if (phoneVerifiedAt != null)
      'phone_verified_at': phoneVerifiedAt!.toIso8601String(),
    if (address != null) 'address': address,
    if (addressState != null) 'address_state': addressState,
    if (addressRegion != null) 'address_region': addressRegion,
    if (addressLatitude != null) 'address_latitude': addressLatitude,
    if (addressLongitude != null) 'address_longitude': addressLongitude,
    if (addressVerifiedAt != null)
      'address_verified_at': addressVerifiedAt!.toUtc().toIso8601String(),
    if (addressValidationProvider != null)
      'address_validation_provider': addressValidationProvider,
    if (bloodType != null) 'blood_type': bloodType,
    'inactivity_threshold': inactivityThreshold,
    'emergency_escalation_target': emergencyEscalationTarget,
    if (termsAcceptedAt != null)
      'terms_accepted_at': termsAcceptedAt!.toIso8601String(),
  };

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
