import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pixel_punch/features/royale/royale_config.dart';
import 'package:pixel_punch/game/models/game_enums.dart';
import 'package:pixel_punch/services/face_villain/face_cartoonizer.dart';
import 'package:pixel_punch/services/face_villain/villain_generator.dart';
import 'package:pixel_punch/services/game_state_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hex colours are #RRGGBB as the Unity side expects', () {
    expect(RoyaleConfigBuilder.hex(const Color(0xFF4CAF50)), '#4CAF50');
    expect(RoyaleConfigBuilder.hex(const Color(0x80FF0000)), '#FF0000');
  });

  test('face villains send their real photo crop (JPEG) to the 3D game', () {
    final photo = img.Image(width: 300, height: 300);
    img.fill(photo, color: img.ColorRgb8(30, 60, 120));
    img.fillCircle(photo, x: 150, y: 150, radius: 90, color: img.ColorRgb8(200, 150, 110));
    final face = cartoonizeFace(CartoonRequest(
      Uint8List.fromList(img.encodePng(photo)),
      const FaceBox(left: 60, top: 60, width: 180, height: 180),
    ));
    expect(img.decodeJpg(face.photoJpg)!.width, portraitSize);

    final villain = VillainGenerator.create(
      id: 'custom_1', face: face, name: 'Dr. Sam', title: 'T',
      archetype: 'speedster', zoneId: 'zone_office', zoneName: 'Office');
    final spec = RoyaleConfigBuilder.customVillain(villain);
    expect(spec['face'], base64Encode(face.photoJpg));
    expect(spec['archetype'], 'speedster');
    expect((spec['speed'] as double), inInclusiveRange(2.8, 7.0));
    expect(spec['taunts'], isNotEmpty);
  });

  test('match config carries every field MatchConfig.cs reads', () async {
    final gs = GameStateService();
    await gs.loadGameData();
    final v = gs.villains.first;
    final config = RoyaleConfigBuilder.build(
      role: RoyaleRole.join,
      joinCode: ' ab12cd ',
      playerName: 'Ali',
      heroId: 'hero_flash',
      heroColor: const Color(0xFFFFC107),
      villains: [RoyaleConfigBuilder.builtInVillain(v, gs.getDialogueProfile(v.dialogueProfileId!))],
      villainCount: 12,
      mapSize: 1600,
      firstPerson: true,
      seed: 42,
    );
    final decoded = jsonDecode(jsonEncode(config)) as Map<String, dynamic>;
    for (final key in [
      'role', 'joinCode', 'maxPlayers', 'seed', 'mapSize', 'villainCount',
      'startInFirstPerson', 'playerName', 'heroId', 'heroColor', 'villains',
    ]) {
      expect(decoded.containsKey(key), isTrue, reason: key);
    }
    expect(decoded['role'], 'join');
    expect(decoded['joinCode'], 'AB12CD');
    final villain = (decoded['villains'] as List).first as Map<String, dynamic>;
    expect(villain['name'], v.name);
    expect(villain['taunts'], isNotEmpty);
  });

  test('Unity match_over becomes a recorded match with XP', () async {
    final gs = GameStateService();
    await gs.loadGameData();
    final rewards = RoyaleResults.record(
      gs,
      {'victory': true, 'kills': 3, 'damage': 420, 'seconds': 300, 'villainsDefeated': 'villain_bug_phantom,custom_1'},
      {'role': 'host', 'heroId': 'hero_striker'},
    );
    expect(rewards.xpEarned, 150 + 3 * 30);
    expect(gs.matchHistory.first.mode, GameMode.squad);
    expect(gs.progress.isVillainDefeated('villain_bug_phantom'), isTrue);
  });
}
