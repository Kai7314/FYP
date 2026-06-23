class RewardCatalogItem {
  const RewardCatalogItem({
    required this.code,
    required this.title,
    required this.sponsor,
    required this.description,
    required this.milestoneDays,
    required this.rewardKind,
    required this.catalogVersion,
    this.voucherValue,
  });

  final String code;
  final String title;
  final String sponsor;
  final String description;
  final int milestoneDays;
  final String rewardKind;
  final int catalogVersion;
  final String? voucherValue;

  factory RewardCatalogItem.fromJson(Map<String, dynamic> json) {
    return RewardCatalogItem(
      code: json['code']?.toString() ?? json['title']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Reward',
      sponsor: json['sponsor']?.toString() ?? 'EthernaCare',
      description: json['description']?.toString() ?? '',
      milestoneDays:
          int.tryParse(json['milestone_days']?.toString() ?? '') ?? 0,
      rewardKind: json['reward_kind']?.toString() ?? 'physical',
      catalogVersion:
          int.tryParse(json['catalog_version']?.toString() ?? '') ?? 1,
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
    'voucher_value': voucherValue,
  };
}

class RewardSnapshot {
  const RewardSnapshot({
    required this.catalog,
    required this.earnedCodes,
    required this.catalogVersion,
    required this.syncedAt,
  });

  final List<RewardCatalogItem> catalog;
  final Set<String> earnedCodes;
  final int catalogVersion;
  final DateTime syncedAt;

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
    'catalog_version': catalogVersion,
    'synced_at': syncedAt.toIso8601String(),
  };
}
