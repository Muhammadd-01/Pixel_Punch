import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/custom_villain.dart';

/// Static appearance of a 2D fighter.
class CharacterLook {
  final Color color;
  final String archetype;
  final bool isVillain;
  final Color skin;
  final ui.Image? face;
  final FaceTraits? traits;

  const CharacterLook({
    required this.color,
    required this.archetype,
    required this.isVillain,
    this.skin = const Color(0xFFF1C27D),
    this.face,
    this.traits,
  });

  static const _skins = [
    Color(0xFFF1C27D),
    Color(0xFFE0AC69),
    Color(0xFFC68642),
    Color(0xFF8D5524),
    Color(0xFFFFDBAC),
  ];

  static Color skinFor(String id) =>
      _skins[id.codeUnits.fold<int>(0, (a, b) => a + b) % _skins.length];
}

/// Per-frame animation state.
class CharacterPose {
  final double walkPhase;
  final bool moving;
  final double attack; // 1 = punch just thrown, 0 = idle
  final Offset facing;
  final bool knockedOut;
  final bool hitFlash;
  final double opacity;
  final bool angry;

  const CharacterPose({
    this.walkPhase = 0,
    this.moving = false,
    this.attack = 0,
    this.facing = const Offset(1, 0),
    this.knockedOut = false,
    this.hitFlash = false,
    this.opacity = 1,
    this.angry = false,
  });
}

/// Draws a chunky cartoon fighter centred on (0, 0) of a 40x40 unit box.
/// The head extends above the box. Shared by the game and menu previews.
void paintCharacter(Canvas canvas, CharacterLook look, CharacterPose pose,
    {double scale = 1}) {
  canvas.save();
  canvas.scale(scale);

  // Shadow stays on the ground even when knocked out.
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(0, 18), width: 30, height: 8),
    Paint()..color = Colors.black.withValues(alpha: 0.3 * pose.opacity),
  );

  final needsLayer = pose.hitFlash || pose.opacity < 1;
  if (needsLayer) {
    final layer = Paint()
      ..color = Colors.white.withValues(alpha: pose.opacity.clamp(0.0, 1.0));
    if (pose.hitFlash) {
      layer.colorFilter =
          const ColorFilter.mode(Color(0xEEFFFFFF), BlendMode.srcATop);
    }
    canvas.saveLayer(const Rect.fromLTWH(-40, -60, 80, 90), layer);
  }

  if (pose.knockedOut) {
    canvas.translate(0, 8);
    canvas.rotate(math.pi / 2 * (pose.facing.dx >= 0 ? -1 : 1));
    canvas.translate(0, -2);
  }

  final dir = pose.facing.dx >= 0 ? 1.0 : -1.0;
  final swing = pose.moving ? math.sin(pose.walkPhase) : 0.0;
  final bob = pose.moving ? math.sin(pose.walkPhase * 2).abs() * -1.5 : 0.0;

  final main = look.color;
  final dark = _shade(main, -0.35);
  final ink = Paint()
    ..color = const Color(0xFF1A0E22)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeJoin = StrokeJoin.round;

  // Villain cape behind the body.
  if (look.isVillain) {
    final cape = Path()
      ..moveTo(-10, -7 + bob)
      ..lineTo(10, -7 + bob)
      ..lineTo(14 + swing * 1.5, 15)
      ..lineTo(-14 + swing * 1.5, 15)
      ..close();
    canvas.drawPath(cape, Paint()..color = _shade(main, -0.5));
    canvas.drawPath(cape, ink);
  }

  // Legs.
  final legPaint = Paint()..color = _shade(main, -0.55);
  for (final side in [-1.0, 1.0]) {
    final lift = swing * side * 2.2;
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(side < 0 ? -7.5 : 2.5, 5 + lift.clamp(-3, 0), 5, 12 - lift.abs() * 0.4),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(r, legPaint);
    canvas.drawRRect(r, ink);
  }

  // Torso.
  final torso = RRect.fromRectAndRadius(
    Rect.fromLTWH(-10, -8 + bob, 20, 16),
    const Radius.circular(6),
  );
  canvas.drawRRect(torso, Paint()..color = main);
  canvas.drawRect(Rect.fromLTWH(-10, 3 + bob, 20, 3), Paint()..color = dark);
  _paintEmblem(canvas, look, Offset(0, -2 + bob));
  canvas.drawRRect(torso, ink);

  // Fists (the front fist throws punches toward the facing direction).
  final f = pose.facing.distance > 0 ? pose.facing / pose.facing.distance : const Offset(1, 0);
  final punch = Curves.easeOut.transform(pose.attack.clamp(0.0, 1.0));
  final fistPaint = Paint()..color = look.isVillain ? _shade(main, 0.25) : look.skin;
  final backFist = Offset(-dir * 13, 1 - swing * 2 + bob);
  final frontFist = Offset(dir * 13, 1 + swing * 2 + bob) + f * (12 * punch);
  canvas.drawCircle(backFist, 4, fistPaint);
  canvas.drawCircle(backFist, 4, ink);
  if (punch > 0.05) {
    canvas.drawLine(
      Offset(dir * 8, -2 + bob),
      frontFist,
      Paint()
        ..color = _shade(main, -0.1)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }
  canvas.drawCircle(frontFist, 4.5, fistPaint);
  canvas.drawCircle(frontFist, 4.5, ink);

  // Head.
  if (look.face != null) {
    _paintFaceHead(canvas, look, pose, Offset(0, -21 + bob));
  } else if (look.isVillain) {
    _paintVillainHead(canvas, look, pose, Offset(0, -19 + bob), dir);
  } else {
    _paintHeroHead(canvas, look, pose, Offset(0, -19 + bob), dir);
  }

  if (needsLayer) canvas.restore();
  canvas.restore();
}

