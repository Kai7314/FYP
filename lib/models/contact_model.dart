class ContactModel {
  const ContactModel({
    required this.userId,
    required this.name,
    required this.relationship,
    required this.phone,
    required this.address,
    this.id,
    this.isPrimary = false,
  });

  final String? id;
  final String userId;
  final String name;
  final String relationship;
  final String phone;
  final String address;
  final bool isPrimary;

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id']?.toString() ?? json['contact_id']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      relationship: json['relationship']?.toString() ?? 'Trusted contact',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
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
    'address': address,
    'is_primary': isPrimary,
  };
}
