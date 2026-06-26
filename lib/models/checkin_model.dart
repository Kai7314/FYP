class CheckinModel {
  const CheckinModel({
    required this.userId,
    required this.checkinTime,
    this.id,
    this.status = 'active',
  });

  final String? id;
  final String userId;
  final DateTime checkinTime;
  final String status;

  factory CheckinModel.fromJson(Map<String, dynamic> json) {
    return CheckinModel(
      id: json['id']?.toString() ?? json['checkin_id']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      checkinTime:
          DateTime.tryParse(json['checkin_time']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: json['status']?.toString() ?? 'active',
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'user_id': userId,
    'checkin_time': checkinTime.toIso8601String(),
    'status': status,
  };
}
