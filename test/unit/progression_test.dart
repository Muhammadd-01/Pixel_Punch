import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_punch/game/models/game_enums.dart';
import 'package:pixel_punch/game/models/player_progress.dart';

void main() {
  group('PlayerProgress Progression Tests', () {
    late PlayerProgress progress;

    setUp(() {
      progress = PlayerProgress();
    });

    test('Initial progress state starts at level 1 with default unlocks', () {
      expect(progress.playerLevel, equals(1));
      expect(progress.totalXp, equals(0));
      expect(progress.wins, equals(0));
      expect(progress.losses, equals(0));
      expect(progress.unlockedZones.containsKey('zone_office'), isTrue);
      expect(progress.unlockedCharacters.contains('hero_striker'), isTrue);
      expect(progress.unlockedCharacters.contains('hero_bulwark'), isTrue);
      expect(progress.unlockedCharacters.contains('hero_flash'), isTrue);
    });

    test('Adding XP calculates levels correctly', () {
      // Level 1 requires 1 * 200 = 200 XP to level up
      expect(progress.xpForNextLevel, equals(200));

      progress.addXp(50);
      expect(progress.playerLevel, equals(1));
      expect(progress.totalXp, equals(50));
      expect(progress.levelProgress, closeTo(0.25, 0.01));

      // Add 250 XP -> Total 300 XP -> Level 2 with 100 XP remaining
      progress.addXp(250);
      expect(progress.playerLevel, equals(2));
      expect(progress.totalXp, equals(100));
      // Level 2 requires 2 * 200 = 400 XP
      expect(progress.xpForNextLevel, equals(400));
    });

    test('Record matches updates wins, losses, and total matches', () {
      progress.recordMatch(MatchOutcome.victory);
      expect(progress.totalMatches, equals(1));
      expect(progress.wins, equals(1));
      expect(progress.losses, equals(0));

      progress.recordMatch(MatchOutcome.defeat);
      expect(progress.totalMatches, equals(2));
      expect(progress.wins, equals(1));
      expect(progress.losses, equals(1));
    });

    test('Villain discovery lifecycle state advances and never regresses', () {
      progress.updateVillainState('villain_bug_phantom', DiscoveryState.located);
      expect(progress.villainStates['villain_bug_phantom'], equals(DiscoveryState.located));
      expect(progress.villainStates['villain_bug_phantom']!.isDiscovered, isTrue);
      expect(progress.isVillainDefeated('villain_bug_phantom'), isFalse);

      // Advance to defeated
      progress.updateVillainState('villain_bug_phantom', DiscoveryState.defeated);
      expect(progress.isVillainDefeated('villain_bug_phantom'), isTrue);

      // Attempt to regress back to located -> should NOT regress
      progress.updateVillainState('villain_bug_phantom', DiscoveryState.located);
      expect(progress.villainStates['villain_bug_phantom'], equals(DiscoveryState.defeated));
    });

    test('Duplicate reward claim is prevented', () {
      expect(progress.isRewardClaimed('reward_boss_office'), isFalse);

      final firstClaim = progress.claimReward('reward_boss_office');
      expect(firstClaim, isTrue);
      expect(progress.isRewardClaimed('reward_boss_office'), isTrue);

      // Second claim attempt with the same ID must return false
      final secondClaim = progress.claimReward('reward_boss_office');
      expect(secondClaim, isFalse);
    });

    test('JSON serialization roundtrip preserves state', () {
      progress.playerLevel = 4;
      progress.totalXp = 150;
      progress.wins = 12;
      progress.losses = 3;
      progress.updateVillainState('villain_captain_deadline', DiscoveryState.defeated);
      progress.claimReward('reward_1');

      final json = progress.toJson();
      final restored = PlayerProgress.fromJson(json);

      expect(restored.playerLevel, equals(4));
      expect(restored.totalXp, equals(150));
      expect(restored.wins, equals(12));
      expect(restored.losses, equals(3));
      expect(restored.isVillainDefeated('villain_captain_deadline'), isTrue);
      expect(restored.isRewardClaimed('reward_1'), isTrue);
    });
  });
}
