import 'dart:math';
import 'package:flame/components.dart';
import '../components/fighter_base.dart';
import '../components/player_component.dart';
import '../components/villain_component.dart';
import '../models/game_enums.dart';
import '../pixel_punch_game.dart';
import '../../core/config/game_config.dart';

/// Finite-state machine AI controller for both enemies and teammates.
class AIController {
  final FighterBase fighter;
  final PixelPunchGame game;
  final bool isTeammate;

  AIState _state = AIState.idle;
  double _decisionTimer = 0;
  PositionComponent? _currentTarget;
  final Random _random = Random();

  AIController({
    required this.fighter,
    required this.game,
    required this.isTeammate,
  });

  AIState get state => _state;

  void update(double dt) {
    if (fighter.isKnockedOut) {
      _state = AIState.knockedOut;
      return;
    }

    _decisionTimer += dt;
    if (_decisionTimer >= GameConfig.aiDecisionInterval) {
      _decisionTimer = 0;
      _makeDecision();
    }
    _executeState(dt);
  }

  void _makeDecision() {
    final myTeam = isTeammate ? Team.friendly : Team.enemy;
    _currentTarget = game.getNearestEnemy(fighter.position, myTeam);

    if (_currentTarget == null) {
      _state = AIState.idle;
      return;
    }

    final dist = fighter.position.distanceTo(_currentTarget!.position);

    // Retreat when low health
    if (fighter.isLowHealth && !isTeammate && _random.nextDouble() < 0.3) {
      _state = AIState.retreat;
      return;
    }

    // Try special ability
    if (fighter.canUseSpecial && _random.nextDouble() < 0.2) {
      if (dist <= (fighter.abilityData?.range ?? 80)) {
        _state = AIState.useSpecial;
        return;
      }
    }

    // Attack if in range
    if (dist <= fighter.fighterData.attackRange) {
      _state = AIState.attack;
      return;
    }

    // Approach
    if (dist <= GameConfig.aiApproachDistance) {
      _state = AIState.approach;
      return;
    }

    _state = isTeammate ? AIState.follow : AIState.idle;
  }

  void _executeState(double dt) {
    switch (_state) {
      case AIState.idle:
        fighter.velocity = Vector2.zero();
        fighter.currentAnimation = 'idle';
      case AIState.approach || AIState.investigate:
        _moveToward(_currentTarget!.position, dt);
      case AIState.follow:
        _moveToward(game.player.position, dt, keepDistance: 60);
      case AIState.attack:
        _performAttack();
      case AIState.useSpecial:
        _performSpecial();
      case AIState.retreat:
        _retreat(dt);
      case AIState.patrol || AIState.defend:
        fighter.velocity = Vector2.zero();
      case AIState.stunned || AIState.knockedOut:
        fighter.velocity = Vector2.zero();
    }
  }

  void _moveToward(Vector2 target, double dt, {double keepDistance = 0}) {
    final dir = target - fighter.position;
    final dist = dir.length;
    if (dist <= keepDistance) {
      fighter.velocity = Vector2.zero();
      fighter.currentAnimation = 'idle';
      return;
    }

    final normalized = dir.normalized();
    fighter.velocity = normalized * fighter.fighterData.moveSpeed;
    fighter.facingDirection = normalized;
    fighter.position += fighter.velocity * dt;
    fighter.currentAnimation = 'walk';

    fighter.position.x = fighter.position.x.clamp(20, game.zoneData.width - 20);
    fighter.position.y = fighter.position.y.clamp(20, game.zoneData.height - 20);
  }

  void _retreat(double dt) {
    if (_currentTarget == null) return;
    final dir = (fighter.position - _currentTarget!.position).normalized();
    fighter.velocity = dir * fighter.fighterData.moveSpeed;
    fighter.facingDirection = -dir;
    fighter.position += fighter.velocity * dt;
    fighter.currentAnimation = 'walk';

    fighter.position.x = fighter.position.x.clamp(20, game.zoneData.width - 20);
    fighter.position.y = fighter.position.y.clamp(20, game.zoneData.height - 20);
  }

  void _performAttack() {
    if (!fighter.canAttack || _currentTarget == null) return;
    fighter.isAttacking = true;
    fighter.attackCooldownTimer = fighter.fighterData.attackCooldown;

    final dist = fighter.position.distanceTo(_currentTarget!.position);
    if (dist <= fighter.fighterData.attackRange && _currentTarget is FighterBase) {
      final target = _currentTarget! as FighterBase;
      final knockDir = target.position - fighter.position;
      final dmg = target.takeDamage(
        fighter.fighterData.attackDamage,
        knockbackDirection: knockDir,
      );
      if (isTeammate) {
        game.totalDamageDealt += dmg;
      } else {
        game.totalDamageTaken += dmg;
      }
    }
    fighter.isAttacking = false;
  }

  void _performSpecial() {
    if (!fighter.canUseSpecial) return;
    if (fighter is PlayerComponent) {
      (fighter as PlayerComponent).performSpecial(game);
    } else if (fighter is VillainComponent) {
      fighter.isUsingSpecial = true;
      fighter.specialCooldownTimer = fighter.abilityData?.cooldown ?? 5.0;
      final ability = fighter.abilityData;
      if (ability != null &&
          _currentTarget != null &&
          _currentTarget is FighterBase &&
          fighter.position.distanceTo(_currentTarget!.position) <= ability.range) {
        final target = _currentTarget! as FighterBase;
        final dmg = target.takeDamage(
          (fighter.fighterData.attackDamage * ability.damageMultiplier).round(),
          knockbackDirection: target.position - fighter.position,
        );
        game.totalDamageTaken += dmg;
      }
      fighter.isUsingSpecial = false;
    }
  }
}
