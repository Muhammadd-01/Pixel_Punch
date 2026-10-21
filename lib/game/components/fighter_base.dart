import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/fighter_data.dart';
import '../models/ability_data.dart';
import '../models/custom_villain.dart';
import '../models/game_enums.dart';
import '../render/character_painter.dart';
import '../pixel_punch_game.dart';
import 'effects.dart';
import '../../core/config/game_config.dart';
import '../../services/audio_service.dart';

/// Base class for all fighter components (heroes and villains).
/// Holds health, combat timers, shared attack/special logic and rendering.
abstract class FighterBase extends PositionComponent {
  final FighterData fighterData;
  final Team team;
  final AbilityData? abilityData;

  // Health
  late int currentHealth;
  late int maxHealth;
  bool get isKnockedOut => currentHealth <= 0;
  double get healthPercent => maxHealth > 0 ? currentHealth / maxHealth : 0;
  bool get isLowHealth => healthPercent < 0.3;

  // Combat state
  double attackCooldownTimer = 0;
  double specialCooldownTimer = 0;
  double dodgeCooldownTimer = 0;
  double invulnerabilityTimer = 0;
  double hitFlashTimer = 0;
  bool isAttacking = false;
  bool isUsingSpecial = false;
  bool isShielded = false;
  bool isDodging = false;
  bool isInvulnerable = false;
  double shieldTimer = 0;
  double dodgeTimer = 0;

  // Movement
  Vector2 velocity = Vector2.zero();
  Vector2 facingDirection = Vector2(1, 0);
  Vector2 knockbackVelocity = Vector2.zero();

  // Animation
  String currentAnimation = 'idle';
  double attackAnim = 0;
  double _walkPhase = 0;
  double _koTimer = 0;
  late CharacterLook look;
  TextPainter? _namePainter;
  SpeechBubble? _bubble;

  static const double dodgeCooldown = 0.7;

  FighterBase({
    required this.fighterData,
    required this.team,
    this.abilityData,
  }) : super(
          size: Vector2.all(GameConfig.playerSize),
          anchor: Anchor.center,
        ) {
    maxHealth = fighterData.baseHealth;
    currentHealth = maxHealth;
    look = CharacterLook(
      color: fighterData.color,
      archetype: fighterData.archetype,
      isVillain: fighterData.isVillain,
      skin: CharacterLook.skinFor(fighterData.id),
    );
  }

  /// Gives the fighter a cartoon face generated from a photo.
  void setFace(ui.Image image, FaceTraits? traits) {
    look = CharacterLook(
      color: fighterData.color,
      archetype: fighterData.archetype,
      isVillain: fighterData.isVillain,
      skin: traits?.skinTone ?? look.skin,
      face: image,
      traits: traits,
    );
  }

  PixelPunchGame? get pixelGame {
    final g = isMounted ? findGame() : null;
    return g is PixelPunchGame ? g : null;
  }

  double get radius => size.x / 2;

  @override
  void update(double dt) {
    super.update(dt);
    if (_bubble != null && !_bubble!.isMounted) _bubble = null;
    if (isKnockedOut) {
      _koTimer += dt;
      return;
    }

    if (attackCooldownTimer > 0) attackCooldownTimer -= dt;
    if (specialCooldownTimer > 0) specialCooldownTimer -= dt;
    if (dodgeCooldownTimer > 0) dodgeCooldownTimer -= dt;
    if (attackAnim > 0) attackAnim = max(0, attackAnim - dt / 0.22);
    if (invulnerabilityTimer > 0) {
      invulnerabilityTimer -= dt;
      if (invulnerabilityTimer <= 0) isInvulnerable = false;
    }
    if (hitFlashTimer > 0) hitFlashTimer -= dt;
    if (shieldTimer > 0) {
      shieldTimer -= dt;
      if (shieldTimer <= 0) isShielded = false;
    }
    if (dodgeTimer > 0) {
      dodgeTimer -= dt;
      if (dodgeTimer <= 0) isDodging = false;
    }

    if (knockbackVelocity.length > 1) {
      moveBy(knockbackVelocity * dt);
      knockbackVelocity *= pow(0.02, dt).toDouble();
    }

    if (velocity.length2 > 1) {
      _walkPhase += dt * (6 + velocity.length / 25);
    }
  }

