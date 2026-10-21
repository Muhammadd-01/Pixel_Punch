import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Draggable;
import 'package:flutter/services.dart';
import 'models/fighter_data.dart';
import 'models/zone_data.dart';
import 'models/ability_data.dart';
import 'models/custom_villain.dart';
import 'models/dialogue_data.dart';
import 'models/game_enums.dart';
import 'components/fighter_base.dart';
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

class PixelPunchGame extends FlameGame with KeyboardEvents {
  final ZoneData zoneData;
  final List<FighterData> heroDataList;
  final List<FighterData> villainDataList;
  final Map<String, AbilityData> abilities;
  final Map<String, DialogueProfile> dialogueProfiles;
  final GameMode mode;

  /// Cartoon face portraits (PNG) for villains generated from photos.
  final Map<String, Uint8List> villainFaces;
  final Map<String, FaceTraits> villainTraits;
  final bool hapticsEnabled;
  final bool reducedMotion;

  // Callbacks to Flutter overlay
  DialogueCallback? onDialogue;
  GameOverCallback? onGameOver;
  DiscoveryCallback? onVillainDiscovered;
  VoidCallback? onDialogueDismissed;
  VoidCallback? onPauseRequested;

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
  bool _loaded = false;
  double matchTimer = 0;
  int totalDamageDealt = 0;
  int totalDamageTaken = 0;
  final Set<String> discoveredVillains = {};
  final Set<String> defeatedVillains = {};
  VillainComponent? _pendingEngage;
  MatchOutcome? _pendingOutcome;
  double _endDelay = 0;
  double _shakeTimer = 0;
  double _hudTimer = 0;
  final Random _rng = Random();
  PositionComponent? _cameraTarget;

  /// Ticks ~10x per second so Flutter HUD widgets can refresh cheaply.
  final ValueNotifier<int> hudTick = ValueNotifier(0);

