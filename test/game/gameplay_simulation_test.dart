import 'dart:typed_data';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pixel_punch/game/components/villain_component.dart';
import 'package:pixel_punch/game/models/custom_villain.dart';
import 'package:pixel_punch/game/models/dialogue_data.dart';
import 'package:pixel_punch/game/models/game_enums.dart';
import 'package:pixel_punch/game/pixel_punch_game.dart';
import 'package:pixel_punch/services/face_villain/face_cartoonizer.dart';
import 'package:pixel_punch/services/face_villain/villain_generator.dart';
import 'package:pixel_punch/services/game_state_service.dart';

/// Plays whole matches headlessly with a simple bot to make sure the
/// game loop, AI, dialogue flow and win/lose detection all work together.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameStateService gs;

  setUpAll(() async {
    gs = GameStateService();
    await gs.loadGameData();
    expect(gs.isLoaded, isTrue);
  });

  CustomVillain makeFaceVillain() {
    final photo = img.Image(width: 300, height: 300);
    img.fill(photo, color: img.ColorRgb8(30, 60, 120));
    img.fillCircle(photo, x: 150, y: 150, radius: 90, color: img.ColorRgb8(200, 150, 110));
    final face = cartoonizeFace(CartoonRequest(
      Uint8List.fromList(img.encodePng(photo)),
      const FaceBox(left: 60, top: 60, width: 180, height: 180),
    ));
    return VillainGenerator.create(
      id: 'custom_sim',
      face: face,
      name: 'Dr. Sim',
      title: 'The Test Dummy',
      archetype: 'heavy_hitter',
      zoneId: 'zone_office',
      zoneName: 'Office',
    );
  }

  Future<({PixelPunchGame game, MatchOutcome? outcome, int dialogues})> playMatch(
    WidgetTester tester,
    GameMode mode, {
    List<CustomVillain> customs = const [],
    bool playerFights = true,
    bool startNextToVillain = false,
  }) async {
    final zone = gs.getZone('zone_office')!;
    final heroes = gs.heroes.take(mode.friendlyCount).toList();
    final villains = gs.villainsForMatch(zone.id, mode,
        customVillains: customs.map((c) => c.toFighterData()).toList(),
        featuredIds: customs.map((c) => c.id).toList());
    final profiles = Map<String, DialogueProfile>.from(gs.dialogueProfiles);
    for (final c in customs) {
      profiles[c.id] = c.toDialogueProfile();
    }

    late PixelPunchGame game;
    await tester.runAsync(() async {
      game = await initializeGame(() => PixelPunchGame(
            zoneData: zone,
            heroDataList: heroes,
            villainDataList: villains,
            abilities: {for (final a in gs.abilities) a.id: a},
            dialogueProfiles: profiles,
            mode: mode,
            villainFaces: {for (final c in customs) c.id: c.portraitPng},
            villainTraits: {for (final c in customs) c.id: c.traits},
            hapticsEnabled: false,
          ));
    });

    if (startNextToVillain) {
      game.player.position = game.villainComponents.first.position + Vector2(50, 0);
    }
    MatchOutcome? outcome;
    int dialogues = 0;
    game.onDialogue = (id, name, title, text, color) {
      dialogues++;
      expect(text, isNotEmpty);
      // Player reads the line and taps to continue.
      Future.microtask(game.dismissDialogue);
    };
    game.onGameOver = (o, dealt, taken, secs) => outcome = o;

    const dt = 1 / 30;
    for (int frame = 0; frame < 30 * 240 && outcome == null; frame++) {
      if (game.isInDialogue) game.dismissDialogue();
      final player = game.player;
      if (playerFights && !player.isKnockedOut) {
        final target = game.getNearestEnemy(player.position, Team.friendly);
        if (target != null) {
          final to = target.position - player.position;
          game.joystickDirection = to.length > 40 ? to.normalized() : Vector2.zero();
          if (to.length < 60) game.attackPressed = true;
          if (frame % 90 == 0) game.specialPressed = true;
          if (frame % 150 == 0) game.dodgePressed = true;
        }
      } else {
        game.joystickDirection = Vector2.zero();
      }
      game.update(dt);
      await tester.pump();
    }
    return (game: game, outcome: outcome, dialogues: dialogues);
  }

  for (final mode in GameMode.values) {
    testWidgets('a ${mode.displayName} match plays to a finish', (tester) async {
      final r = await playMatch(tester, mode);
      final g = r.game;
      // ignore: avoid_print
      print('${mode.name}: ${r.outcome} in ${g.matchTimer.toStringAsFixed(0)}s, '
          'dealt ${g.totalDamageDealt}, taken ${g.totalDamageTaken}');
      final state = [
        'player ${g.player.position} hp ${g.player.currentHealth}',
        for (final t in g.teammateComponents) 'mate ${t.position} hp ${t.currentHealth}',
        for (final v in g.villainComponents)
          'villain ${v.fighterData.id} ${v.position} hp ${v.currentHealth} combat ${v.isInCombat} found ${v.discovered}',
        'dialogue ${g.isInDialogue} timer ${g.matchTimer.toStringAsFixed(1)}',
      ].join(' | ');
      expect(r.outcome, isNotNull, reason: 'match never ended: $state');
      expect(r.game.villainComponents.length, mode.enemyCount);
      expect(r.game.teammateComponents.length, mode.friendlyCount - 1);
      expect(r.game.discoveredVillains, isNotEmpty);
      expect(r.dialogues, greaterThan(0), reason: 'discovery dialogue should show');
      expect(r.game.totalDamageDealt, greaterThan(0));
      if (r.outcome == MatchOutcome.victory) {
        expect(r.game.villainComponents.every((v) => v.isKnockedOut), isTrue);
        expect(r.game.defeatedVillains, isNotEmpty);
      } else {
        expect(r.game.player.isKnockedOut, isTrue);
      }
    });
  }

  testWidgets('villains attack an idle player and win', (tester) async {
    final r = await playMatch(tester, GameMode.solo,
        playerFights: false, startNextToVillain: true);
    expect(r.outcome, MatchOutcome.defeat);
    expect(r.game.totalDamageTaken, greaterThanOrEqualTo(r.game.player.maxHealth));
  });

  testWidgets('a face-generated villain spawns with its cartoon face and fights',
      (tester) async {
    final custom = makeFaceVillain();
    final r = await playMatch(tester, GameMode.solo, customs: [custom]);
    final villain = r.game.villainComponents.single;
    expect(villain.fighterData.id, 'custom_sim');
    expect(villain.look.face, isNotNull, reason: 'portrait should be decoded');
    expect(r.outcome, isNotNull);
  });

  testWidgets('fighters cannot walk through obstacles or leave the zone',
      (tester) async {
    final zone = gs.getZone('zone_office')!;
    late PixelPunchGame game;
    await tester.runAsync(() async {
      game = await initializeGame(() => PixelPunchGame(
            zoneData: zone,
            heroDataList: [gs.heroes.first],
            villainDataList: gs.villainsForMatch(zone.id, GameMode.solo),
            abilities: {for (final a in gs.abilities) a.id: a},
            dialogueProfiles: gs.dialogueProfiles,
            mode: GameMode.solo,
            hapticsEnabled: false,
          ));
    });
    final desk = zone.obstacles.first;
    // Start left of the desk and push right into it.
    final start = Vector2(desk.x - 30, desk.y + desk.height / 2);
    final moved = game.resolveMovement(start, Vector2(40, 0), 16);
    expect(moved.x, lessThanOrEqualTo(desk.x - 16 + 0.01),
        reason: 'desk should block horizontal movement');

    // Walking diagonally into a desk corner slides around it instead of sticking.
    var p = Vector2(desk.x - 20, desk.y + desk.height + 14);
    for (int i = 0; i < 60; i++) {
      p = game.resolveMovement(p, Vector2(3, -2), 16);
    }
    expect(p.y, lessThan(desk.y), reason: 'should slide past the corner');

    final edge = game.resolveMovement(Vector2(20, 20), Vector2(-100, -100), 16);
    expect(edge.x, greaterThanOrEqualTo(16));
    expect(edge.y, greaterThanOrEqualTo(16));
  });

  test('villain roster fills larger modes', () {
    final solo = gs.villainsForMatch('zone_office', GameMode.solo);
    final squad = gs.villainsForMatch('zone_office', GameMode.squad);
    expect(solo, hasLength(1));
    expect(squad, hasLength(3));
    expect(squad.map((v) => v.zoneId).toSet(), {'zone_office'});
  });

  test('VillainComponent exposes combat state', () {
    final data = gs.getVillainsForZone('zone_office').first;
    final v = VillainComponent(
      fighterData: data,
      team: Team.enemy,
      patrolRadius: 50,
    );
    expect(v.isInCombat, isFalse);
    expect(v.discovered, isFalse);
  });
}
