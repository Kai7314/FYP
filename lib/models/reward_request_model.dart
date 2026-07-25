class RewardRequest {
  const RewardRequest({
    required this.id,
    required this.userId,
    required this.rewardCode,
    required this.rewardTitle,
    required this.rewardSponsor,
    required this.rewardKind,
    required this.recipientName,
    required this.contactPhone,
    required this.deliveryAddress,
    required this.deliveryState,
    required this.deliveryRegion,
    required this.status,
    required this.requestedAt,
    required this.statusUpdatedAt,
    this.userName,
    this.userEmail,
    this.reviewedBy,
    this.reviewedAt,
    this.fulfilledAt,
    this.trackingReference,
    this.adminNotes,
  });

  final String id;
  final String userId;
  final String? userName;
  final String? userEmail;
  final String rewardCode;
  final String rewardTitle;
  final String rewardSponsor;
  final String rewardKind;
  final String recipientName;
  final String contactPhone;
  final String deliveryAddress;
  final String deliveryState;
  final String deliveryRegion;
  final String status;
  final DateTime requestedAt;
  final DateTime statusUpdatedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime? fulfilledAt;
  final String? trackingReference;
  final String? adminNotes;

  bool get isPhysical => rewardKind == 'physical';
  bool get isPending => status == 'pending';
  bool get isInFulfillment => status == 'preparing' || status == 'shipped';
  bool get isComplete => status == 'delivered' || status == 'rejected';

  String get statusLabel => switch (status) {
    'preparing' => 'Preparing',
    'shipped' => 'Shipped',
    'delivered' => 'Delivered',
    'rejected' => 'Rejected',
    _ => 'Pending',
  };

  String get deliveryAddressLabel =>
      '$deliveryAddress, $deliveryRegion, $deliveryState';

  factory RewardRequest.fromJson(Map<String, dynamic> json) {
    return RewardRequest(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: _nullableText(json['user_name']),
      userEmail: _nullableText(json['user_email']),
      rewardCode: json['reward_code']?.toString() ?? '',
      rewardTitle: json['reward_title']?.toString() ?? 'Reward',
      rewardSponsor: json['reward_sponsor']?.toString() ?? 'EthernaCare',
      rewardKind: json['reward_kind']?.toString() ?? 'physical',
      recipientName: json['recipient_name']?.toString() ?? '',
      contactPhone: json['contact_phone']?.toString() ?? '',
      deliveryAddress: json['delivery_address']?.toString() ?? '',
      deliveryState: json['delivery_state']?.toString() ?? '',
      deliveryRegion: json['delivery_region']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      requestedAt:
          DateTime.tryParse(json['requested_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      statusUpdatedAt:
          DateTime.tryParse(json['status_updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      reviewedBy: _nullableText(json['reviewed_by']),
      reviewedAt: DateTime.tryParse(json['reviewed_at']?.toString() ?? ''),
      fulfilledAt: DateTime.tryParse(json['fulfilled_at']?.toString() ?? ''),
      trackingReference: _nullableText(json['tracking_reference']),
      adminNotes: _nullableText(json['admin_notes']),
    );
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class RewardDeliveryDetails {
  const RewardDeliveryDetails({
    required this.recipientName,
    required this.contactPhone,
    required this.address,
    required this.state,
    required this.region,
  });

  final String recipientName;
  final String contactPhone;
  final String address;
  final String state;
  final String region;
}
