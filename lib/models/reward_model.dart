class RewardCatalogItem {
  const RewardCatalogItem({
    required this.code,
    required this.title,
    required this.sponsor,
    required this.description,
    required this.milestoneDays,
    required this.rewardKind,
    required this.catalogVersion,
    this.active = true,
    this.voucherValue,
  });

  final String code;
  final String title;
  final String sponsor;
  final String description;
  final int milestoneDays;
  final String rewardKind;
  final int catalogVersion;
  final bool active;
  final String? voucherValue;

  bool get isVoucher => rewardKind == 'voucher';

  factory RewardCatalogItem.fromJson(Map<String, dynamic> json) {
    return RewardCatalogItem(
      code: json['code']?.toString() ?? json['title']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Reward',
      sponsor: json['sponsor']?.toString() ?? 'EthernaCare',
      description: json['description']?.toString() ?? '',
      milestoneDays:
          int.tryParse(json['milestone_days']?.toString() ?? '') ?? 0,
      rewardKind: json['reward_kind']?.toString() ?? 'virtual',
      catalogVersion:
          int.tryParse(json['catalog_version']?.toString() ?? '') ?? 1,
      active: json['active'] != false,
      voucherValue: json['voucher_value']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'title': title,
    'sponsor': sponsor,
    'description': description,
    'milestone_days': milestoneDays,
    'reward_kind': rewardKind,
    'catalog_version': catalogVersion,
    'active': active,
    'voucher_value': voucherValue,
  };
}

class RewardSnapshot {
  const RewardSnapshot({
    required this.catalog,
    required this.earnedCodes,
    required this.catalogVersion,
    required this.syncedAt,
    this.claimedBadgeCodes = const {},
    this.redemptionCodes = const {},
  });

  final List<RewardCatalogItem> catalog;
  final Set<String> earnedCodes;
  final Set<String> claimedBadgeCodes;
  final int catalogVersion;
  final DateTime syncedAt;
  final Map<String, String> redemptionCodes;

  String? redemptionCodeFor(String rewardCode) => redemptionCodes[rewardCode];

  bool isBadgeClaimed(String rewardCode) =>
      claimedBadgeCodes.contains(rewardCode);

  RewardCatalogItem? nextReward(int streak) {
    final available =
        catalog
            .where(
              (item) =>
                  item.milestoneDays > streak &&
                  !earnedCodes.contains(item.code),
            )
            .toList()
          ..sort((a, b) => a.milestoneDays.compareTo(b.milestoneDays));
    return available.isEmpty ? null : available.first;
  }

  factory RewardSnapshot.fromJson(Map<String, dynamic> json) {
    return RewardSnapshot(
      catalog: (json['catalog'] as List? ?? const [])
          .map(
            (item) => RewardCatalogItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      earnedCodes: (json['earned_codes'] as List? ?? const [])
          .map((item) => item.toString())
          .toSet(),
      claimedBadgeCodes: (json['claimed_badge_codes'] as List? ?? const [])
          .map((item) => item.toString())
          .toSet(),
      redemptionCodes: Map<String, dynamic>.from(
        json['redemption_codes'] as Map? ?? const {},
      ).map((key, value) => MapEntry(key, value.toString())),
      catalogVersion:
          int.tryParse(json['catalog_version']?.toString() ?? '') ?? 0,
      syncedAt:
          DateTime.tryParse(json['synced_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
    'catalog': catalog.map((item) => item.toJson()).toList(),
    'earned_codes': earnedCodes.toList(),
    'claimed_badge_codes': claimedBadgeCodes.toList(),
    'redemption_codes': redemptionCodes,
    'catalog_version': catalogVersion,
    'synced_at': syncedAt.toIso8601String(),
  };
}
