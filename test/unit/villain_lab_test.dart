import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pixel_punch/game/models/custom_villain.dart';
import 'package:pixel_punch/game/models/dialogue_data.dart';
import 'package:pixel_punch/game/models/game_enums.dart';
import 'package:pixel_punch/services/face_villain/face_cartoonizer.dart';
import 'package:pixel_punch/services/face_villain/villain_generator.dart';
import 'package:pixel_punch/services/game_state_service.dart';

Uint8List _fakeSelfie() {
  final image = img.Image(width: 400, height: 500);
  img.fill(image, color: img.ColorRgb8(40, 90, 160)); // background
  img.fillCircle(image, x: 200, y: 200, radius: 120, color: img.ColorRgb8(60, 40, 30)); // hair
  img.fillCircle(image, x: 200, y: 240, radius: 105, color: img.ColorRgb8(224, 172, 105)); // face
  img.fillCircle(image, x: 160, y: 220, radius: 10, color: img.ColorRgb8(20, 20, 20)); // eyes
  img.fillCircle(image, x: 240, y: 220, radius: 10, color: img.ColorRgb8(20, 20, 20));
  img.fillRect(image, x1: 0, y1: 420, x2: 400, y2: 500, color: img.ColorRgb8(200, 30, 30)); // shirt
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('Face cartoonizer', () {
    test('produces a round 256px portrait and measures the face', () {
      final result = cartoonizeFace(CartoonRequest(
        _fakeSelfie(),
        const FaceBox(
          left: 95,
          top: 135,
          width: 210,
          height: 210,
          leftEye: [240, 220],
          rightEye: [160, 220],
          smiling: 0.9,
          eyesOpen: 0.95,
        ),
      ));

      final portrait = img.decodePng(result.png)!;
      expect(portrait.width, portraitSize);
      expect(portrait.height, portraitSize);
      // Corners are cut away by the round mask.
      expect(portrait.getPixel(0, 0).a, 0);
      // Centre is opaque.
      expect(portrait.getPixel(128, 128).a, 255);

      expect(result.faceDetected, isTrue);
      expect(result.smiling, 0.9);
      // Skin tone sampled from the face should be warm (red > blue).
      final skin = result.skinTone;
      expect((skin >> 16) & 0xFF, greaterThan(skin & 0xFF));
      // Eyes are ordered left to right in the portrait.
      expect(result.leftEye[0], lessThan(result.rightEye[0]));
    });

    test('falls back to a centre crop when no face is detected', () {
      final result = cartoonizeFace(CartoonRequest(_fakeSelfie(), null));
      expect(result.faceDetected, isFalse);
      expect(img.decodePng(result.png)!.width, portraitSize);
    });

    test('rejects data that is not an image', () {
      expect(
        () => cartoonizeFace(CartoonRequest(Uint8List.fromList([1, 2, 3]), null)),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Villain generator', () {
    final face = cartoonizeFace(CartoonRequest(
      _fakeSelfie(),
      const FaceBox(left: 95, top: 135, width: 210, height: 210, smiling: 0.95),
    ));

    test('a big smile makes a trickster', () {
      expect(VillainGenerator.inferArchetype(face), 'trickster');
    });

    test('creates a playable villain with dialogue and round-trips through JSON', () {
      final villain = VillainGenerator.create(
        id: 'custom_test',
        face: face,
        name: VillainGenerator.suggestName('Sam', face.seed),
        title: 'The Tester',
        archetype: 'tank',
        zoneId: 'zone_office',
        zoneName: 'NexoVate Office District',
      );
      expect(villain.name, endsWith('Sam'));
      expect(villain.specialAbility, 'protective_shield');
      expect(villain.baseHealth, greaterThan(120));

      final fighter = villain.toFighterData();
      expect(fighter.isVillain, isTrue);
      expect(fighter.dialogueProfileId, 'custom_test');

      final profile = villain.toDialogueProfile();
      expect(profile.getLineForced(DialogueCategory.discovery), isNotNull);
      expect(profile.getLineForced(DialogueCategory.defeat), isNotNull);

      final copy = CustomVillain.fromJson(villain.toJson());
      expect(copy.name, villain.name);
      expect(copy.portraitPng, villain.portraitPng);
      expect(copy.traits.accentColor, villain.traits.accentColor);
      expect(copy.traits.leftEye, villain.traits.leftEye);
    });

    test('restyle recomputes stats for a new archetype', () {
      final base = VillainGenerator.create(
        id: 'custom_x',
        face: face,
        name: 'Evil Sam',
        title: 'T',
        archetype: 'tank',
        zoneId: 'zone_office',
        zoneName: 'Office',
      );
      final fast = VillainGenerator.restyle(base,
          name: 'Evil Sam', title: 'T', archetype: 'speedster', zoneId: 'zone_neon', zoneName: 'Neon');
      expect(fast.moveSpeed, greaterThan(base.moveSpeed));
      expect(fast.zoneId, 'zone_neon');
      expect(fast.portraitPng, base.portraitPng);
    });
  });

  group('Match setup and rewards', () {
    test('XP rewards victories and partial progress', () {
      expect(GameStateService.xpFor(MatchOutcome.victory, 2), 200);
      expect(GameStateService.xpFor(MatchOutcome.defeat, 1), 30);
    });

    test('unlock requirements are parsed', () {
      final gs = GameStateService();
      expect(gs.requirementMet(null), isTrue);
      expect(gs.requirementMet('Defeat 3 villains'), isFalse);
      expect(gs.requirementMet('Complete Zone 1'), isFalse);
      expect(gs.requirementMet('Something unknown'), isFalse);
    });
  });
}
