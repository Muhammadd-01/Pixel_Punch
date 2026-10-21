import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Floating damage / heal number.
class FloatingText extends PositionComponent {
  final String text;
  final Color color;
  double _life = 0;
  static const double _duration = 0.8;
  late final TextPainter _painter;

  FloatingText({
    required this.text,
    required this.color,
    required Vector2 position,
    double fontSize = 12,
  }) : super(position: position, anchor: Anchor.center, priority: 100) {
    _painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    position.y -= 30 * dt;
    if (_life >= _duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / _duration).clamp(0.0, 1.0);
    final alpha = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
    canvas.saveLayer(
      Rect.fromLTWH(-_painter.width, -_painter.height, _painter.width * 3, _painter.height * 3),
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
    _painter.paint(canvas, Offset(-_painter.width / 2, -_painter.height / 2));
    canvas.restore();
  }
}

/// Expanding ring (slams, heals, shields).
class RingEffect extends PositionComponent {
  final Color color;
  final double maxRadius;
  final double duration;
  double _life = 0;

  RingEffect({
    required Vector2 position,
    required this.color,
    required this.maxRadius,
    this.duration = 0.4,
  }) : super(position: position, anchor: Anchor.center, priority: 50);

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    if (_life >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / duration).clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset.zero,
      maxRadius * Curves.easeOut.transform(t),
      Paint()
        ..color = color.withValues(alpha: (1 - t) * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * (1 - t) + 1,
    );
  }
}

/// Short burst of sparks on hit.
class HitSpark extends PositionComponent {
  final Color color;
  final List<Offset> _dirs;
  double _life = 0;
  static const double _duration = 0.25;

  HitSpark({required Vector2 position, required this.color, int count = 7})
      : _dirs = List.generate(count, (i) {
          final rnd = math.Random();
          final a = rnd.nextDouble() * math.pi * 2;
          final s = 0.6 + rnd.nextDouble() * 0.6;
          return Offset(math.cos(a) * s, math.sin(a) * s);
        }),
        super(position: position, anchor: Anchor.center, priority: 60);

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    if (_life >= _duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_life / _duration).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = color.withValues(alpha: 1 - t)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final d in _dirs) {
      final start = d * (4 + 14 * t);
      final end = d * (10 + 22 * t);
      canvas.drawLine(start, end, paint);
    }
  }
}

/// Comic speech bubble that follows a fighter for a few seconds.
class SpeechBubble extends PositionComponent {
  final String text;
  final Color color;
  double _life = 0;
  final double duration;
  late final TextPainter _painter;

  SpeechBubble({required this.text, required this.color, this.duration = 2.6})
      : super(anchor: Anchor.bottomCenter, priority: 120) {
    _painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF1A0E22),
          fontSize: 7.5,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 110);
    size = Vector2(_painter.width + 12, _painter.height + 10);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _life += dt;
    if (_life >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final appear = (_life / 0.15).clamp(0.0, 1.0);
    final fade = _life > duration - 0.3 ? (duration - _life) / 0.3 : 1.0;
    canvas.save();
    canvas.translate(size.x / 2, size.y);
    canvas.scale(0.6 + 0.4 * appear);
    canvas.translate(-size.x / 2, -size.y);
    final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(8));
    final fill = Paint()..color = Colors.white.withValues(alpha: 0.95 * fade);
    canvas.drawRRect(rrect, fill);
    final tail = Path()
      ..moveTo(size.x / 2 - 5, size.y - 1)
      ..lineTo(size.x / 2, size.y + 6)
      ..lineTo(size.x / 2 + 5, size.y - 1)
      ..close();
    canvas.drawPath(tail, fill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = color.withValues(alpha: fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    if (fade > 0.05) _painter.paint(canvas, const Offset(6, 5));
    canvas.restore();
  }
}
