import 'game_enums.dart';

/// Tracks the player's local progression.
class PlayerProgress {
  int playerLevel;
  int totalXp;
  int totalMatches;
  int wins;
  int losses;
  Map<String, DiscoveryState> villainStates;
  Map<String, bool> unlockedZones;
  Set<String> unlockedCharacters;
  Set<String> claimedRewards;
  DateTime lastUpdated;

  PlayerProgress({
    this.playerLevel = 1,
    this.totalXp = 0,
    this.totalMatches = 0,
    this.wins = 0,
    this.losses = 0,
    Map<String, DiscoveryState>? villainStates,
    Map<String, bool>? unlockedZones,
    Set<String>? unlockedCharacters,
    Set<String>? claimedRewards,
    DateTime? lastUpdated,
  })  : villainStates = villainStates ?? {},
        unlockedZones = unlockedZones ?? {'zone_office': true},
        unlockedCharacters = unlockedCharacters ?? {'hero_striker', 'hero_bulwark', 'hero_flash'},
        claimedRewards = claimedRewards ?? {},
        lastUpdated = lastUpdated ?? DateTime.now();

  int get xpForNextLevel => playerLevel * 200;
  double get levelProgress => totalXp / xpForNextLevel;

  void addXp(int amount) {
    totalXp += amount;
    while (totalXp >= xpForNextLevel) {
      totalXp -= xpForNextLevel;
      playerLevel++;
    }
    lastUpdated = DateTime.now();
  }

  void recordMatch(MatchOutcome outcome) {
    totalMatches++;
    if (outcome == MatchOutcome.victory) wins++;
    if (outcome == MatchOutcome.defeat) losses++;
    lastUpdated = DateTime.now();
  }

  void updateVillainState(String villainId, DiscoveryState state) {
    final current = villainStates[villainId];
    // Only advance the state, never regress
    if (current == null || state.index > current.index) {
      villainStates[villainId] = state;
      lastUpdated = DateTime.now();
    }
  }

  bool isVillainDefeated(String villainId) {
    return villainStates[villainId]?.isDefeated ?? false;
  }

  bool isRewardClaimed(String rewardId) {
    return claimedRewards.contains(rewardId);
  }

  bool claimReward(String rewardId) {
    if (claimedRewards.contains(rewardId)) return false;
    claimedRewards.add(rewardId);
    lastUpdated = DateTime.now();
    return true;
  }

  Map<String, dynamic> toJson() => {
    'playerLevel': playerLevel,
    'totalXp': totalXp,
    'totalMatches': totalMatches,
    'wins': wins,
    'losses': losses,
    'villainStates': villainStates.map((k, v) => MapEntry(k, v.name)),
    'unlockedZones': unlockedZones,
    'unlockedCharacters': unlockedCharacters.toList(),
    'claimedRewards': claimedRewards.toList(),
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory PlayerProgress.fromJson(Map<String, dynamic> json) {
    return PlayerProgress(
      playerLevel: json['playerLevel'] as int? ?? 1,
      totalXp: json['totalXp'] as int? ?? 0,
      totalMatches: json['totalMatches'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      villainStates: (json['villainStates'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, DiscoveryState.values.byName(v as String)),
      ),
      unlockedZones: (json['unlockedZones'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v as bool),
      ),
      unlockedCharacters: (json['unlockedCharacters'] as List?)?.cast<String>().toSet(),
      claimedRewards: (json['claimedRewards'] as List?)?.cast<String>().toSet(),
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : null,
    );
  }
}