  /// Moves while respecting obstacles and zone bounds.
  void moveBy(Vector2 delta) {
    final game = pixelGame;
    if (game == null) {
      position += delta;
      return;
    }
    position.setFrom(game.resolveMovement(position, delta, radius * 0.8));
  }

  /// Moves a long distance in small steps so dashes stop at walls.
  void dashBy(Vector2 delta) {
    final steps = max(1, (delta.length / 8).ceil());
    final step = delta / steps.toDouble();
    for (int i = 0; i < steps; i++) {
      final before = position.clone();
      moveBy(step);
      if (position.distanceTo(before) < step.length * 0.3) break;
    }
  }

  /// Take damage from an attack.
  int takeDamage(int rawDamage, {Vector2? knockbackDirection, double knockback = 1}) {
    if (isKnockedOut || isInvulnerable || isDodging) return 0;

    // Defence subtracts from the hit, but every hit still chips at least
    // 35% through so heavily armoured fighters stay beatable.
    final effectiveDamage = isShielded
        ? (rawDamage * 0.2).round()
        : max(max(1, (rawDamage * 0.35).floor()), rawDamage - fighterData.defense);

    currentHealth = max(0, currentHealth - effectiveDamage);
    hitFlashTimer = GameConfig.hitFlashDuration;

    if (knockbackDirection != null && !isShielded && knockbackDirection.length2 > 0) {
      knockbackVelocity = knockbackDirection.normalized() *
          GameConfig.knockbackForce * 1.2 * knockback;
    }

    if (!isShielded) {
      isInvulnerable = true;
      invulnerabilityTimer = GameConfig.invulnerabilityDuration;
    }

    final game = pixelGame;
    if (game != null) {
      game.world.add(FloatingText(
        text: '-$effectiveDamage',
        color: team == Team.friendly ? const Color(0xFFFF5252) : const Color(0xFFFFEB3B),
        position: position + Vector2(0, -36),
      ));
      game.world.add(HitSpark(
        position: position + Vector2(0, -6),
        color: isShielded ? Colors.cyanAccent : Colors.white,
      ));
    }

    pixelGame?.audioService?.playCombatSound(CombatSound.damageTaken);
    if (isKnockedOut) _onKnockout();
    onDamaged(effectiveDamage);
    return effectiveDamage;
  }

  /// Hook for subclasses (taunts, aggro).
  void onDamaged(int amount) {}

  /// Hook when this fighter uses its special.
  void onSpecialUsed() {}

  void heal(int amount) {
    if (isKnockedOut) return;
    final before = currentHealth;
    currentHealth = min(maxHealth, currentHealth + amount);
    final healed = currentHealth - before;
    final game = pixelGame;
    if (game != null && healed > 0) {
      game.world.add(FloatingText(
        text: '+$healed',
        color: const Color(0xFF69F0AE),
        position: position + Vector2(0, -36),
      ));
    }
  }

  bool get canAttack =>
      !isKnockedOut && attackCooldownTimer <= 0 && !isAttacking && !isDodging;
  bool get canUseSpecial =>
      !isKnockedOut &&
      specialCooldownTimer <= 0 &&
      !isUsingSpecial &&
      !isDodging;
  bool get canDodge => !isKnockedOut && !isDodging && dodgeCooldownTimer <= 0;

  double get specialCooldownProgress {
    if (abilityData == null) return 1.0;
    if (specialCooldownTimer <= 0) return 1.0;
    return 1.0 - (specialCooldownTimer / abilityData!.cooldown);
  }

  double get dodgeCooldownProgress =>
      dodgeCooldownTimer <= 0 ? 1.0 : 1.0 - dodgeCooldownTimer / dodgeCooldown;

