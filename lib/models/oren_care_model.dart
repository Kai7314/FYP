class OrenToy {
  const OrenToy({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.iconCodePoint,
    required this.imageAsset,
  });

  final String id;
  final String name;
  final String description;
  final int price;
  final int iconCodePoint;
  final String imageAsset;
}

class OrenCareState {
  const OrenCareState({
    required this.tokens,
    required this.ownedToyIds,
    required this.lastDailyTokenDate,
    required this.lastCheckInTokenDate,
    required this.lastAction,
    required this.mood,
    required this.energy,
    required this.updatedAt,
  });

  final int tokens;
  final Set<String> ownedToyIds;
  final String lastDailyTokenDate;
  final String lastCheckInTokenDate;
  final String lastAction;
  final String mood;
  final int energy;
  final DateTime updatedAt;

  factory OrenCareState.initial() {
    return OrenCareState(
      tokens: 0,
      ownedToyIds: const {},
      lastDailyTokenDate: '',
      lastCheckInTokenDate: '',
      lastAction: 'Oren is ready for today.',
      mood: 'Calm',
      energy: 65,
      updatedAt: DateTime.now(),
    );
  }

  factory OrenCareState.fromJson(Map<String, dynamic> json) {
    return OrenCareState(
      tokens: int.tryParse(json['tokens']?.toString() ?? '') ?? 0,
      ownedToyIds: (json['owned_toy_ids'] as List? ?? const [])
          .map((value) => value.toString())
          .toSet(),
      lastDailyTokenDate: json['last_daily_token_date']?.toString() ?? '',
      lastCheckInTokenDate:
          json['last_checkin_token_date']?.toString() ?? '',
      lastAction: json['last_action']?.toString() ?? 'Oren is ready.',
      mood: json['mood']?.toString() ?? 'Calm',
      energy: int.tryParse(json['energy']?.toString() ?? '') ?? 65,
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  OrenCareState copyWith({
    int? tokens,
    Set<String>? ownedToyIds,
    String? lastDailyTokenDate,
    String? lastCheckInTokenDate,
    String? lastAction,
    String? mood,
    int? energy,
    DateTime? updatedAt,
  }) {
    return OrenCareState(
      tokens: tokens ?? this.tokens,
      ownedToyIds: ownedToyIds ?? this.ownedToyIds,
      lastDailyTokenDate: lastDailyTokenDate ?? this.lastDailyTokenDate,
      lastCheckInTokenDate:
          lastCheckInTokenDate ?? this.lastCheckInTokenDate,
      lastAction: lastAction ?? this.lastAction,
      mood: mood ?? this.mood,
      energy: energy ?? this.energy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'tokens': tokens,
    'owned_toy_ids': ownedToyIds.toList(),
    'last_daily_token_date': lastDailyTokenDate,
    'last_checkin_token_date': lastCheckInTokenDate,
    'last_action': lastAction,
    'mood': mood,
    'energy': energy,
    'updated_at': updatedAt.toIso8601String(),
  };
}