void _paintEmblem(Canvas canvas, CharacterLook look, Offset c) {
  final p = Paint()..color = Colors.white.withValues(alpha: 0.85);
  switch (look.archetype) {
    case 'tank':
      final path = Path()
        ..moveTo(c.dx - 4, c.dy - 4)
        ..lineTo(c.dx + 4, c.dy - 4)
        ..lineTo(c.dx + 4, c.dy)
        ..lineTo(c.dx, c.dy + 4)
        ..lineTo(c.dx - 4, c.dy)
        ..close();
      canvas.drawPath(path, p);
    case 'speedster':
      final path = Path()
        ..moveTo(c.dx + 1, c.dy - 5)
        ..lineTo(c.dx - 3, c.dy + 1)
        ..lineTo(c.dx, c.dy + 1)
        ..lineTo(c.dx - 1, c.dy + 5)
        ..lineTo(c.dx + 3, c.dy - 1)
        ..lineTo(c.dx, c.dy - 1)
        ..close();
      canvas.drawPath(path, p);
    case 'support':
      canvas.drawRect(Rect.fromCenter(center: c, width: 2.5, height: 7), p);
      canvas.drawRect(Rect.fromCenter(center: c, width: 7, height: 2.5), p);
    case 'heavy_hitter':
      canvas.drawCircle(c, 3.5, p);
    case 'trickster':
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - 4)
          ..lineTo(c.dx + 4, c.dy)
          ..lineTo(c.dx, c.dy + 4)
          ..lineTo(c.dx - 4, c.dy)
          ..close(),
        p,
      );
    default:
      _star(canvas, c, 4.2, p);
  }
}

void _star(Canvas canvas, Offset c, double r, Paint p) {
  final path = Path();
  for (int i = 0; i < 10; i++) {
    final rr = i.isEven ? r : r * 0.45;
    final a = -math.pi / 2 + i * math.pi / 5;
    final pt = Offset(c.dx + rr * math.cos(a), c.dy + rr * math.sin(a));
    if (i == 0) {
      path.moveTo(pt.dx, pt.dy);
    } else {
      path.lineTo(pt.dx, pt.dy);
    }
  }
  canvas.drawPath(path..close(), p);
}