  void _onKnockout() {
    currentAnimation = 'knockout';
    velocity = Vector2.zero();
    knockbackVelocity = Vector2.zero();
    isShielded = false;
    pixelGame?.onFighterKnockedOut(this);
  }

  /// Deals damage and keeps the match stats up to date.
  int dealDamageTo(FighterBase target, int rawDamage, {double knockback = 1}) {
    final dir = target.position - position;
    final dmg = target.takeDamage(rawDamage,
        knockbackDirection: dir, knockback: knockback);
    final game = pixelGame;
    if (game != null && dmg > 0) game.recordDamage(this, target, dmg);
    return dmg;
  }

  /// Basic punch at the nearest enemy in reach. Returns true if it landed.
  bool performAttack() {
    if (!canAttack) return false;
    final game = pixelGame;
    attackCooldownTimer = fighterData.attackCooldown;
    attackAnim = 1;
    if (game == null) return false;

    final target = game.getNearestEnemy(position, team);
    if (target == null) return false;
    final toTarget = target.position - position;
    final reach = fighterData.attackRange + target.radius * 0.5;
    if (toTarget.length <= reach) {
      if (toTarget.length2 > 0) facingDirection = toTarget.normalized();
      dealDamageTo(target, fighterData.attackDamage);
      pixelGame?.audioService?.playCombatSound(CombatSound.punchHit);
      return true;
    }
    return false;
  }

  void performSpecial() {
    final ability = abilityData;
    if (!canUseSpecial || ability == null) return;
    final game = pixelGame;
    if (game == null) return;
    isUsingSpecial = true;
    pixelGame?.audioService?.playCombatSound(CombatSound.specialActivate);
    specialCooldownTimer = ability.cooldown;
    attackAnim = 1;

    switch (ability.type) {
      case AbilityType.damage:
        final target = game.getNearestEnemy(position, team);
        if (target != null && position.distanceTo(target.position) <= ability.range) {
          facingDirection = (target.position - position).normalized();
          dealDamageTo(target,
              (fighterData.attackDamage * ability.damageMultiplier).round(),
              knockback: 2);
        }
        game.world.add(RingEffect(
            position: position.clone(), color: Colors.orangeAccent, maxRadius: ability.range));
      case AbilityType.shield:
        isShielded = true;
        shieldTimer = ability.duration;
        game.world.add(RingEffect(
            position: position.clone(), color: Colors.cyanAccent, maxRadius: 34));
      case AbilityType.dash:
        final target = game.getNearestEnemy(position, team);
        if (target != null) facingDirection = (target.position - position).normalized();
        isDodging = true;
        dodgeTimer = ability.duration;
        dashBy(facingDirection.normalized() * ability.range);
        for (final enemy in game.getAliveFighters(team.opposite)) {
          if (position.distanceTo(enemy.position) < 55) {
            dealDamageTo(enemy,
                (fighterData.attackDamage * ability.damageMultiplier).round(),
                knockback: 1.5);
          }
        }
        game.world.add(RingEffect(
            position: position.clone(), color: Colors.yellowAccent, maxRadius: 40));
      case AbilityType.areaDamage:
        for (final enemy in game.getAliveFighters(team.opposite)) {
          if (position.distanceTo(enemy.position) <= ability.range) {
            dealDamageTo(enemy,
                (fighterData.attackDamage * ability.damageMultiplier).round(),
                knockback: 2.2);
          }
        }
        game.world.add(RingEffect(
            position: position.clone(),
            color: Colors.deepOrangeAccent,
            maxRadius: ability.range,
            duration: 0.5));
        game.shake(0.25);
      case AbilityType.heal:
        for (final ally in game.getAliveFighters(team)) {
          if (position.distanceTo(ally.position) <= ability.range) {
            ally.heal(ability.healAmount);
          }
        }
        game.world.add(RingEffect(
            position: position.clone(),
            color: Colors.greenAccent,
            maxRadius: ability.range,
            duration: 0.6));
      case AbilityType.evasion:
        isDodging = true;
        isInvulnerable = true;
        dodgeTimer = ability.duration;
        invulnerabilityTimer = ability.duration;
        final threat = game.getNearestEnemy(position, team);
        final away = threat != null && threat.position != position
            ? (position - threat.position).normalized()
            : facingDirection.normalized();
        game.world.add(RingEffect(
            position: position.clone(), color: Colors.purpleAccent, maxRadius: 30));
        dashBy(away * ability.range);
    }
    isUsingSpecial = false;
    onSpecialUsed();
  }

