import 'dart:convert';
import 'dart:ui';
import 'package:uuid/uuid.dart';
import '../../game/models/custom_villain.dart';
import '../../game/models/fighter_data.dart';
import '../../game/models/dialogue_data.dart';
import '../../game/models/game_enums.dart';
import '../../game/models/match_result.dart';
import '../../services/game_state_service.dart';

/// How the player wants to enter the 3D battle royale.
enum RoyaleRole { offline, host, join }

/// Builds the JSON that the Unity game's GameBridge.StartMatch expects
/// (see unity/PixelPunch3D/Assets/PixelPunch/Scripts/Core/MatchConfig.cs).
class RoyaleConfigBuilder {
  RoyaleConfigBuilder._();

  static String hex(Color c) {
    final argb = c.toARGB32();
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  /// Built-in villain → 3D spec (2D pixel speeds become metres/second).
  static Map<String, dynamic> builtInVillain(FighterData v, DialogueProfile? profile) => {
        'id': v.id,
        'name': v.name,
        'title': v.title,
        'archetype': v.archetype,
        'color': hex(v.color),
        'health': v.baseHealth,
        'attack': v.attackDamage,
        'defense': v.defense,
        'speed': (v.moveSpeed / 38).clamp(2.8, 7.0),
        'face': '',
        'taunts': profile?.lines[DialogueCategory.combatTaunt] ?? const <String>[],
      };

  /// Face-generated villain → 3D spec with the real face photo for the head.
  static Map<String, dynamic> customVillain(CustomVillain v) => {
        'id': v.id,
        'name': v.name,
        'title': v.title,
        'archetype': v.archetype,
        'color': hex(v.traits.accentColor),
        'skin': hex(v.traits.skinTone),
        'hair': hex(v.traits.hairColor),
        'health': v.baseHealth,
        'attack': v.attackDamage,
        'defense': v.defense,
        'speed': (v.moveSpeed / 38).clamp(2.8, 7.0),
        'face': base64Encode(v.facePhoto ?? v.portraitPng),
        'taunts': v.dialogue['combat_taunt'] ?? const <String>[],
      };

  static Map<String, dynamic> build({
    required RoyaleRole role,
    String joinCode = '',
    required String playerName,
    required String heroId,
    required Color heroColor,
    required List<Map<String, dynamic>> villains,
    required int villainCount,
    required double mapSize,
    required bool firstPerson,
    int maxPlayers = 4,
    int? seed,
  }) =>
      {
        'role': role.name,
        'joinCode': joinCode.trim().toUpperCase(),
        'maxPlayers': maxPlayers,
        'seed': seed ?? DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
        'mapSize': mapSize,
        'villainCount': villainCount,
        'startInFirstPerson': firstPerson,
        'playerName': playerName,
        'heroId': heroId,
        'heroColor': hex(heroColor),
        'villains': villains,
      };
}

/// Turns the Unity "match_over" message into a recorded match + XP.
class RoyaleResults {
  RoyaleResults._();

  static MatchResult fromUnity(Map<String, dynamic> data, Map<String, dynamic> config) {
    final victory = data['victory'] == true;
    final kills = (data['kills'] as num?)?.toInt() ?? 0;
    final defeated = (data['villainsDefeated'] as String? ?? '')
        .split(',')
        .where((s) => s.isNotEmpty)
        .toList();
    return MatchResult(
      matchId: const Uuid().v4(),
      mode: config['role'] == 'offline' ? GameMode.solo : GameMode.squad,
      zoneId: 'royale_island',
      playerCharacterIds: [config['heroId'] as String? ?? 'hero_striker'],
      enemyIds: defeated,
      outcome: victory ? MatchOutcome.victory : MatchOutcome.defeat,
      durationSeconds: (data['seconds'] as num?)?.toInt() ?? 0,
      damageDealt: (data['damage'] as num?)?.toInt() ?? 0,
      damageTaken: 0,
      xpEarned: (victory ? 150 : 25) + kills * 30,
      completedAt: DateTime.now(),
    );
  }

  static MatchRewards record(GameStateService gs, Map<String, dynamic> data, Map<String, dynamic> config) {
    final result = fromUnity(data, config);
    return gs.applyMatchResult(result, defeatedIds: result.enemyIds);
  }
}
