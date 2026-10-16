import 'package:flutter/material.dart';
import '../../app/app_theme.dart';

/// Reusable PixelPunch logo widget displaying the generated branding asset
/// with stylized fallback and glow effect.
class PixelPunchLogoWidget extends StatelessWidget {
  final double width;
  final double height;
  final bool showShadow;

  const PixelPunchLogoWidget({
    super.key,
    this.width = 180,
    this.height = 180,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: showShadow
          ? BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            )
          : null,
      child: Image.asset(
        'assets/branding/pixel_punch_logo.png',
        width: width,
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback procedural logo if asset loading fails
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sports_mma, size: 54, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  'PIXELPUNCH',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
