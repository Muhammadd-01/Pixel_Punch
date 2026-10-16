import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_punch/game/dialogue/dialogue_manager.dart';
import 'package:pixel_punch/game/models/dialogue_data.dart';

void main() {
  group('Dialogue System Tests', () {
    late DialogueProfile profile;

    setUp(() {
      profile = DialogueProfile(
        villainId: 'bug_phantom',
        lines: {
          DialogueCategory.discovery: [
            'Oh, look who found my little bug lab!',
            'Another debugger?'
          ],
          DialogueCategory.encounterIntro: [
            'Ready to crash? Let us see how you handle my exceptions!'
          ],
          DialogueCategory.combatTaunt: [
            'That was a feature!',
            '404: Your attack not found!'
          ],
          DialogueCategory.victory: [
            'Bug report: RESOLVED.'
          ],
          DialogueCategory.defeat: [
            'Stack overflow... I am going down...'
          ],
        },
      );
    });

    test('getLineForced always returns a valid line ignoring cooldown', () {
      final line1 = profile.getLineForced(DialogueCategory.discovery);
      expect(line1, isNotNull);
      expect(profile.lines[DialogueCategory.discovery]!.contains(line1), isTrue);

      // Call immediately again - should still return a line
      final line2 = profile.getLineForced(DialogueCategory.discovery);
      expect(line2, isNotNull);
    });

    test('getLine respects cooldown for combat taunts', () {
      final line1 = profile.getLine(DialogueCategory.combatTaunt, cooldownSeconds: 5.0);
      expect(line1, isNotNull);

      // Call immediately with 5s cooldown should return null
      final line2 = profile.getLine(DialogueCategory.combatTaunt, cooldownSeconds: 5.0);
      expect(line2, isNull);
    });

    test('DialogueManager triggers callback with correct metadata', () {
      String? triggeredVillainId;
      String? triggeredText;

      final manager = DialogueManager(
        profiles: {'bug_phantom': profile},
        onShowDialogue: (villainId, name, title, text, color) {
          triggeredVillainId = villainId;
          triggeredText = text;
        },
      );

      final success = manager.triggerDialogue(
        'bug_phantom',
        DialogueCategory.discovery,
        'Bug Phantom',
        'The Glitch Trickster',
        const Color(0xFF8BC34A),
      );

      expect(success, isTrue);
      expect(triggeredVillainId, equals('bug_phantom'));
      expect(triggeredText, isNotNull);
      expect(manager.isShowingDialogue, isTrue);

      // While showing dialogue, subsequent triggers should be blocked
      final blocked = manager.triggerDialogue(
        'bug_phantom',
        DialogueCategory.combatTaunt,
        'Bug Phantom',
        'The Glitch Trickster',
        const Color(0xFF8BC34A),
      );
      expect(blocked, isFalse);

      // After dismissing, dialogue state clears
      manager.dismissDialogue();
      expect(manager.isShowingDialogue, isFalse);
    });
  });
}
