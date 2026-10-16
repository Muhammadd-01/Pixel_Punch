import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Draggable;
import 'models/fighter_data.dart';
import 'models/zone_data.dart';
import 'models/ability_data.dart';
import 'models/dialogue_data.dart';
import 'models/game_enums.dart';
import 'components/player_component.dart';
import 'components/villain_component.dart';
import 'components/zone_component.dart';
import 'combat/combat_manager.dart';
import 'dialogue/dialogue_manager.dart';
import '../core/config/game_config.dart';

/// Callback types for game-to-Flutter communication.
typedef DialogueCallback = void Function(
    String villainId, String name, String title, String text, Color color);
typedef GameOverCallback = void Function(
    MatchOutcome outcome, int damageDealt, int damageTaken, int durationSeconds);
typedef DiscoveryCallback = void Function(
    String villainId, String name, String title);

class PixelPunchGame extends FlameGame with HasCollisionDetection {
  final ZoneData zoneData;
  final List<FighterData> heroDataList;
  final List<FighterData> villainDataList;
  final Map<String, AbilityData> abilities;
  final Map<String, DialogueProfile> dialogueProfiles;
  final GameMode mode;

  // Callbacks to Flutter overlay
  DialogueCallback? onDialogue;
  GameOverCallback? onGameOver;
  DiscoveryCallback? onVillainDiscovered;
  VoidCallback? onDialogueDismissed;

  // Core managers
  late CombatManager combatManager;
  late DialogueManager dialogueManager;

  // Components
  late PlayerComponent player;
  List<VillainComponent> villainComponents = [];
  List<PlayerComponent> teammateComponents = [];
  late ZoneComponent zoneComponent;

  // State
  bool isPaused = false;
  bool isGameOver = false;
  bool isInDialogue = false;
  bool isExplorationMode = true;
  double matchTimer = 0;
  int totalDamageDealt = 0;
  int totalDamageTaken = 0;
  final Set<String> discoveredVillains = {};
  final Set<String> defeatedVillains = {};

  // Joystick state (set from Flutter overlay)
  Vector2 joystickDirection = Vector2.zero();
  bool attackPressed = false;
  bool specialPressed = false;
  bool dodgePressed = false;

  PixelPunchGame({
    required this.zoneData,
    required this.heroDataList,
    required this.villainDataList,
    required this.abilities,
    required this.dialogueProfiles,
    required this.mode,
  });

  @override
  Color backgroundColor() => zoneData.backgroundColor;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Initialize managers
    combatManager = CombatManager(game: this);
    dialogueManager = DialogueManager(
      profiles: dialogueProfiles,
      onShowDialogue: (villainId, name, title, text, color) {
        isInDialogue = true;
        onDialogue?.call(villainId, name, title, text, color);
      },
    );

    // Create zone
    zoneComponent = ZoneComponent(zoneData: zoneData);
    await world.add(zoneComponent);

    // Create player
    final heroData = heroDataList.first;
    player = PlayerComponent(
      fighterData: heroData,
      team: Team.friendly,
      isPlayerControlled: true,
      abilityData: abilities[heroData.specialAbility],
    );
    player.position = Vector2(zoneData.playerSpawnX, zoneData.playerSpawnY);
    await world.add(player);

    // Create AI teammates (for Duo/Squad)
    for (int i = 1; i < heroDataList.length && i < mode.friendlyCount; i++) {
      final data = heroDataList[i];
      final teammate = PlayerComponent(
        fighterData: data,
        team: Team.friendly,
        isPlayerControlled: false,
        abilityData: abilities[data.specialAbility],
      );
      teammate.position = Vector2(
        zoneData.playerSpawnX + (i * 60),
        zoneData.playerSpawnY,
      );
      teammateComponents.add(teammate);
      await world.add(teammate);
    }

    // Create villains
    for (final villainData in villainDataList) {
      final villain = VillainComponent(
        fighterData: villainData,
        team: Team.enemy,
        abilityData: abilities[villainData.specialAbility],
        dialogueProfile: dialogueProfiles[villainData.dialogueProfileId],
        patrolRadius: villainData.patrolRadius ?? 100.0,
      );
      villain.position = Vector2(
        villainData.spawnX ?? 400,
        villainData.spawnY ?? 400,
      );
      villainComponents.add(villain);
      await world.add(villain);
    }

