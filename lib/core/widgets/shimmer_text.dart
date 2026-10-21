import 'package:flutter/material.dart';
import '../../app/app_theme.dart';

/// Text widget with an animated shimmer/sweeping highlight effect.
class ShimmerText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Color shimmerColor;
  final TextAlign textAlign;

  const ShimmerText({
    super.key,
    required this.text,
    this.style,
    this.shimmerColor = AppColors.accent,
    this.textAlign = TextAlign.center,
  });

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
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
      builder: (context, _) {
        final t = _controller.value;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 + 3.0 * t, 0),
              end: Alignment(-0.5 + 3.0 * t, 0),
              colors: [
                Colors.white,
                widget.shimmerColor,
                Colors.white,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: Text(
            widget.text,
            textAlign: widget.textAlign,
            style: widget.style ??
                Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
          ),
        );
      },
    );
  }
}

/// Animated typewriter text — reveals text character by character with optional blip callback.
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration charDuration;
  final VoidCallback? onCharReveal;
  final VoidCallback? onComplete;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.charDuration = const Duration(milliseconds: 35),
    this.onCharReveal,
    this.onComplete,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _charCount;

  @override
  void initState() {
    super.initState();
    final totalDuration = widget.charDuration * widget.text.length;
    _controller = AnimationController(
      vsync: this,
      duration: totalDuration,
    );
    _charCount = IntTween(begin: 0, end: widget.text.length).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
    _charCount.addListener(_onCharChanged);
    _controller.forward().then((_) => widget.onComplete?.call());
  }

  int _lastCount = 0;
  void _onCharChanged() {
    final current = _charCount.value;
    if (current > _lastCount) {
      widget.onCharReveal?.call();
      _lastCount = current;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _charCount,
      builder: (context, _) {
        final visibleText = widget.text.substring(0, _charCount.value);
        final cursor = _charCount.value < widget.text.length ? '▌' : '';
        return Text(
          '$visibleText$cursor',
          style: widget.style ??
              Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
        );
      },
    );
  }
}
