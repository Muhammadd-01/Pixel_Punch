import 'dart:math';
import 'package:flame/components.dart';
import 'fighter_base.dart';
import '../models/dialogue_data.dart';
import '../pixel_punch_game.dart';
import '../ai/ai_controller.dart';
import '../../core/config/game_config.dart';

/// AI-controlled villain component.
class VillainComponent extends FighterBase {
  final DialogueProfile? dialogueProfile;
  final double patrolRadius;
  late Vector2 spawnPosition;
  AIController? _aiController;
  bool _combatActivated = false;
  double _dialogueCooldown = 0;
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

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    spawnPosition = position.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isKnockedOut) return;

    _dialogueCooldown -= dt;

    if (_combatActivated) {
      _aiController?.update(dt);
    } else {
      _updatePatrol(dt);
    }
  }

  void _updatePatrol(double dt) {
    if (_patrolWaitTimer > 0) {
      _patrolWaitTimer -= dt;
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
    position += velocity * dt;
    currentAnimation = 'walk';
  }

  void activateCombat() {
    if (_combatActivated) return;
    _combatActivated = true;
    final game = findGame();
    if (game is PixelPunchGame) {
      _aiController = AIController(
        fighter: this,
        game: game,
        isTeammate: false,
      );
    }
  }

  void tryCombatTaunt() {
    if (_dialogueCooldown > 0 || dialogueProfile == null) return;
    final game = findGame();
    if (game is! PixelPunchGame) return;

    final category =
        isLowHealth ? DialogueCategory.lowHealth : DialogueCategory.combatTaunt;
    final line = dialogueProfile!.getLine(category);
    if (line != null) {
      game.dialogueManager.triggerDialogue(
        fighterData.dialogueProfileId ?? fighterData.id,
        category,
        fighterData.name,
        fighterData.title,
        fighterData.color,
      );
      _dialogueCooldown = GameConfig.dialogueCooldown;
    }
  }

  @override
  int takeDamage(int rawDamage, {Vector2? knockbackDirection}) {
    final dmg = super.takeDamage(rawDamage, knockbackDirection: knockbackDirection);
    if (dmg > 0) activateCombat();
    return dmg;
  }
}
