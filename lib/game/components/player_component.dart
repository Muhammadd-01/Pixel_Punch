import 'package:flame/components.dart';
import 'fighter_base.dart';
import '../models/ability_data.dart';
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

    if (isAttacking) {
      attackCooldownTimer = fighterData.attackCooldown;
      isAttacking = false;
    }
  }

  void _handlePlayerMovement(double dt) {
    if (inputDirection.length > 0) {
      final normalizedDir =
          inputDirection.length > 1 ? inputDirection.normalized() : inputDirection;
      velocity = normalizedDir * fighterData.moveSpeed;
      facingDirection = normalizedDir;
      currentAnimation = 'walk';
    } else {
      velocity = Vector2.zero();
      currentAnimation = 'idle';
    }

    position += velocity * dt;

    // Clamp to zone boundaries
    final game = findGame();
    if (game is PixelPunchGame) {
      position.x = position.x.clamp(20, game.zoneData.width - 20);
      position.y = position.y.clamp(20, game.zoneData.height - 20);
    }
  }

  void performAttack(PixelPunchGame game) {
    if (!canAttack) return;
    isAttacking = true;

    final target = game.getNearestEnemy(position, team);
    if (target == null) return;

    final dist = position.distanceTo(target.position);
    if (dist <= fighterData.attackRange) {
      final knockDir = (target.position - position);
      if (target is FighterBase) {
        final dmg = target.takeDamage(
          fighterData.attackDamage,
          knockbackDirection: knockDir,
        );
        game.totalDamageDealt += dmg;
      }
    }
  }

  void performSpecial(PixelPunchGame game) {
    if (!canUseSpecial || abilityData == null) return;
    isUsingSpecial = true;
    specialCooldownTimer = abilityData!.cooldown;

    switch (abilityData!.type) {
      case AbilityType.damage:
        _doChargedStrike(game);
      case AbilityType.shield:
        _doProtectiveShield();
      case AbilityType.dash:
        _doRapidDash(game);
      case AbilityType.areaDamage:
        _doGroundSlam(game);
      case AbilityType.heal:
        _doTeamRecovery(game);
      case AbilityType.evasion:
        _doEvasiveBurst();
    }
    isUsingSpecial = false;
  }

  void _doChargedStrike(PixelPunchGame game) {
    final target = game.getNearestEnemy(position, team);
    if (target == null) return;
    final dist = position.distanceTo(target.position);
    if (dist <= abilityData!.range && target is FighterBase) {
      final dmg = target.takeDamage(
        (fighterData.attackDamage * abilityData!.damageMultiplier).round(),
        knockbackDirection: (target.position - position),
      );
      game.totalDamageDealt += dmg;
    }
  }

  void _doProtectiveShield() {
    isShielded = true;
    shieldTimer = abilityData!.duration;
  }

  void _doRapidDash(PixelPunchGame game) {
    isDodging = true;
    dodgeTimer = abilityData!.duration;
    position += facingDirection.normalized() * abilityData!.range;

    final enemies = game.getAliveTeamMembers(team.opposite);
    for (final enemy in enemies) {
      final dist = position.distanceTo(enemy.position);
      if (dist < 50 && enemy is FighterBase) {
        final dmg = enemy.takeDamage(
          (fighterData.attackDamage * abilityData!.damageMultiplier).round(),
          knockbackDirection: (enemy.position - position),
        );
        game.totalDamageDealt += dmg;
      }
    }
  }

  void _doGroundSlam(PixelPunchGame game) {
    final enemies = game.getAliveTeamMembers(team.opposite);
    for (final enemy in enemies) {
      final dist = position.distanceTo(enemy.position);
      if (dist <= abilityData!.range && enemy is FighterBase) {
        final dmg = enemy.takeDamage(
          (fighterData.attackDamage * abilityData!.damageMultiplier).round(),
          knockbackDirection: (enemy.position - position),
        );
        game.totalDamageDealt += dmg;
      }
    }
  }

  void _doTeamRecovery(PixelPunchGame game) {
    final allies = game.getAliveTeamMembers(team);
    for (final ally in allies) {
      if (ally is FighterBase) {
        final dist = position.distanceTo(ally.position);
        if (dist <= abilityData!.range) ally.heal(abilityData!.healAmount);
      }
    }
  }

  void _doEvasiveBurst() {
    isDodging = true;
    isInvulnerable = true;
    dodgeTimer = abilityData!.duration;
    invulnerabilityTimer = abilityData!.duration;
    position += facingDirection.normalized() * abilityData!.range;
  }

  void performDodge() {
    if (isKnockedOut || isDodging) return;
    isDodging = true;
    isInvulnerable = true;
    dodgeTimer = 0.3;
    invulnerabilityTimer = 0.3;
    position += facingDirection.normalized() * 60;
  }

  void activateCombatAI(PixelPunchGame game) {
    if (isPlayerControlled) return;
    _aiController = AIController(
      fighter: this,
      game: game,
      isTeammate: true,
    );
  }
}
