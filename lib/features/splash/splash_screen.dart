import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/game_state_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/supabase_service.dart';
import '../../services/custom_villain_service.dart';
import '../../services/sync_service.dart';
import '../../services/audio_service.dart';
import '../../core/widgets/pixel_punch_logo.dart';
import '../../core/widgets/shimmer_text.dart';
import '../../app/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _taglineOpacity;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressOpacity;
  bool _isLoading = true;
  String _loadingText = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    _logoController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _progressController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _logoController, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn)));
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _logoController,
            curve: const Interval(0.5, 1.0, curve: Curves.easeIn)));
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _progressOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _progressController, curve: Curves.easeIn));

    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _progressController.forward();
    });
  }

  Future<void> _initializeApp() async {
    try {
      final gameState = context.read<GameStateService>();
      final storage = context.read<LocalStorageService>();
      final supabase = context.read<SupabaseService>();
      final audio = context.read<AudioService>();
      final customVillains = context.read<CustomVillainService>();
      final stopwatch = Stopwatch()..start();

      // Step 1: Load game data
      if (mounted) setState(() => _loadingText = 'Loading game data...');
      await gameState.loadGameData();

      // Step 2: Load saved progress
      if (mounted) setState(() => _loadingText = 'Loading your progress...');
      await gameState.loadSavedData(storage);
      await customVillains.load();

      // Step 3: Initialize audio
      if (mounted) setState(() => _loadingText = 'Preparing sounds...');
      await audio.initialize(settings: await storage.loadSettings());

      // Step 4: Check onboarding
      final onboardingDone = await storage.isOnboardingComplete();

      // Step 5: Initialize Supabase safely in background
      if (mounted) setState(() => _loadingText = 'Connecting...');
      try {
        await supabase.initialize().timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Supabase init skipped: $e');
      }
      if (!mounted) return;
      if (supabase.isAuthenticated) {
        // Merge cloud progress in the background; never block startup.
        final sync = context.read<SyncService>();
        sync.syncData(gameState.progress).then((_) {
          gameState.replaceProgress(gameState.progress);
        }).catchError((Object e) {
          debugPrint('Startup sync failed: $e');
        });
      }

      // Keep the logo on screen briefly, but never longer than needed.
      final remaining = 2000 - stopwatch.elapsedMilliseconds;
      if (remaining > 0) await Future.delayed(Duration(milliseconds: remaining));
      if (!mounted) return;

      if (mounted) setState(() => _loadingText = 'Ready!');
      setState(() => _isLoading = false);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      // First install: onboarding. Afterwards: straight home when signed in
      // (or playing as guest), otherwise the login screen.
      final guest = await storage.isGuestChosen();
      if (!mounted) return;
      context.go(!onboardingDone
          ? '/onboarding'
          : (supabase.isAuthenticated || guest)
              ? '/home'
              : '/login');
    } catch (e) {
      debugPrint('Splash init error: $e');
      if (mounted) {
        setState(() => _loadingText = 'Something went wrong...');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.go('/onboarding');
      }
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.background,
              AppColors.backgroundLight,
              Color(0xFF0A1628),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with pulse + entrance animation
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) => Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(scale: _logoScale.value, child: child),
                ),
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) =>
                      Transform.scale(scale: _pulseAnimation.value, child: child),
                  child: _buildLogo(),
                ),
              ),
              const SizedBox(height: 24),

              // Tagline with shimmer
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) =>
                    Opacity(opacity: _taglineOpacity.value, child: child),
                child: const ShimmerText(
                  text: 'Your Zone. Your Rivals. Your Victory.',
                  shimmerColor: AppColors.accent,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Loading indicator + text
              FadeTransition(
                opacity: _progressOpacity,
                child: Column(
                  children: [
                    if (_isLoading)
                      SizedBox(
                        width: 200,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            backgroundColor: AppColors.surface,
                            valueColor:
                                AlwaysStoppedAnimation(AppColors.primary),
                            minHeight: 4,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _loadingText,
                        key: ValueKey(_loadingText),
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
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

  Widget _buildLogo() {
    return const PixelPunchLogoWidget(
      width: 240,
      height: 240,
      showShadow: true,
    );
  }
}
