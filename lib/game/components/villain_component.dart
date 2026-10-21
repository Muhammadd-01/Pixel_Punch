import 'dart:math';
import 'package:flame/components.dart';
import 'fighter_base.dart';
import '../models/dialogue_data.dart';
import '../ai/ai_controller.dart';

/// AI-controlled villain component.
class VillainComponent extends FighterBase {
  final DialogueProfile? dialogueProfile;
  final double patrolRadius;
  late Vector2 spawnPosition;
  AIController? _aiController;
  bool _combatActivated = false;
  bool discovered = false;
  bool _saidLowHealth = false;
  double _tauntCooldown = 4;
  Vector2? _patrolTarget;
  double _patrolWaitTimer = 0;
  final Random _rng = Random();

  VillainComponent({
    required super.fighterData,
    required super.team,
    super.abilityData,
    this.dialogueProfile,
    required this.patrolRadius,
  });

  bool get isInCombat => _combatActivated;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    spawnPosition = position.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isKnockedOut) return;

    _tauntCooldown -= dt;

    if (_combatActivated) {
      _aiController?.update(dt);
    } else {
      _updatePatrol(dt);
    }
  }

  void _updatePatrol(double dt) {
    if (_patrolWaitTimer > 0) {
      _patrolWaitTimer -= dt;
      velocity = Vector2.zero();
      currentAnimation = 'idle';
      return;
    }

    if (_patrolTarget == null || position.distanceTo(_patrolTarget!) < 10) {
      final angle = _rng.nextDouble() * 2 * pi;
      _patrolTarget = spawnPosition +
          Vector2(
            patrolRadius * 0.7 * cos(angle),
            patrolRadius * 0.7 * sin(angle),
          );
      _patrolWaitTimer = 1.5 + _rng.nextDouble() * 2;
      return;
    }

    final dir = (_patrolTarget! - position).normalized();
    velocity = dir * (fighterData.moveSpeed * 0.4);
    facingDirection = dir;
    final before = position.clone();
    moveBy(velocity * dt);
    // Blocked by an obstacle: pick a new patrol point.
    if (position.distanceTo(before) < velocity.length * dt * 0.2) {
      _patrolTarget = null;
    }
    currentAnimation = 'walk';
  }

  void activateCombat() {
    if (_combatActivated || isKnockedOut) return;
    final game = pixelGame;
    if (game == null) return;
    _combatActivated = true;
    discovered = true;
    _aiController = AIController(
      fighter: this,
      game: game,
      isTeammate: false,
    );
    game.onVillainEngaged(this);
  }

  /// Speaks a random line from the given category as a speech bubble.
  bool speak(DialogueCategory category, {bool force = false}) {
    final profile = dialogueProfile;
    if (profile == null) return false;
    final line = force ? profile.getLineForced(category) : profile.getLine(category);
    if (line == null) return false;
    say(line);
    return true;
  }

  void tryCombatTaunt() {
    if (_tauntCooldown > 0 || isKnockedOut) return;
    if (speak(isLowHealth ? DialogueCategory.lowHealth : DialogueCategory.combatTaunt)) {
      _tauntCooldown = 6;
    }
  }

  @override
  void onDamaged(int amount) {
    if (amount > 0) activateCombat();
    if (isKnockedOut) {
      speak(DialogueCategory.defeat, force: true);
    } else if (isLowHealth && !_saidLowHealth) {
      _saidLowHealth = true;
      speak(DialogueCategory.lowHealth, force: true);
    }
  }

  @override
  void onSpecialUsed() {
    if (_rng.nextDouble() < 0.6) speak(DialogueCategory.specialAttack, force: true);
  }
}
