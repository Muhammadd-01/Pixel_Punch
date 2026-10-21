import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/game_state_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/supabase_service.dart';
import '../../services/custom_villain_service.dart';
import '../../services/sync_service.dart';
import '../../core/widgets/pixel_punch_logo.dart';
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
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _taglineOpacity;
  late Animation<double> _pulseAnimation;
  bool _isLoading = true;

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

    _logoController.forward();
  }

  Future<void> _initializeApp() async {
    try {
      final gameState = context.read<GameStateService>();
      final storage = context.read<LocalStorageService>();
      final supabase = context.read<SupabaseService>();

      final customVillains = context.read<CustomVillainService>();
      final stopwatch = Stopwatch()..start();

      await gameState.loadGameData();
      await gameState.loadSavedData(storage);
      await customVillains.load();
      final onboardingDone = await storage.isOnboardingComplete();


      // Initialize Supabase safely in background
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
      final remaining = 1600 - stopwatch.elapsedMilliseconds;
      if (remaining > 0) await Future.delayed(Duration(milliseconds: remaining));
      if (!mounted) return;
      setState(() => _isLoading = false);
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      context.go(onboardingDone ? '/home' : '/onboarding');
    } catch (e) {
      debugPrint('Splash init error: $e');
      if (mounted) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) context.go('/onboarding');
      }
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
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
            colors: [AppColors.background, AppColors.backgroundLight, Color(0xFF0A1628)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) =>
                    Opacity(opacity: _taglineOpacity.value, child: child),
                child: Text(
                  'Your Zone. Your Rivals. Your Victory.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary, letterSpacing: 1.5),
                ),
              ),
              const SizedBox(height: 48),
              if (_isLoading)
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: AppColors.surface,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    borderRadius: BorderRadius.circular(4),
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