    // Setup camera to follow player
    camera.follow(player, maxSpeed: 300, snap: true);
    camera.viewfinder.zoom = 1.5;
  }

  @override
  void update(double dt) {
    if (isPaused || isGameOver || isInDialogue) return;
    super.update(dt);

    matchTimer += dt;

    // Update player input
    player.inputDirection = joystickDirection;
    if (attackPressed) {
      player.performAttack(this);
      attackPressed = false;
    }
    if (specialPressed) {
      player.performSpecial(this);
      specialPressed = false;
    }
    if (dodgePressed) {
      player.performDodge();
      dodgePressed = false;
    }

    // Check for villain discovery
    _checkVillainDiscovery();

    // Update combat
    combatManager.update(dt);

    // Check game over conditions
    _checkGameOver();
  }

  void _checkVillainDiscovery() {
    for (final villain in villainComponents) {
      if (discoveredVillains.contains(villain.fighterData.id)) continue;
      if (villain.isKnockedOut) continue;

      final distance = player.position.distanceTo(villain.position);
      if (distance < GameConfig.discoveryTriggerRadius) {
        discoveredVillains.add(villain.fighterData.id);
        onVillainDiscovered?.call(
          villain.fighterData.id,
          villain.fighterData.name,
          villain.fighterData.title,
        );

        // Trigger discovery dialogue
        dialogueManager.triggerDialogue(
          villain.fighterData.dialogueProfileId ?? villain.fighterData.id,
          DialogueCategory.discovery,
          villain.fighterData.name,
          villain.fighterData.title,
          villain.fighterData.color,
        );
      }
    }
  }

  void _checkGameOver() {
    if (isGameOver) return;

    final allFriendlyDown =
        player.isKnockedOut && teammateComponents.every((t) => t.isKnockedOut);
    final allEnemiesDown = villainComponents.every((v) => v.isKnockedOut);

    if (allFriendlyDown) {
      _endGame(MatchOutcome.defeat);
    } else if (allEnemiesDown) {
      _endGame(MatchOutcome.victory);
    }
  }

  void _endGame(MatchOutcome outcome) {
    isGameOver = true;
    for (final v in villainComponents) {
      if (v.isKnockedOut) {
        defeatedVillains.add(v.fighterData.id);
      }
    }
    onGameOver?.call(outcome, totalDamageDealt, totalDamageTaken, matchTimer.toInt());
  }

  void dismissDialogue() {
    isInDialogue = false;
    dialogueManager.dismissDialogue();
    onDialogueDismissed?.call();
  }

  void pauseGame() => isPaused = true;
  void resumeGame() => isPaused = false;

  void startCombatWithVillain(String villainId) {
    isExplorationMode = false;
    for (final v in villainComponents) {
      v.activateCombat();
    }
    for (final t in teammateComponents) {
      t.activateCombatAI(this);
    }
  }

  /// Get all alive fighters of a given team.
  List<PositionComponent> getAliveTeamMembers(Team team) {
    final result = <PositionComponent>[];
    if (team == Team.friendly) {
      if (!player.isKnockedOut) result.add(player);
      for (final t in teammateComponents) {
        if (!t.isKnockedOut) result.add(t);
      }
    } else {
      for (final v in villainComponents) {
        if (!v.isKnockedOut) result.add(v);
      }
    }
    return result;
  }

  /// Get the nearest enemy for a given position and team.
  PositionComponent? getNearestEnemy(Vector2 position, Team myTeam) {
    final enemies = getAliveTeamMembers(myTeam.opposite);
    if (enemies.isEmpty) return null;

    PositionComponent? nearest;
    double minDist = double.infinity;
    for (final enemy in enemies) {
      final dist = position.distanceTo(enemy.position);
      if (dist < minDist) {
        minDist = dist;
        nearest = enemy;
      }
    }
    return nearest;
  }
}
