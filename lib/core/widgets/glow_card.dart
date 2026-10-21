import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/app_theme.dart';

/// A card with animated glowing border effect.
class GlowCard extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool animate;
  final VoidCallback? onTap;

  const GlowCard({
    super.key,
    required this.child,
    this.glowColor = AppColors.primary,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(16),
    this.animate = true,
    this.onTap,
  });

  @override
  State<GlowCard> createState() => _GlowCardState();
}

class _GlowCardState extends State<GlowCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.animate) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final glowOpacity = widget.animate
            ? 0.15 + 0.15 * sin(t * 2 * pi)
            : 0.2;
        final borderOpacity = widget.animate
            ? 0.3 + 0.2 * sin(t * 2 * pi)
            : 0.4;

        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: widget.glowColor.withValues(alpha: borderOpacity),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.glowColor.withValues(alpha: glowOpacity),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
