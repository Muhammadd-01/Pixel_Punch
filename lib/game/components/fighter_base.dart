import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import '../models/fighter_data.dart';
import '../models/ability_data.dart';
import '../models/game_enums.dart';
import '../../core/config/game_config.dart';

/// Base class for all fighter components (heroes and villains).
abstract class FighterBase extends PositionComponent with CollisionCallbacks {
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

  String currentAnimation = 'idle';

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
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox(
      radius: GameConfig.playerSize / 2,
      anchor: Anchor.center,
      position: size / 2,
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isKnockedOut) return;

    if (attackCooldownTimer > 0) attackCooldownTimer -= dt;
    if (specialCooldownTimer > 0) specialCooldownTimer -= dt;
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
      position += knockbackVelocity * dt;
      knockbackVelocity *= 0.85;
    }
  }

  /// Take damage from an attack.
  int takeDamage(int rawDamage, {Vector2? knockbackDirection}) {
    if (isKnockedOut || isInvulnerable || isDodging) return 0;

    final effectiveDamage = isShielded
        ? (rawDamage * 0.2).round()
        : max(1, rawDamage - fighterData.defense);

    currentHealth = max(0, currentHealth - effectiveDamage);
    hitFlashTimer = GameConfig.hitFlashDuration;

    if (knockbackDirection != null && !isShielded) {
      knockbackVelocity =
          knockbackDirection.normalized() * GameConfig.knockbackForce;
    }

    if (!isShielded) {
      isInvulnerable = true;
      invulnerabilityTimer = GameConfig.invulnerabilityDuration;
    }

    if (isKnockedOut) _onKnockout();
    return effectiveDamage;
  }

  void heal(int amount) {
    if (isKnockedOut) return;
    currentHealth = min(maxHealth, currentHealth + amount);
  }

  bool get canAttack =>
      !isKnockedOut && attackCooldownTimer <= 0 && !isAttacking && !isDodging;
  bool get canUseSpecial =>
      !isKnockedOut &&
      specialCooldownTimer <= 0 &&
      !isUsingSpecial &&
      !isDodging;

  double get specialCooldownProgress {
    if (abilityData == null) return 1.0;
    if (specialCooldownTimer <= 0) return 1.0;
    return 1.0 - (specialCooldownTimer / abilityData!.cooldown);
  }

  void _onKnockout() {
    currentAnimation = 'knockout';
    velocity = Vector2.zero();
    knockbackVelocity = Vector2.zero();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _renderCharacter(canvas);
    _renderHealthBar(canvas);
    _renderEffects(canvas);
  }

  void _renderCharacter(Canvas canvas) {
    final bodyPaint = Paint()
      ..color = isKnockedOut
          ? fighterData.color.withValues(alpha: 0.3)
          : (hitFlashTimer > 0 ? Colors.white : fighterData.color);

    if (isInvulnerable && !isKnockedOut) {
      bodyPaint.color = bodyPaint.color.withValues(
        alpha: (sin(invulnerabilityTimer * 20) > 0) ? 1.0 : 0.4,
      );
    }

    // Shield glow
    if (isShielded) {
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x / 2 + 6,
        Paint()
          ..color = Colors.cyan.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill,
      );
    }

    // Character body
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2 - 2,
      bodyPaint,
    );

    // Eyes
    if (!isKnockedOut) {
      final eyePaint = Paint()..color = Colors.white;
      final pupilPaint = Paint()..color = Colors.black;
      canvas.drawCircle(Offset(size.x / 2 - 6, size.y / 2 - 4), 4, eyePaint);
      canvas.drawCircle(
          Offset(size.x / 2 - 6 + facingDirection.x * 2, size.y / 2 - 4),
          2,
          pupilPaint);
      canvas.drawCircle(Offset(size.x / 2 + 6, size.y / 2 - 4), 4, eyePaint);
      canvas.drawCircle(
          Offset(size.x / 2 + 6 + facingDirection.x * 2, size.y / 2 - 4),
          2,
          pupilPaint);
    } else {
      final xPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(size.x / 2 - 9, size.y / 2 - 7),
          Offset(size.x / 2 - 3, size.y / 2 - 1), xPaint);
      canvas.drawLine(Offset(size.x / 2 - 3, size.y / 2 - 7),
          Offset(size.x / 2 - 9, size.y / 2 - 1), xPaint);
      canvas.drawLine(Offset(size.x / 2 + 3, size.y / 2 - 7),
          Offset(size.x / 2 + 9, size.y / 2 - 1), xPaint);
      canvas.drawLine(Offset(size.x / 2 + 9, size.y / 2 - 7),
          Offset(size.x / 2 + 3, size.y / 2 - 1), xPaint);
    }

    // Name label
    final nameSpan = TextSpan(
      text: fighterData.name,
      style: TextStyle(
        color: team == Team.friendly ? Colors.green : Colors.red,
        fontSize: 8,
        fontWeight: FontWeight.bold,
      ),
    );
    final namePainter = TextPainter(
      text: nameSpan,
      textDirection: TextDirection.ltr,
    );
    namePainter.layout();
    namePainter.paint(canvas, Offset((size.x - namePainter.width) / 2, -14));

    // Attack indicator
    if (isAttacking) {
      final attackPaint = Paint()
        ..color = Colors.yellow.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      final attackDir = facingDirection.normalized();
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(
              size.x / 2 + attackDir.x * 15, size.y / 2 + attackDir.y * 15),
          radius: fighterData.attackRange * 0.4,
        ),
        0,
        3.14,
        false,
        attackPaint,
      );
    }
  }

  void _renderHealthBar(Canvas canvas) {
    if (isKnockedOut) return;
    final barWidth = size.x + 4;
    const barHeight = 4.0;
    const barY = -8.0;
    final barX = (size.x - barWidth) / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, barWidth, barHeight),
          const Radius.circular(2)),
      Paint()..color = Colors.black54,
    );

    final healthColor = healthPercent > 0.6
        ? Colors.green
        : healthPercent > 0.3
            ? Colors.orange
            : Colors.red;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, barWidth * healthPercent, barHeight),
          const Radius.circular(2)),
      Paint()..color = healthColor,
    );
  }

  void _renderEffects(Canvas canvas) {
    if (isDodging) {
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x / 2 + 4,
        Paint()..color = fighterData.color.withValues(alpha: 0.3),
      );
    }
  }
}
