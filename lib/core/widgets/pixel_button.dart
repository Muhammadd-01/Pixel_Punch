import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/app_theme.dart';
import '../../services/audio_service.dart';

/// A premium game-styled button with glow effects, press animation, and icon support.
class PixelButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback onTap;
  final bool isLarge;
  final bool isOutlined;
  final bool enabled;
  final bool showGlow;
  final double? width;

  const PixelButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color = AppColors.primary,
    this.isLarge = false,
    this.isOutlined = false,
    this.enabled = true,
    this.showGlow = true,
    this.width,
  });

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isLarge && widget.showGlow) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.enabled ? widget.color : widget.color.withValues(alpha: 0.4);
    final vertPad = widget.isLarge ? 20.0 : 16.0;
    final fontSize = widget.isLarge ? 20.0 : 16.0;
    final iconSize = widget.isLarge ? 28.0 : 22.0;
    final letterSpacing = widget.isLarge ? 3.0 : 1.5;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final glowIntensity = widget.showGlow && widget.isLarge
            ? 8.0 + _pulseAnimation.value * 12.0
            : 0.0;
        final glowOpacity = widget.showGlow && widget.isLarge
            ? 0.2 + _pulseAnimation.value * 0.2
            : 0.0;

        return GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            if (widget.enabled) {
              try {
                context.read<AudioService>().playUiSound(UiSound.buttonTap);
              } catch (_) {}
              widget.onTap();
            }
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: Container(
              width: widget.width,
              padding: EdgeInsets.symmetric(vertical: vertPad, horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: widget.isOutlined
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withValues(alpha: 0.3),
                          color.withValues(alpha: 0.1),
                        ],
                      ),
                border: Border.all(
                  color: color.withValues(alpha: widget.isOutlined ? 0.8 : 0.5),
                  width: widget.isOutlined ? 2.0 : 1.5,
                ),
                boxShadow: glowIntensity > 0
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: glowOpacity),
                          blurRadius: glowIntensity,
                          spreadRadius: glowIntensity * 0.3,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: widget.width != null
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: color, size: iconSize),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: color,
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      letterSpacing: letterSpacing,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
