import 'dart:math';
import 'package:flame/components.dart';
import '../components/fighter_base.dart';
import '../components/villain_component.dart';
import '../models/ability_data.dart';
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
  double _retreatTimer = 0;
  FighterBase? _currentTarget;
  final Random _random = Random();
  late final double _strafeSide = _random.nextBool() ? 1 : -1;

  AIController({
    required this.fighter,
    required this.game,
    required this.isTeammate,
  }) {
    // Stagger decisions so a squad does not act in lock-step.
    _decisionTimer = _random.nextDouble() * GameConfig.aiDecisionInterval;
  }

  AIState get state => _state;

  void update(double dt) {
    if (fighter.isKnockedOut) {
      _state = AIState.knockedOut;
      return;
    }

    if (_retreatTimer > 0) _retreatTimer -= dt;
    _decisionTimer += dt;
    if (_decisionTimer >= GameConfig.aiDecisionInterval) {
      _decisionTimer = 0;
      _makeDecision();
    }
    _executeState(dt);
  }

  FighterBase? _pickTarget() {
    if (!isTeammate) return game.getNearestEnemy(fighter.position, Team.enemy);
    // Teammates only engage villains that are already fighting, or ones
    // close to the player, so they do not wander off while exploring.
    FighterBase? best;
    double bestDist = double.infinity;
    for (final v in game.villainComponents) {
      if (v.isKnockedOut) continue;
      final engaged = v.isInCombat ||
          v.position.distanceTo(game.player.position) < GameConfig.aiApproachDistance;
      if (!engaged) continue;
      final d = fighter.position.distanceTo(v.position);
      if (d < bestDist) {
        bestDist = d;
        best = v;
      }
    }
    return best;
  }

  void _makeDecision() {
    if (_retreatTimer > 0) return;
    _currentTarget = _pickTarget();
    final ability = fighter.abilityData;

    // Support: heal hurt allies even with no target around.
    if (ability != null &&
        ability.type == AbilityType.heal &&
        fighter.canUseSpecial) {
      final hurt = game
          .getAliveFighters(fighter.team)
          .where((a) =>
              a.healthPercent < 0.6 &&
              a.position.distanceTo(fighter.position) <= ability.range)
          .length;
      if (hurt > 0) {
        _state = AIState.useSpecial;
        return;
      }
    }

    if (_currentTarget == null) {
      _state = isTeammate ? AIState.follow : AIState.idle;
      return;
    }

    final dist = fighter.position.distanceTo(_currentTarget!.position);

    // Retreat briefly when low on health.
    if (fighter.isLowHealth && _random.nextDouble() < (isTeammate ? 0.1 : 0.2)) {
      _state = AIState.retreat;
      _retreatTimer = 0.6 + _random.nextDouble() * 0.6;
      return;
    }

    if (ability != null && fighter.canUseSpecial && _wantsSpecial(ability, dist)) {
      _state = AIState.useSpecial;
      return;
    }

    if (dist <= fighter.fighterData.attackRange + _currentTarget!.radius * 0.4) {
      _state = AIState.attack;
      return;
    }

    _state = AIState.approach;
  }

  bool _wantsSpecial(AbilityData ability, double dist) {
    switch (ability.type) {
      case AbilityType.shield:
        return dist < 90 && fighter.healthPercent < 0.85 && _random.nextDouble() < 0.5;
      case AbilityType.evasion:
        return (fighter.isLowHealth || fighter.hitFlashTimer > 0) &&
            dist < 70 &&
            _random.nextDouble() < 0.5;
      case AbilityType.heal:
        return false; // handled above
      case AbilityType.dash:
        return dist > 50 && dist < ability.range + 40 && _random.nextDouble() < 0.35;
      case AbilityType.areaDamage:
        final nearby = game
            .getAliveFighters(fighter.team.opposite)
            .where((e) => e.position.distanceTo(fighter.position) <= ability.range)
            .length;
        return nearby >= 1 && _random.nextDouble() < (nearby > 1 ? 0.6 : 0.3);
      case AbilityType.damage:
        return dist <= ability.range && _random.nextDouble() < 0.3;
    }
  }

  void _executeState(double dt) {
    switch (_state) {
      case AIState.idle || AIState.patrol || AIState.defend:
        fighter.velocity = Vector2.zero();
        fighter.currentAnimation = 'idle';
      case AIState.approach || AIState.investigate:
        final target = _currentTarget;
        if (target == null || target.isKnockedOut) {
          fighter.velocity = Vector2.zero();
          return;
        }
        // Approach slightly from the side so fighters do not stack up.
        final to = target.position - fighter.position;
        final side = Vector2(-to.y, to.x)..normalize();
        final goal = target.position -
            to.normalized() * (fighter.fighterData.attackRange * 0.7) +
            side * (_strafeSide * 10);
        _moveToward(goal, dt);
        if (to.length <= fighter.fighterData.attackRange + target.radius * 0.4) {
          _performAttack();
        }
      case AIState.follow:
        _moveToward(game.player.position, dt, keepDistance: 55);
      case AIState.attack:
        fighter.velocity = Vector2.zero();
        _performAttack();
      case AIState.useSpecial:
        fighter.performSpecial();
        _state = AIState.approach;
      case AIState.retreat:
        _retreat(dt);
      case AIState.stunned || AIState.knockedOut:
        fighter.velocity = Vector2.zero();
    }
  }

  void _moveToward(Vector2 target, double dt, {double keepDistance = 4}) {
    final dir = target - fighter.position;
    final dist = dir.length;
    if (dist <= keepDistance) {
      fighter.velocity = Vector2.zero();
      fighter.currentAnimation = 'idle';
      if (_currentTarget != null) {
        final face = _currentTarget!.position - fighter.position;
        if (face.length2 > 0) fighter.facingDirection = face.normalized();
      }
      return;
    }

    final normalized = dir.normalized();
    final speed = fighter.fighterData.moveSpeed *
        (isTeammate && _state == AIState.follow && dist > 160 ? 1.3 : 1.0);
    fighter.velocity = normalized * speed;
    fighter.facingDirection = normalized;
    final step = fighter.velocity * dt;
    if (step.length > dist) step.scale(dist / step.length);
    final before = fighter.position.clone();
    fighter.moveBy(step);
    // Slide around obstacles when stuck.
    if (fighter.position.distanceTo(before) < step.length * 0.25) {
      final slide = Vector2(-normalized.y, normalized.x) * (_strafeSide * speed * dt);
      fighter.moveBy(slide);
    }
    fighter.currentAnimation = 'walk';
  }

  void _retreat(double dt) {
    final target = _currentTarget;
    if (target == null || _retreatTimer <= 0) {
      _state = AIState.approach;
      return;
    }
    final away = fighter.position - target.position;
    if (away.length2 == 0) return;
    final dir = away.normalized();
    fighter.velocity = dir * fighter.fighterData.moveSpeed;
    fighter.facingDirection = -dir;
    fighter.moveBy(fighter.velocity * dt);
    fighter.currentAnimation = 'walk';
  }

  void _performAttack() {
    final target = _currentTarget;
    if (target == null || !fighter.canAttack) return;
    final face = target.position - fighter.position;
    if (face.length2 > 0) fighter.facingDirection = face.normalized();
    fighter.performAttack();
    // Enemy AI swings a little slower than its stat so players can react.
    if (!isTeammate) fighter.attackCooldownTimer *= 1.3;
    if (fighter is VillainComponent && _random.nextDouble() < 0.12) {
      (fighter as VillainComponent).tryCombatTaunt();
    }
  }
}