void _paintHeroHead(
    Canvas canvas, CharacterLook look, CharacterPose pose, Offset c, double dir) {
  final ink = Paint()
    ..color = const Color(0xFF1A0E22)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;
  canvas.drawCircle(c, 12, Paint()..color = look.skin);
  // Hair.
  canvas.drawArc(Rect.fromCircle(center: c, radius: 12), math.pi * 1.05,
      math.pi * 0.9, true, Paint()..color = const Color(0xFF3B2A20));
  // Headband in team colour.
  canvas.drawRect(
      Rect.fromLTWH(c.dx - 12, c.dy - 6, 24, 4), Paint()..color = look.color);
  canvas.drawPath(
    Path()
      ..moveTo(c.dx - dir * 11, c.dy - 5)
      ..lineTo(c.dx - dir * 18, c.dy - 8)
      ..lineTo(c.dx - dir * 17, c.dy - 2)
      ..close(),
    Paint()..color = look.color,
  );
  canvas.drawCircle(c, 12, ink);
  _paintEyes(canvas, c + const Offset(0, 1), pose, dir,
      white: Colors.white, pupil: const Color(0xFF1A0E22));
  if (!pose.knockedOut) {
    canvas.drawArc(Rect.fromCenter(center: c + Offset(dir * 1.5, 6), width: 7, height: 4),
        0.2, math.pi - 0.4, false, ink..strokeWidth = 1.3);
  }
}

void _paintVillainHead(
    Canvas canvas, CharacterLook look, CharacterPose pose, Offset c, double dir) {
  final ink = Paint()
    ..color = const Color(0xFF1A0E22)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;
  final headColor = _shade(look.color, 0.2);
  // Little horns for every villain.
  for (final side in [-1.0, 1.0]) {
    final horn = Path()
      ..moveTo(c.dx + side * 5, c.dy - 9)
      ..lineTo(c.dx + side * 11, c.dy - 17)
      ..lineTo(c.dx + side * 10, c.dy - 7)
      ..close();
    canvas.drawPath(horn, Paint()..color = const Color(0xFF2B1B30));
  }
  canvas.drawCircle(c, 12, Paint()..color = headColor);
  canvas.drawCircle(c, 12, ink);
  _paintEyes(canvas, c + const Offset(0, 1), pose, dir,
      white: const Color(0xFFFFEB3B), pupil: const Color(0xFF1A0E22));
  if (!pose.knockedOut) {
    // Angry brows.
    final brow = Paint()
      ..color = const Color(0xFF1A0E22)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c + const Offset(-8, -5), c + const Offset(-2, -2), brow);
    canvas.drawLine(c + const Offset(8, -5), c + const Offset(2, -2), brow);
    // Grin with teeth.
    final mouth = Path()
      ..moveTo(c.dx - 6, c.dy + 5)
      ..quadraticBezierTo(c.dx, c.dy + 10, c.dx + 6, c.dy + 5)
      ..close();
    canvas.drawPath(mouth, Paint()..color = Colors.white);
    canvas.drawPath(mouth, ink..strokeWidth = 1.3);
  }
}

void _paintEyes(Canvas canvas, Offset c, CharacterPose pose, double dir,
    {required Color white, required Color pupil}) {
  if (pose.knockedOut) {
    final x = Paint()
      ..color = const Color(0xFF1A0E22)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (final ex in [-4.5, 4.5]) {
      canvas.drawLine(c + Offset(ex - 2.5, -4), c + Offset(ex + 2.5, 1), x);
      canvas.drawLine(c + Offset(ex + 2.5, -4), c + Offset(ex - 2.5, 1), x);
    }
    return;
  }
  final f = pose.facing.distance > 0 ? pose.facing / pose.facing.distance : const Offset(1, 0);
  for (final ex in [-4.5, 4.5]) {
    final e = c + Offset(ex + dir * 1.5, -1.5);
    canvas.drawOval(Rect.fromCenter(center: e, width: 6, height: 7),
        Paint()..color = white);
    canvas.drawCircle(e + f * 1.4, 1.7, Paint()..color = pupil);
  }
}

