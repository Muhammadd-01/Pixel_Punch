import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/app_theme.dart';

/// Reusable animated particle + gradient background used across all screens.
class AnimatedBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? gradientColors;
  final int particleCount;
  final bool showGrid;
  final bool showFloatingPixels;

  const AnimatedBackground({
    super.key,
    required this.child,
    this.gradientColors,
    this.particleCount = 30,
    this.showGrid = false,
    this.showFloatingPixels = true,
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _particles = List.generate(
      widget.particleCount,
      (_) => _Particle.random(_random),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.gradientColors ??
        const [
          AppColors.background,
          AppColors.backgroundLight,
          Color(0xFF0A1628),
        ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          if (widget.showGrid)
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPainter(
                  animation: _controller,
                  color: AppColors.primary.withValues(alpha: 0.03),
                ),
              ),
            ),
          if (widget.showFloatingPixels)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _ParticlePainter(
                    particles: _particles,
                    progress: _controller.value,
                  ),
                ),
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}

class _Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;
  final Color color;
  final double phase;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.color,
    required this.phase,
  });

  factory _Particle.random(Random rng) {
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      Colors.white,
    ];
    return _Particle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      size: 2 + rng.nextDouble() * 4,
      speed: 0.2 + rng.nextDouble() * 0.8,
      opacity: 0.1 + rng.nextDouble() * 0.4,
      color: colors[rng.nextInt(colors.length)],
      phase: rng.nextDouble() * 2 * pi,
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = (progress * p.speed + p.phase) % 1.0;
      final x = p.x * size.width;
      final y = ((p.y - t) % 1.0) * size.height;
      final wobble = sin(progress * 2 * pi * p.speed + p.phase) * 8;
      final pulse = 0.5 + 0.5 * sin(progress * 2 * pi * 2 + p.phase);

      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity * (0.5 + 0.5 * pulse))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.8);

      canvas.drawCircle(
        Offset(x + wobble, y),
        p.size * (0.8 + 0.4 * pulse),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}

class _GridPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _GridPainter({required this.animation, required this.color})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    const spacing = 40.0;
    final offset = (animation.value * spacing) % spacing;

    for (double x = -spacing + offset; x < size.width + spacing; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = -spacing + offset; y < size.height + spacing; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => true;
}
