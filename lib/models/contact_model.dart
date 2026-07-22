class ContactModel {
  const ContactModel({
    required this.userId,
    required this.name,
    required this.relationship,
    required this.phone,
    required this.email,
    required this.address,
    this.addressState,
    this.addressRegion,
    this.phoneVerifiedAt,
    this.id,
    this.isPrimary = false,
  });

  final String? id;
  final String userId;
  final String name;
  final String relationship;
  final String phone;
  final String email;
  final String address;
  final String? addressState;
  final String? addressRegion;
  final DateTime? phoneVerifiedAt;
  final bool isPrimary;

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id']?.toString() ?? json['contact_id']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      relationship: json['relationship']?.toString() ?? 'Trusted contact',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      addressState: json['address_state']?.toString(),
      addressRegion: json['address_region']?.toString(),
      phoneVerifiedAt: DateTime.tryParse(
        json['phone_verified_at']?.toString() ?? '',
      ),
      isPrimary:
          json['is_primary'] == true || json['is_primary']?.toString() == '1',
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'user_id': userId,
    'name': name,
    'relationship': relationship,
    'phone': phone,
    'email': email,
    'address': address,
    if (addressState != null) 'address_state': addressState,
    if (addressRegion != null) 'address_region': addressRegion,
    if (phoneVerifiedAt != null)
      'phone_verified_at': phoneVerifiedAt!.toIso8601String(),
    'is_primary': isPrimary,
  };
}