/// Head made from the cartoonised face photo: round portrait, devil horns,
/// angry brows placed over the detected eyes and glowing pupils in combat.
void _paintFaceHead(
    Canvas canvas, CharacterLook look, CharacterPose pose, Offset c) {
  const r = 15.0;
  final image = look.face!;
  final traits = look.traits;
  final accent = traits?.accentColor ?? look.color;

  for (final side in [-1.0, 1.0]) {
    final horn = Path()
      ..moveTo(c.dx + side * 6, c.dy - 12)
      ..quadraticBezierTo(c.dx + side * 15, c.dy - 18, c.dx + side * 15, c.dy - 25)
      ..quadraticBezierTo(c.dx + side * 17, c.dy - 15, c.dx + side * 12, c.dy - 9)
      ..close();
    canvas.drawPath(horn, Paint()..color = _shade(accent, -0.25));
    canvas.drawPath(
        horn,
        Paint()
          ..color = const Color(0xFF1A0E22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3);
  }

  final rect = Rect.fromCircle(center: c, radius: r);
  canvas.save();
  canvas.clipPath(Path()..addOval(rect));
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    rect,
    Paint()..filterQuality = FilterQuality.medium,
  );
  canvas.restore();
  canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6);

  final le = traits?.leftEye ?? const Offset(0.36, 0.45);
  final re = traits?.rightEye ?? const Offset(0.64, 0.45);
  Offset map(Offset rel) => Offset(rect.left + rel.dx * rect.width, rect.top + rel.dy * rect.height);
  final l = map(le), rr = map(re);
  final eyeGap = (rr - l).distance.clamp(6.0, 20.0);

  if (pose.knockedOut) {
    final x = Paint()
      ..color = const Color(0xFFFF1744)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (final e in [l, rr]) {
      canvas.drawLine(e + const Offset(-2.5, -2.5), e + const Offset(2.5, 2.5), x);
      canvas.drawLine(e + const Offset(2.5, -2.5), e + const Offset(-2.5, 2.5), x);
    }
    return;
  }

  // Angry brows slanting down toward the nose.
  final brow = Paint()
    ..color = const Color(0xFF1A0E22)
    ..strokeWidth = math.max(1.8, eyeGap * 0.2)
    ..strokeCap = StrokeCap.round;
  final lift = eyeGap * 0.38;
  canvas.drawLine(l + Offset(-eyeGap * 0.32, -lift - 1.5), l + Offset(eyeGap * 0.22, -lift + 1.2), brow);
  canvas.drawLine(rr + Offset(eyeGap * 0.32, -lift - 1.5), rr + Offset(-eyeGap * 0.22, -lift + 1.2), brow);

  if (pose.angry) {
    final glow = Paint()
      ..color = const Color(0xFFFF1744).withValues(alpha: 0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    canvas.drawCircle(l, 1.6, glow);
    canvas.drawCircle(rr, 1.6, glow);
  }
}

Color _shade(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness + amount * hsl.lightness).clamp(0.05, 0.92))
      .toColor();
}

/// Widget-friendly painter for menu previews.
class CharacterPreviewPainter extends CustomPainter {
  final CharacterLook look;
  final CharacterPose pose;

  CharacterPreviewPainter(this.look, {this.pose = const CharacterPose()});

  @override
  void paint(Canvas canvas, Size size) {
    // Character spans roughly y -46..22 and x -20..20 in local units.
    final s = math.min(size.width / 44, size.height / 72);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + 12 * s);
    paintCharacter(canvas, look, pose, scale: s);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CharacterPreviewPainter old) =>
      old.look != look || old.pose != pose;
}