  // Input (set from Flutter overlay or keyboard)
  Vector2 joystickDirection = Vector2.zero();
  final Vector2 _keyboardDirection = Vector2.zero();
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
    this.villainFaces = const {},
    this.villainTraits = const {},
    this.hapticsEnabled = true,
    this.reducedMotion = false,
  });

  bool get isReady => _loaded;

  @override
  Color backgroundColor() => const Color(0xFF0B0B16);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    combatManager = CombatManager(game: this);
    dialogueManager = DialogueManager(
      profiles: dialogueProfiles,
      onShowDialogue: (villainId, name, title, text, color) {
        isInDialogue = true;
        onDialogue?.call(villainId, name, title, text, color);
      },
    );

    zoneComponent = ZoneComponent(zoneData: zoneData);
    await world.add(zoneComponent);

    // Player
    final heroData = heroDataList.first;
    player = PlayerComponent(
      fighterData: heroData,
      team: Team.friendly,
      isPlayerControlled: true,
      abilityData: abilities[heroData.specialAbility],
    )..priority = 10;
    player.position = Vector2(zoneData.playerSpawnX, zoneData.playerSpawnY);
    await world.add(player);

    // AI teammates (Duo/Squad)
    for (int i = 1; i < heroDataList.length && i < mode.friendlyCount; i++) {
      final data = heroDataList[i];
      final teammate = PlayerComponent(
        fighterData: data,
        team: Team.friendly,
        isPlayerControlled: false,
        abilityData: abilities[data.specialAbility],
      )..priority = 10;
      teammate.position = _freeSpot(Vector2(
        zoneData.playerSpawnX + (i.isOdd ? -50 : 50),
        zoneData.playerSpawnY + 40,
      ));
      teammateComponents.add(teammate);
      await world.add(teammate);
      teammate.activateCombatAI(this);
    }

    // Villains
    final usedSpawns = <Vector2>[];
    for (int i = 0; i < villainDataList.length; i++) {
      final villainData = villainDataList[i];
      final villain = VillainComponent(
        fighterData: villainData,
        team: Team.enemy,
        abilityData: abilities[villainData.specialAbility],
        dialogueProfile: dialogueProfiles[villainData.dialogueProfileId ?? villainData.id],
        patrolRadius: villainData.patrolRadius ?? 100.0,
      )..priority = 10;
      var spawn = villainData.spawnX != null && villainData.spawnY != null
          ? Vector2(villainData.spawnX!, villainData.spawnY!)
          : _defaultVillainSpawn(i);
      while (usedSpawns.any((s) => s.distanceTo(spawn) < 70)) {
        spawn += Vector2(80, 60);
      }
      spawn = _freeSpot(spawn);
      usedSpawns.add(spawn);
      villain.position = spawn;

      final png = villainFaces[villainData.id];
      if (png != null) {
        try {
          final image = await decodeImageFromList(png);
          villain.setFace(image, villainTraits[villainData.id]);
        } catch (e) {
          debugPrint('Could not decode villain face: $e');
        }
      }
      villainComponents.add(villain);
      await world.add(villain);
    }

    _cameraTarget = player;
    _updateZoom(size);
    _updateCamera(0, snap: true);
    _loaded = true;
    hudTick.value++;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _updateZoom(size);
  }

  void _updateZoom(Vector2 size) {
    if (size.x <= 0 || size.y <= 0) return;
    // Keep characters a comfortable size on both phones and tablets.
    camera.viewfinder.zoom = (min(size.x, size.y) / 300).clamp(1.0, 2.2);
  }

  Vector2 _defaultVillainSpawn(int index) {
    final playerSpawn = Vector2(zoneData.playerSpawnX, zoneData.playerSpawnY);
    final locations = [...zoneData.locations]..sort((a, b) {
        final da = Vector2(a.x + a.width / 2, a.y + a.height / 2).distanceTo(playerSpawn);
        final db = Vector2(b.x + b.width / 2, b.y + b.height / 2).distanceTo(playerSpawn);
        return db.compareTo(da);
      });
    if (locations.isEmpty) {
      return Vector2(zoneData.width * 0.7, zoneData.height * 0.5);
    }
    final loc = locations[index % locations.length];
    return Vector2(loc.x + loc.width / 2, loc.y + loc.height / 2);
  }

  @override
  void update(double dt) {
    if (isPaused || isInDialogue) return;
    // Clamp large frame gaps (e.g. after app resume) so physics stays stable.
    dt = min(dt, 1 / 20);
    super.update(dt);
    if (!_loaded) return;

    _hudTimer += dt;
    if (_hudTimer >= 0.1) {
      _hudTimer = 0;
      hudTick.value++;
    }

    _updateCamera(dt);
    _updateShake(dt);

    if (isGameOver) return;

    if (_pendingOutcome != null) {
      _endDelay -= dt;
      if (_endDelay <= 0) _endGame(_pendingOutcome!);
      return;
    }

    matchTimer += dt;
    dialogueManager.update(dt);

    // Player input
    final input = joystickDirection.length2 > 0.0001
        ? joystickDirection
        : _keyboardDirection;
    player.inputDirection = input;
    if (attackPressed) {
      player.performAttack();
      attackPressed = false;
    }
    if (specialPressed) {
      player.performSpecial();
      specialPressed = false;
    }
    if (dodgePressed) {
      player.performDodge();
      dodgePressed = false;
    }

    _separateFighters();
    _checkVillainDiscovery();
    combatManager.update(dt);
    _checkGameOver();
  }

  void _separateFighters() {
    final all = <FighterBase>[
      if (!player.isKnockedOut) player,
      ...teammateComponents.where((t) => !t.isKnockedOut),
      ...villainComponents.where((v) => !v.isKnockedOut),
    ];
    const minDist = 28.0;
    for (int i = 0; i < all.length; i++) {
      for (int j = i + 1; j < all.length; j++) {
        final a = all[i], b = all[j];
        final d = b.position - a.position;
        final len = d.length;
        if (len >= minDist) continue;
        final push = len == 0
            ? Vector2(_rng.nextDouble() - 0.5, _rng.nextDouble() - 0.5)
            : d / len;
        final overlap = (minDist - len) / 2;
        a.moveBy(-push * overlap);
        b.moveBy(push * overlap);
      }
    }
  }

  void _checkVillainDiscovery() {
    if (player.isKnockedOut) return;
    for (final villain in villainComponents) {
      if (villain.isKnockedOut) continue;
      if (villain.discovered && villain.isInCombat) continue;

      final distance = player.position.distanceTo(villain.position);
      if (distance < GameConfig.discoveryTriggerRadius * 1.6) {
        _discover(villain);
        final shown = dialogueManager.triggerDialogue(
          villain.fighterData.dialogueProfileId ?? villain.fighterData.id,
          DialogueCategory.discovery,
          villain.fighterData.name,
          villain.fighterData.title,
          villain.fighterData.color,
        );
        if (shown) {
          _pendingEngage = villain;
        } else {
          villain.activateCombat();
        }
        return;
      }
    }
  }

  void _discover(VillainComponent villain) {
    villain.discovered = true;
    if (discoveredVillains.add(villain.fighterData.id)) {
      onVillainDiscovered?.call(
        villain.fighterData.id,
        villain.fighterData.name,
        villain.fighterData.title,
      );
    }
  }

  /// Called by a villain the moment it starts fighting.
  void onVillainEngaged(VillainComponent villain) {
    isExplorationMode = false;
    _discover(villain);
    // Nearby villains join the brawl too.
    for (final other in villainComponents) {
      if (other == villain || other.isInCombat || other.isKnockedOut) continue;
      if (other.position.distanceTo(villain.position) < 260) {
        other.activateCombat();
      }
    }
  }

  void onFighterKnockedOut(FighterBase fighter) {
    if (fighter is VillainComponent) {
      defeatedVillains.add(fighter.fighterData.id);
      shake(0.2);
      _haptic(HapticFeedback.mediumImpact);
    } else if (fighter == player) {
      _haptic(HapticFeedback.heavyImpact);
      // Spectate a surviving teammate.
      for (final t in teammateComponents) {
        if (!t.isKnockedOut) {
          _cameraTarget = t;
          break;
        }
      }
    }
  }

  void recordDamage(FighterBase attacker, FighterBase target, int amount) {
    if (attacker.team == Team.friendly) {
      totalDamageDealt += amount;
      if (attacker == player) _haptic(HapticFeedback.selectionClick);
    } else {
      totalDamageTaken += amount;
      if (target == player) {
        _haptic(HapticFeedback.lightImpact);
        shake(0.12);
      }
    }
  }

  void _haptic(Future<void> Function() feedback) {
    if (hapticsEnabled) feedback();
  }

  void shake(double seconds) {
    if (reducedMotion) return;
    _shakeTimer = max(_shakeTimer, seconds);
  }

  /// Smoothly follows the target and keeps the view inside the zone.
  void _updateCamera(double dt, {bool snap = false}) {
    final target = _cameraTarget;
    if (target == null) return;
    final vf = camera.viewfinder;
    final t = snap ? 1.0 : 1 - exp(-8 * dt);
    final pos = vf.position + (target.position - vf.position) * t;
    final halfW = size.x / vf.zoom / 2;
    final halfH = size.y / vf.zoom / 2;
    pos.x = zoneData.width <= halfW * 2
        ? zoneData.width / 2
        : pos.x.clamp(halfW, zoneData.width - halfW).toDouble();
    pos.y = zoneData.height <= halfH * 2
        ? zoneData.height / 2
        : pos.y.clamp(halfH, zoneData.height - halfH).toDouble();
    vf.position = pos;
  }

  void _updateShake(double dt) {
    if (_shakeTimer > 0) {
      _shakeTimer -= dt;
      final m = 4 * (_shakeTimer.clamp(0.0, 0.3) / 0.3);
      camera.viewport.position = Vector2(
        (_rng.nextDouble() - 0.5) * 2 * m,
        (_rng.nextDouble() - 0.5) * 2 * m,
      );
    } else if (camera.viewport.position.length2 > 0) {
      camera.viewport.position = Vector2.zero();
    }
  }

  void _checkGameOver() {
    if (isGameOver || _pendingOutcome != null) return;

    final allFriendlyDown =
        player.isKnockedOut && teammateComponents.every((t) => t.isKnockedOut);
    final allEnemiesDown = villainComponents.every((v) => v.isKnockedOut);

    if (allFriendlyDown) {
      _pendingOutcome = MatchOutcome.defeat;
      for (final v in villainComponents) {
        if (!v.isKnockedOut) {
          v.speak(DialogueCategory.victory, force: true);
          break;
        }
      }
    } else if (allEnemiesDown) {
      _pendingOutcome = MatchOutcome.victory;
    }
    if (_pendingOutcome != null) _endDelay = 1.6;
  }

  void _endGame(MatchOutcome outcome) {
    isGameOver = true;
    player.inputDirection = Vector2.zero();
    for (final v in villainComponents) {
      if (v.isKnockedOut) defeatedVillains.add(v.fighterData.id);
    }
    onGameOver?.call(
        outcome, totalDamageDealt, totalDamageTaken, matchTimer.toInt());
  }

  void dismissDialogue() {
    isInDialogue = false;
    dialogueManager.dismissDialogue();
    final pending = _pendingEngage;
    _pendingEngage = null;
    pending?.activateCombat();
    onDialogueDismissed?.call();
  }

  void pauseGame() => isPaused = true;
  void resumeGame() => isPaused = false;

  /// Kept for compatibility: engage a specific villain.
  void startCombatWithVillain(String villainId) {
    for (final v in villainComponents) {
      if (v.fighterData.id == villainId) v.activateCombat();
    }
  }

  // ---------------------------------------------------------------------------
  // Queries

  List<FighterBase> getAliveFighters(Team team) {
    final result = <FighterBase>[];
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

  /// Get all alive fighters of a given team.
  List<PositionComponent> getAliveTeamMembers(Team team) => getAliveFighters(team);

  /// Get the nearest living enemy for a given position and team.
  FighterBase? getNearestEnemy(Vector2 position, Team myTeam) {
    FighterBase? nearest;
    double minDist = double.infinity;
    for (final enemy in getAliveFighters(myTeam.opposite)) {
      final dist = position.distanceTo(enemy.position);
      if (dist < minDist) {
        minDist = dist;
        nearest = enemy;
      }
    }
    return nearest;
  }

  // ---------------------------------------------------------------------------
  // Collision

  bool _hitsObstacle(Vector2 p, double r) {
    for (final o in zoneData.obstacles) {
      final nx = p.x.clamp(o.x, o.x + o.width);
      final ny = p.y.clamp(o.y, o.y + o.height);
      final dx = p.x - nx, dy = p.y - ny;
      if (dx * dx + dy * dy < r * r) return true;
    }
    return false;
  }

  /// Applies [delta] to [from], then pushes the circle back out of any
  /// obstacle it overlaps. This slides smoothly along walls and corners.
  Vector2 resolveMovement(Vector2 from, Vector2 delta, double radius,
      {bool assist = true}) {
    final p = _pushOut(from + delta, radius);
    // Corner assist: when walking almost straight into a corner, glide
    // around it instead of stopping dead.
    final len = delta.length;
    if (assist && len > 0.01 && p.distanceTo(from) < len * 0.35) {
      final dir = delta / len;
      for (final side in [1.0, -1.0]) {
        final tangent = Vector2(-dir.y, dir.x) * side;
        final probe = _pushOut(from + (dir * 0.4 + tangent * 0.9) * len, radius);
        if (probe.distanceTo(from) > len * 0.5 &&
            (probe - from).dot(dir) > len * 0.1) {
          return probe;
        }
      }
    }
    if (len > radius && _segmentCrossesObstacle(from, p)) return from.clone();
    return p;
  }

  Vector2 _pushOut(Vector2 target, double radius) {
    final r = radius;
    final p = target.clone();
    for (int iteration = 0; iteration < 3; iteration++) {
      var moved = false;
      for (final o in zoneData.obstacles) {
        final cx = p.x.clamp(o.x, o.x + o.width).toDouble();
        final cy = p.y.clamp(o.y, o.y + o.height).toDouble();
        final dx = p.x - cx, dy = p.y - cy;
        final d2 = dx * dx + dy * dy;
        if (d2 >= r * r) continue;
        moved = true;
        if (d2 > 1e-6) {
          final d = sqrt(d2);
          p.x += dx / d * (r - d);
          p.y += dy / d * (r - d);
        } else {
          // Centre is inside the rectangle: leave by the nearest side.
          final left = p.x - o.x, right = o.x + o.width - p.x;
          final top = p.y - o.y, bottom = o.y + o.height - p.y;
          final m = [left, right, top, bottom].reduce(min);
          if (m == left) {
            p.x = o.x - r;
          } else if (m == right) {
            p.x = o.x + o.width + r;
          } else if (m == top) {
            p.y = o.y - r;
          } else {
            p.y = o.y + o.height + r;
          }
        }
      }
      p.x = p.x.clamp(r, zoneData.width - r).toDouble();
      p.y = p.y.clamp(r, zoneData.height - r).toDouble();
      if (!moved) break;
    }
    return p;
  }

  bool _segmentCrossesObstacle(Vector2 a, Vector2 b) {
    const steps = 6;
    for (int i = 1; i < steps; i++) {
      final t = i / steps;
      if (_hitsObstacle(Vector2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t), 2)) {
        return true;
      }
    }
    return false;
  }

  Vector2 _freeSpot(Vector2 desired) {
    const r = 18.0;
    var p = Vector2(
      desired.x.clamp(r, zoneData.width - r).toDouble(),
      desired.y.clamp(r, zoneData.height - r).toDouble(),
    );
    double angle = 0, dist = 0;
    while (_hitsObstacle(p, r) && dist < 400) {
      angle += 0.7;
      dist += 6;
      p = Vector2(
        (desired.x + cos(angle) * dist).clamp(r, zoneData.width - r).toDouble(),
        (desired.y + sin(angle) * dist).clamp(r, zoneData.height - r).toDouble(),
      );
    }
    return p;
  }

  // ---------------------------------------------------------------------------
  // Keyboard (desktop / web / emulator)

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    bool any(List<LogicalKeyboardKey> keys) => keys.any(keysPressed.contains);
    _keyboardDirection
      ..x = (any([LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight]) ? 1.0 : 0.0) -
          (any([LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft]) ? 1.0 : 0.0)
      ..y = (any([LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown]) ? 1.0 : 0.0) -
          (any([LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp]) ? 1.0 : 0.0);

    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.keyJ || key == LogicalKeyboardKey.space) {
        attackPressed = true;
      } else if (key == LogicalKeyboardKey.keyK) {
        specialPressed = true;
      } else if (key == LogicalKeyboardKey.keyL ||
          key == LogicalKeyboardKey.shiftLeft ||
          key == LogicalKeyboardKey.shiftRight) {
        dodgePressed = true;
      } else if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyP) {
        onPauseRequested?.call();
      }
    }
    return KeyEventResult.handled;
  }

  @override
  void onRemove() {
    hudTick.dispose();
    super.onRemove();
  }
}