  void performDodge() {
    if (!canDodge) return;
    isDodging = true;
    isInvulnerable = true;
    pixelGame?.audioService?.playCombatSound(CombatSound.dodgeWhoosh);
    dodgeTimer = 0.3;
    invulnerabilityTimer = 0.3;
    dodgeCooldownTimer = dodgeCooldown;
    final dir = velocity.length2 > 1 ? velocity.normalized() : facingDirection.normalized();
    dashBy(dir * 60);
  }

  /// Shows a comic speech bubble above the fighter.
  void say(String text, {double duration = 2.6}) {
    if (!isMounted) return;
    _bubble?.removeFromParent();
    final bubble = SpeechBubble(
        text: text, color: fighterData.color, duration: duration);
    bubble.position = Vector2(size.x / 2, -46);
    _bubble = bubble;
    add(bubble);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);

    if (isShielded) {
      canvas.drawCircle(
        const Offset(0, -6),
        30,
        Paint()..color = Colors.cyanAccent.withValues(alpha: 0.18),
      );
      canvas.drawCircle(
        const Offset(0, -6),
        30,
        Paint()
          ..color = Colors.cyanAccent.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    double opacity = 1;
    if (isKnockedOut) {
      opacity = 0.55;
    } else if (isDodging) {
      opacity = 0.5;
    } else if (isInvulnerable) {
      opacity = (sin(invulnerabilityTimer * 40) > 0) ? 1.0 : 0.55;
    }

    paintCharacter(
      canvas,
      look,
      CharacterPose(
        walkPhase: _walkPhase,
        moving: velocity.length2 > 1 && !isKnockedOut,
        attack: attackAnim,
        facing: Offset(facingDirection.x, facingDirection.y),
        knockedOut: isKnockedOut,
        hitFlash: hitFlashTimer > 0,
        opacity: opacity,
        angry: !isKnockedOut && (isLowHealth || attackAnim > 0),
      ),
    );

    if (isKnockedOut && _koTimer < 1.5) {
      // Dizzy stars.
      final t = _koTimer * 6;
      for (int i = 0; i < 3; i++) {
        final a = t + i * 2.1;
        canvas.drawCircle(
          Offset(cos(a) * 12, -14 + sin(a) * 4),
          2.2,
          Paint()..color = Colors.yellowAccent.withValues(alpha: 1 - _koTimer / 1.5),
        );
      }
    }

    canvas.restore();
    _renderHealthBar(canvas);
  }

  void _renderHealthBar(Canvas canvas) {
    if (isKnockedOut) return;
    final barWidth = size.x + 6;
    const barHeight = 4.0;
    final hasFace = look.face != null;
    final barY = hasFace ? -32.0 : -26.0;
    final barX = (size.x - barWidth) / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(barX - 1, barY - 1, barWidth + 2, barHeight + 2),
          const Radius.circular(3)),
      Paint()..color = Colors.black87,
    );

    final healthColor = healthPercent > 0.6
        ? const Color(0xFF4CAF50)
        : healthPercent > 0.3
            ? const Color(0xFFFF9800)
            : const Color(0xFFFF5252);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, barWidth * healthPercent, barHeight),
          const Radius.circular(2)),
      Paint()..color = healthColor,
    );

    _namePainter ??= TextPainter(
      text: TextSpan(
        text: fighterData.name,
        style: TextStyle(
          color: team == Team.friendly ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80),
          fontSize: 7.5,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _namePainter!.paint(
        canvas, Offset((size.x - _namePainter!.width) / 2, barY - 11));
  }
}
