import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/local_storage_service.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/animated_background.dart';
import '../../core/widgets/pixel_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _heroAnimController;
  late AnimationController _entranceController;
  late Animation<double> _entranceScale;
  late Animation<double> _entranceOpacity;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.explore_rounded,
      title: 'Explore Battle Zones',
      description:
          'Enter distinct worlds from stylized offices to neon-lit districts. Each zone has unique challenges, secrets, and rivals to uncover.',
      color: AppColors.primary,
      emoji: '🗺️',
    ),
    _OnboardingPage(
      icon: Icons.person_search_rounded,
      title: 'Discover Villains',
      description:
          'Find fictional company-inspired villains lurking in every zone. Hear their taunts, learn their stories, and prepare for epic battle.',
      color: AppColors.secondary,
      emoji: '👿',
    ),
    _OnboardingPage(
      icon: Icons.sports_mma_rounded,
      title: 'Fight & Dominate',
      description:
          'Pick your hero team and battle in Solo, Duo, or Squad modes. Master abilities, team up with friends, and claim ultimate victory!',
      color: AppColors.accent,
      emoji: '🥊',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _heroAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _entranceScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.elasticOut),
    );
    _entranceOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _heroAnimController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _complete() async {
    await context.read<LocalStorageService>().setOnboardingComplete();
    if (mounted) context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        particleCount: 40,
        showGrid: true,
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with Skip button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Page counter
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentPage + 1} / ${_pages.length}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _complete,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (i) {
                    setState(() => _currentPage = i);
                    _entranceController.reset();
                    _entranceController.forward();
                  },
                  itemBuilder: (_, i) {
                    final p = _pages[i];
                    return AnimatedBuilder(
                      animation: _entranceController,
                      builder: (context, child) => Opacity(
                        opacity: _entranceOpacity.value,
                        child: Transform.scale(
                          scale: _entranceScale.value,
                          child: child,
                        ),
                      ),
                      child: _buildPage(p),
                    );
                  },
                ),
              ),

              // Dot indicators
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) {
                    final isActive = _currentPage == i;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      width: isActive ? 36 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: isActive
                            ? _pages[i].color
                            : AppColors.surface.withValues(alpha: 0.6),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color:
                                      _pages[i].color.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                ),
              ),

              // Navigation buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentPage > 0)
                      PixelButton(
                        label: 'Back',
                        icon: Icons.arrow_back_rounded,
                        color: AppColors.textSecondary,
                        isOutlined: true,
                        onTap: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        ),
                      )
                    else
                      const SizedBox(width: 100),
                    PixelButton(
                      label: _currentPage == _pages.length - 1
                          ? "LET'S GO!"
                          : 'Next',
                      icon: _currentPage == _pages.length - 1
                          ? Icons.rocket_launch_rounded
                          : Icons.arrow_forward_rounded,
                      color: _pages[_currentPage].color,
                      isLarge: _currentPage == _pages.length - 1,
                      showGlow: _currentPage == _pages.length - 1,
                      onTap: _currentPage == _pages.length - 1
                          ? _complete
                          : () => _pageController.nextPage(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon with glow
          AnimatedBuilder(
            animation: _heroAnimController,
            builder: (context, child) {
              final bounce = sin(_heroAnimController.value * pi) * 8;
              return Transform.translate(
                offset: Offset(0, -bounce),
                child: child,
              );
            },
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    page.color.withValues(alpha: 0.25),
                    page.color.withValues(alpha: 0.05),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: page.color.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
                border: Border.all(
                  color: page.color.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  page.emoji,
                  style: const TextStyle(fontSize: 56),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: page.color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(height: 20),

          // Description
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.7,
                  fontSize: 15,
                ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final String emoji;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.emoji,
  });
}
