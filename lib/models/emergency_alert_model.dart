class EmergencyAlertModel {
  const EmergencyAlertModel({
    required this.userId,
    required this.triggeredTime,
    this.id,
    this.status = 'triggered',
  });

  final String? id;
  final String userId;
  final DateTime triggeredTime;
  final String status;

  factory EmergencyAlertModel.fromJson(Map<String, dynamic> json) {
    return EmergencyAlertModel(
      id: json['id']?.toString() ?? json['alert_id']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      triggeredTime:
          DateTime.tryParse(json['triggered_time']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: json['status']?.toString() ?? 'triggered',
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'user_id': userId,
    'triggered_time': triggeredTime.toIso8601String(),
    'status': status,
  };
}
