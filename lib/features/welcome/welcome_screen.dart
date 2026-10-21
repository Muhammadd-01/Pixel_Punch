import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/animated_background.dart';
import '../../core/widgets/pixel_button.dart';
import '../../core/widgets/pixel_punch_logo.dart';
import '../../core/widgets/shimmer_text.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _buttonsController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _taglineOpacity;
  late Animation<Offset> _buttonsSlide;
  late Animation<double> _buttonsOpacity;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _buttonsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
      ),
    );

    _buttonsSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _buttonsController,
      curve: Curves.easeOutCubic,
    ));
    _buttonsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _buttonsController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _logoController.forward().then((_) {
      _buttonsController.forward();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _buttonsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        particleCount: 35,
        showFloatingPixels: true,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Logo
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) => Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: child,
                      ),
                    ),
                    child: const PixelPunchLogoWidget(
                      width: 160,
                      height: 160,
                      showShadow: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Shimmer tagline
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) => Opacity(
                      opacity: _taglineOpacity.value,
                      child: child,
                    ),
                    child: const ShimmerText(
                      text: 'Your Zone. Your Rivals. Your Victory.',
                      shimmerColor: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 56),

                  // Buttons section with slide animation
                  SlideTransition(
                    position: _buttonsSlide,
                    child: FadeTransition(
                      opacity: _buttonsOpacity,
                      child: Column(
                        children: [
                          // Primary: Continue as Guest
                          PixelButton(
                            label: 'PLAY AS GUEST',
                            icon: Icons.play_arrow_rounded,
                            color: AppColors.primary,
                            isLarge: true,
                            showGlow: true,
                            width: double.infinity,
                            onTap: () => context.go('/home'),
                          ),
                          const SizedBox(height: 16),

                          // Create Account
                          PixelButton(
                            label: 'CREATE ACCOUNT',
                            icon: Icons.person_add_rounded,
                            color: AppColors.secondary,
                            isOutlined: true,
                            width: double.infinity,
                            onTap: () => context.push('/register'),
                          ),
                          const SizedBox(height: 12),

                          // Login
                          PixelButton(
                            label: 'SIGN IN',
                            icon: Icons.login_rounded,
                            color: AppColors.textSecondary,
                            isOutlined: true,
                            width: double.infinity,
                            onTap: () => context.push('/login'),
                          ),
                          const SizedBox(height: 36),

                          // Terms text
                          Text(
                            'By continuing, you agree to our Terms of Service\nand Privacy Policy.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.5),
                                  height: 1.5,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
