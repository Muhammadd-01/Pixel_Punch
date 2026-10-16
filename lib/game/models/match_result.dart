import 'game_enums.dart';

/// Result of a completed match.
class MatchResult {
  final String matchId;
  final GameMode mode;
  final String zoneId;
  final List<String> playerCharacterIds;
  final List<String> enemyIds;
  final MatchOutcome outcome;
  final int durationSeconds;
  final int damageDealt;
  final int damageTaken;
  final int xpEarned;
  final DateTime completedAt;

  const MatchResult({
    required this.matchId,
    required this.mode,
    required this.zoneId,
    required this.playerCharacterIds,
    required this.enemyIds,
    required this.outcome,
    required this.durationSeconds,
    required this.damageDealt,
    required this.damageTaken,
    required this.xpEarned,
    required this.completedAt,
  });

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'mode': mode.name,
    'zoneId': zoneId,
    'playerCharacterIds': playerCharacterIds,
    'enemyIds': enemyIds,
    'outcome': outcome.name,
    'durationSeconds': durationSeconds,
    'damageDealt': damageDealt,
    'damageTaken': damageTaken,
    'xpEarned': xpEarned,
    'completedAt': completedAt.toIso8601String(),
  };

  factory MatchResult.fromJson(Map<String, dynamic> json) {
    return MatchResult(
      matchId: json['matchId'] as String,
      mode: GameMode.values.byName(json['mode'] as String),
      zoneId: json['zoneId'] as String,
      playerCharacterIds: (json['playerCharacterIds'] as List).cast<String>(),
      enemyIds: (json['enemyIds'] as List).cast<String>(),
      outcome: MatchOutcome.values.byName(json['outcome'] as String),
      durationSeconds: json['durationSeconds'] as int,
      damageDealt: json['damageDealt'] as int,
      damageTaken: json['damageTaken'] as int,
      xpEarned: json['xpEarned'] as int,
      completedAt: DateTime.parse(json['completedAt'] as String),
    );
  }
}
