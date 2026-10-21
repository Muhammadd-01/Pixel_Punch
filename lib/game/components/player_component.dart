import 'package:flame/components.dart';
import 'fighter_base.dart';
import '../pixel_punch_game.dart';
import '../ai/ai_controller.dart';

/// Player-controlled or AI-teammate fighter component.
class PlayerComponent extends FighterBase {
  final bool isPlayerControlled;
  Vector2 inputDirection = Vector2.zero();
  AIController? _aiController;

  PlayerComponent({
    required super.fighterData,
    required super.team,
    required this.isPlayerControlled,
    super.abilityData,
  });

  @override
  void update(double dt) {
    super.update(dt);
    if (isKnockedOut) return;

    if (isPlayerControlled) {
      _handlePlayerMovement(dt);
    } else {
      _aiController?.update(dt);
    }
  }

  void _handlePlayerMovement(double dt) {
    if (inputDirection.length2 > 0.01) {
      final dir =
          inputDirection.length > 1 ? inputDirection.normalized() : inputDirection;
      velocity = dir * fighterData.moveSpeed;
      facingDirection = dir.normalized();
      currentAnimation = 'walk';
      moveBy(velocity * dt);
    } else {
      velocity = Vector2.zero();
      currentAnimation = 'idle';
    }
  }

  /// Teammates run their AI from the moment the match starts: they follow
  /// the player while exploring and join fights automatically.
  void activateCombatAI(PixelPunchGame game) {
    if (isPlayerControlled || _aiController != null) return;
    _aiController = AIController(
      fighter: this,
      game: game,
      isTeammate: true,
    );
  }
}
