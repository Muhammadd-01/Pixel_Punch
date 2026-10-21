import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../models/zone_data.dart';

/// Renders the zone environment including floor, obstacles, and decorations.
class ZoneComponent extends PositionComponent {
  final ZoneData zoneData;

  ZoneComponent({required this.zoneData})
      : super(
          size: Vector2(zoneData.width, zoneData.height),
          position: Vector2.zero(),
        );

  ui.Picture? _picture;

  /// The zone is static, so it is recorded once and replayed every frame.
  ui.Picture _record() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _drawFloor(canvas);
    _drawGrid(canvas);
    _drawLocations(canvas);
    _drawObstacles(canvas);
    _drawBoundary(canvas);
    return recorder.endRecording();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawPicture(_picture ??= _record());
  }

  @override
  void onRemove() {
    _picture?.dispose();
    _picture = null;
    super.onRemove();
  }

  void _drawFloor(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, zoneData.width, zoneData.height),
      Paint()..color = zoneData.backgroundColor,
    );

    final tilePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (double x = 0; x < zoneData.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, zoneData.height), tilePaint);
    }
    for (double y = 0; y < zoneData.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(zoneData.width, y), tilePaint);
    }
  }

  void _drawGrid(Canvas canvas) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    for (double x = 0; x < zoneData.width; x += 200) {
      canvas.drawLine(Offset(x, 0), Offset(x, zoneData.height), gridPaint);
    }
    for (double y = 0; y < zoneData.height; y += 200) {
      canvas.drawLine(Offset(0, y), Offset(zoneData.width, y), gridPaint);
    }
  }

  void _drawLocations(Canvas canvas) {
    for (final loc in zoneData.locations) {
      final color = _locationColor(loc.name);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(loc.x, loc.y, loc.width, loc.height),
          const Radius.circular(8),
        ),
        Paint()..color = color.withValues(alpha: 0.08),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(loc.x, loc.y, loc.width, loc.height),
          const Radius.circular(8),
        ),
        Paint()
          ..color = color.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      final nameSpan = TextSpan(
        text: loc.name,
        style: TextStyle(
          color: color.withValues(alpha: 0.5),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
      final painter = TextPainter(text: nameSpan, textDirection: TextDirection.ltr);
      painter.layout();
      painter.paint(canvas, Offset(loc.x + (loc.width - painter.width) / 2, loc.y + 4));
    }
  }

  Color _locationColor(String name) => switch (name) {
        'Reception' => Colors.teal,
        'Open Office' => Colors.blue,
        'Meeting Room' => Colors.orange,
        'Creative Dept' => Colors.purple,
        'Server Room' => Colors.red,
        'Neon Gateway' => Colors.cyan,
        'Training Arena' => Colors.pink,
        'Speed Track' => Colors.amber,
        'Glow Platform' => Colors.green,
        'Stairway Exit' => Colors.brown,
        'Vent Corridor' => Colors.grey,
        'Skyline Lookout' => Colors.lightBlue,
        'Boss Arena' => Colors.deepOrange,
        _ => Colors.white,
      };

  void _drawObstacles(Canvas canvas) {
    for (final obs in zoneData.obstacles) {
      final color = _obstacleColor(obs.type);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(obs.x + 4, obs.y + 6, obs.width, obs.height),
          const Radius.circular(4),
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.3),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(obs.x, obs.y, obs.width, obs.height),
          const Radius.circular(4),
        ),
        Paint()..color = color,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(obs.x, obs.y, obs.width, obs.height),
          const Radius.circular(4),
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawRect(
        Rect.fromLTWH(obs.x + 2, obs.y + 2, obs.width - 4, (obs.height * 0.2).clamp(2, 6)),
        Paint()..color = Colors.white.withValues(alpha: 0.18),
      );
    }
  }

  Color _obstacleColor(String type) => switch (type) {
        'desk' => const Color(0xFF5D4037),
        'wall' => const Color(0xFF78909C),
        'server_rack' => const Color(0xFF37474F),
        'whiteboard' => const Color(0xFFECEFF1),
        'platform' => const Color(0xFF00BCD4),
        'barrier' => const Color(0xFFFF5722),
        'vent' => const Color(0xFF90A4AE),
        'railing' => const Color(0xFF607D8B),
        _ => const Color(0xFF9E9E9E),
      };

  void _drawBoundary(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, zoneData.width, zoneData.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
}
