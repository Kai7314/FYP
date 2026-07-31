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
    required this.selectedToyId,
    required this.lastDailyTokenDate,
    required this.lastCheckInTokenDate,
    required this.lastAction,
    required this.mood,
    required this.energy,
    required this.updatedAt,
  });

  final int tokens;
  final Set<String> ownedToyIds;
  final String selectedToyId;
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
      selectedToyId: '',
      lastDailyTokenDate: '',
      lastCheckInTokenDate: '',
      lastAction: 'Oren is ready for today.',
      mood: 'Calm',
      energy: 65,
      updatedAt: DateTime.now(),
    );
  }

  factory OrenCareState.fromJson(Map<String, dynamic> json) {
    final ownedToyIds = (json['owned_toy_ids'] as List? ?? const [])
        .map((value) => value.toString())
        .toSet();
    final savedSelection = json['selected_toy_id']?.toString() ?? '';

    return OrenCareState(
      tokens: int.tryParse(json['tokens']?.toString() ?? '') ?? 0,
      ownedToyIds: ownedToyIds,
      selectedToyId: ownedToyIds.contains(savedSelection)
          ? savedSelection
          : ownedToyIds.isEmpty
          ? ''
          : ownedToyIds.first,
      lastDailyTokenDate: json['last_daily_token_date']?.toString() ?? '',
      lastCheckInTokenDate: json['last_checkin_token_date']?.toString() ?? '',
      lastAction: json['last_action']?.toString() ?? 'Oren is ready.',
      mood: json['mood']?.toString() ?? 'Calm',
      energy: (int.tryParse(json['energy']?.toString() ?? '') ?? 65)
          .clamp(0, 100)
          .toInt(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  OrenCareState copyWith({
    int? tokens,
    Set<String>? ownedToyIds,
    String? selectedToyId,
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
      selectedToyId: selectedToyId ?? this.selectedToyId,
      lastDailyTokenDate: lastDailyTokenDate ?? this.lastDailyTokenDate,
      lastCheckInTokenDate: lastCheckInTokenDate ?? this.lastCheckInTokenDate,
      lastAction: lastAction ?? this.lastAction,
      mood: mood ?? this.mood,
      energy: energy ?? this.energy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'tokens': tokens,
    'owned_toy_ids': ownedToyIds.toList(),
    'selected_toy_id': selectedToyId,
    'last_daily_token_date': lastDailyTokenDate,
    'last_checkin_token_date': lastCheckInTokenDate,
    'last_action': lastAction,
    'mood': mood,
    'energy': energy,
    'updated_at': updatedAt.toIso8601String(),
  };
}
