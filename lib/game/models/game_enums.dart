/// Game mode (Solo/Duo/Squad).
enum GameMode {
  solo('Solo', '1v1', 1, 1),
  duo('Duo', '2v2', 2, 2),
  squad('Squad', '3v3', 3, 3);

  final String displayName;
  final String shortName;
  final int friendlyCount;
  final int enemyCount;

  const GameMode(this.displayName, this.shortName, this.friendlyCount, this.enemyCount);
}

/// Discovery lifecycle state for a villain.
enum DiscoveryState {
  unknown,
  rumored,
  located,
  encounterInitiated,
  battleActive,
  defeated,
  rewardClaimed,
  encounterCompleted;

  bool get isDiscovered => index >= DiscoveryState.located.index;
  bool get isDefeated => index >= DiscoveryState.defeated.index;
  bool get isCompleted => this == DiscoveryState.encounterCompleted;
}

/// AI state machine states.
enum AIState {
  idle,
  patrol,
  investigate,
  approach,
  follow,
  attack,
  defend,
  useSpecial,
  retreat,
  stunned,
  knockedOut;

  bool get canAct => this != knockedOut && this != stunned;
  bool get isAggressive => this == attack || this == useSpecial;
}

/// Fighter team allegiance.
enum Team {
  friendly,
  enemy;

  Team get opposite => this == friendly ? enemy : friendly;
}

/// Match outcome.
enum MatchOutcome {
  victory,
  defeat,
  draw,
  abandoned;
}

/// Fighter archetype.
enum Archetype {
  balanced,
  tank,
  speedster,
  heavyHitter,
  support,
  trickster;

  factory Archetype.fromString(String value) {
    return switch (value) {
      'balanced' => Archetype.balanced,
      'tank' => Archetype.tank,
      'speedster' => Archetype.speedster,
      'heavy_hitter' => Archetype.heavyHitter,
      'support' => Archetype.support,
      'trickster' => Archetype.trickster,
      _ => Archetype.balanced,
    };
  }

  String get displayName => switch (this) {
    Archetype.balanced => 'Balanced',
    Archetype.tank => 'Tank',
    Archetype.speedster => 'Speedster',
    Archetype.heavyHitter => 'Heavy Hitter',
    Archetype.support => 'Support',
    Archetype.trickster => 'Trickster',
  };
}
