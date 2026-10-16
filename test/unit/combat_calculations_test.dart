import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_punch/game/components/fighter_base.dart';
import 'package:pixel_punch/game/models/ability_data.dart';
import 'package:pixel_punch/game/models/fighter_data.dart';
import 'package:pixel_punch/game/models/game_enums.dart';

class TestFighter extends FighterBase {
  TestFighter({
    required super.fighterData,
    required super.team,
    super.abilityData,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Combat Calculations Tests', () {
    late FighterData heroData;
    late AbilityData shieldAbility;
    late TestFighter fighter;

    setUp(() {
      heroData = const FighterData(
        id: 'hero_test',
        name: 'Test Hero',
        title: 'Tester',
        biography: 'Test bio',
        archetype: 'tank',
        baseHealth: 100,
        moveSpeed: 100.0,
        attackDamage: 15,
        attackRange: 45.0,
        attackCooldown: 1.0,
        defense: 10,
        specialAbility: 'protective_shield',
        specialCooldown: 8.0,
        color: Color(0xFF2196F3),
      );

      shieldAbility = const AbilityData(
        id: 'protective_shield',
        name: 'Shield',
        description: 'Blocks damage',
        archetype: 'tank',
        damageMultiplier: 0.0,
        range: 0.0,
        duration: 3.0,
        cooldown: 8.0,
        healAmount: 0,
        type: AbilityType.shield,
      );

      fighter = TestFighter(
        fighterData: heroData,
        team: Team.friendly,
        abilityData: shieldAbility,
      );
    });

    test('Damage calculation subtracts defense with minimum 1 damage', () {
      // Raw damage 25, defense 10 -> effective damage 15
      final dealt1 = fighter.takeDamage(25);
      expect(dealt1, equals(15));
      expect(fighter.currentHealth, equals(85));

      // Reset invulnerability for testing
      fighter.isInvulnerable = false;

      // Raw damage 5, defense 10 -> clamped to minimum 1 damage
      final dealt2 = fighter.takeDamage(5);
      expect(dealt2, equals(1));
      expect(fighter.currentHealth, equals(84));
    });

    test('Shield reduces incoming damage by 80%', () {
      fighter.isShielded = true;
      fighter.isInvulnerable = false;

      // Raw damage 50 with shield -> 50 * 0.2 = 10 effective damage
      final dealt = fighter.takeDamage(50);
      expect(dealt, equals(10));
      expect(fighter.currentHealth, equals(90));
    });

    test('Invulnerability completely ignores damage', () {
      fighter.isInvulnerable = true;
      final dealt = fighter.takeDamage(50);
      expect(dealt, equals(0));
      expect(fighter.currentHealth, equals(100));
    });

    test('Fighter is knocked out when health reaches 0 and cannot take further damage', () {
      fighter.isInvulnerable = false;
      fighter.takeDamage(200);

      expect(fighter.currentHealth, equals(0));
      expect(fighter.isKnockedOut, isTrue);
      expect(fighter.canAttack, isFalse);
      expect(fighter.canUseSpecial, isFalse);

      // Subsequent hits to knocked-out fighter return 0
      final dealt = fighter.takeDamage(50);
      expect(dealt, equals(0));
    });

    test('Healing restores health up to maxHealth and not beyond', () {
      fighter.isInvulnerable = false;
      fighter.takeDamage(50); // Health now 60
      expect(fighter.currentHealth, equals(60));

      fighter.heal(20);
      expect(fighter.currentHealth, equals(80));

      // Healing beyond maxHealth (100) should clamp to 100
      fighter.heal(50);
      expect(fighter.currentHealth, equals(100));
    });

    test('Knocked out fighters cannot be healed', () {
      fighter.isInvulnerable = false;
      fighter.takeDamage(200);
      expect(fighter.isKnockedOut, isTrue);

      fighter.heal(50);
      expect(fighter.currentHealth, equals(0));
      expect(fighter.isKnockedOut, isTrue);
    });

    test('Special ability cooldown progress calculates from 0.0 to 1.0', () {
      expect(fighter.specialCooldownProgress, equals(1.0));

      fighter.specialCooldownTimer = 4.0; // Half of 8.0 cooldown
      expect(fighter.specialCooldownProgress, closeTo(0.5, 0.01));

      fighter.specialCooldownTimer = 0.0;
      expect(fighter.specialCooldownProgress, equals(1.0));
    });
  });
}
