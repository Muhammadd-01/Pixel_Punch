import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_punch/core/config/game_config.dart';
import 'package:pixel_punch/game/models/ability_data.dart';
import 'package:pixel_punch/game/models/fighter_data.dart';
import 'package:pixel_punch/game/models/game_enums.dart';
import 'package:pixel_punch/game/models/match_result.dart';
import 'package:pixel_punch/game/models/zone_data.dart';

void main() {
  group('GameConfig Tests', () {
    test('Default values are positive and balanced', () {
      expect(GameConfig.defaultZoneWidth, greaterThan(0));
      expect(GameConfig.defaultZoneHeight, greaterThan(0));
      expect(GameConfig.defaultAttackDamage, greaterThan(0));
      expect(GameConfig.defaultAttackRange, greaterThan(0));
      expect(GameConfig.defaultHealth, equals(100));
      expect(GameConfig.xpPerVillainDefeat, equals(50));
    });
  });

  group('FighterData Model Tests', () {
    test('FighterData correctly parses hero JSON', () {
      final json = {
        'id': 'hero_striker',
        'name': 'Striker',
        'title': 'The Balanced Warrior',
        'archetype': 'balanced',
        'biography': 'A well-rounded fighter.',
        'baseHealth': 100,
        'moveSpeed': 150.0,
        'attackDamage': 15,
        'attackRange': 45.0,
        'attackCooldown': 0.8,
        'defense': 10,
        'specialAbility': 'charged_strike',
        'specialCooldown': 5.0,
        'color': '0xFF4CAF50',
        'unlocked': true,
        'unlockRequirement': null,
      };

      final fighter = FighterData.fromJson(json);
      expect(fighter.id, equals('hero_striker'));
      expect(fighter.name, equals('Striker'));
      expect(fighter.baseHealth, equals(100));
      expect(fighter.moveSpeed, equals(150.0));
      expect(fighter.isVillain, isFalse);
      expect(fighter.unlocked, isTrue);

      final outJson = fighter.toJson();
      expect(outJson['id'], equals('hero_striker'));
      expect(outJson['baseHealth'], equals(100));
    });

    test('FighterData correctly parses villain JSON with patrol data', () {
      final json = {
        'id': 'villain_bug_phantom',
        'name': 'Bug Phantom',
        'title': 'The Glitch Trickster',
        'biography': 'A mischievous entity.',
        'zoneId': 'zone_office',
        'archetype': 'trickster',
        'baseHealth': 80,
        'moveSpeed': 170.0,
        'attackDamage': 10,
        'attackRange': 40.0,
        'attackCooldown': 0.7,
        'defense': 5,
        'specialAbility': 'evasive_burst',
        'specialCooldown': 4.0,
        'difficultyTier': 1,
        'color': '0xFF8BC34A',
        'spawnX': 600.0,
        'spawnY': 400.0,
        'patrolRadius': 100.0,
        'discoveryType': 'area_enter',
        'dialogueProfileId': 'bug_phantom',
      };

      final villain = FighterData.fromJson(json, isVillain: true);
      expect(villain.isVillain, isTrue);
      expect(villain.zoneId, equals('zone_office'));
      expect(villain.spawnX, equals(600.0));
      expect(villain.patrolRadius, equals(100.0));
    });
  });

  group('ZoneData Model Tests', () {
    test('ZoneData parses locations and obstacles correctly', () {
      final json = {
        'id': 'zone_office',
        'name': 'NexoVate Office District',
        'description': 'Stylized cartoon office.',
        'theme': 'office',
        'unlocked': true,
        'recommendedDifficulty': 'Easy',
        'width': 1600.0,
        'height': 1200.0,
        'backgroundColor': '0xFFE8E0D4',
        'villainIds': ['villain_bug_phantom'],
        'locations': [
          {'name': 'Reception', 'x': 100.0, 'y': 600.0, 'width': 200.0, 'height': 150.0}
        ],
        'obstacles': [
          {'type': 'desk', 'x': 450.0, 'y': 450.0, 'width': 60.0, 'height': 40.0}
        ],
        'playerSpawn': {'x': 150.0, 'y': 650.0}
      };

      final zone = ZoneData.fromJson(json);
      expect(zone.id, equals('zone_office'));
      expect(zone.locations.length, equals(1));
      expect(zone.locations.first.name, equals('Reception'));
      expect(zone.obstacles.length, equals(1));
      expect(zone.obstacles.first.type, equals('desk'));
      expect(zone.playerSpawnX, equals(150.0));
    });
  });

  group('AbilityData Model Tests', () {
    test('AbilityType enums map string correctly', () {
      expect(AbilityType.fromString('damage'), equals(AbilityType.damage));
      expect(AbilityType.fromString('shield'), equals(AbilityType.shield));
      expect(AbilityType.fromString('dash'), equals(AbilityType.dash));
      expect(AbilityType.fromString('heal'), equals(AbilityType.heal));
      expect(AbilityType.fromString('area_damage'), equals(AbilityType.areaDamage));
      expect(AbilityType.fromString('evasion'), equals(AbilityType.evasion));
    });

    test('AbilityData parses accurately', () {
      final json = {
        'id': 'charged_strike',
        'name': 'Charged Strike',
        'description': 'Channel energy for 2x strike.',
        'archetype': 'balanced',
        'damageMultiplier': 2.0,
        'range': 55.0,
        'duration': 0.0,
        'cooldown': 5.0,
        'healAmount': 0,
        'type': 'damage'
      };

      final ability = AbilityData.fromJson(json);
      expect(ability.damageMultiplier, equals(2.0));
      expect(ability.type, equals(AbilityType.damage));
      expect(ability.cooldown, equals(5.0));
    });
  });

  group('MatchResult Model Tests', () {
    test('MatchResult serialization roundtrip', () {
      final now = DateTime.now();
      final match = MatchResult(
        matchId: 'match_123',
        mode: GameMode.solo,
        zoneId: 'zone_office',
        playerCharacterIds: ['hero_striker'],
        enemyIds: ['villain_bug_phantom'],
        outcome: MatchOutcome.victory,
        durationSeconds: 45,
        damageDealt: 120,
        damageTaken: 30,
        xpEarned: 50,
        completedAt: now,
      );

      final json = match.toJson();
      final parsed = MatchResult.fromJson(json);

      expect(parsed.matchId, equals('match_123'));
      expect(parsed.mode, equals(GameMode.solo));
      expect(parsed.outcome, equals(MatchOutcome.victory));
      expect(parsed.xpEarned, equals(50));
      expect(parsed.damageDealt, equals(120));
    });
  });
}
