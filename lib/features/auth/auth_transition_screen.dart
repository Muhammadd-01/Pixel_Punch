import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/pixel_punch_logo.dart';
import '../../services/audio_service.dart';
import '../../services/game_state_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';

/// What the in-between loading screen is doing.
enum AuthTransition { login, register, guest, logout }

/// Animated "buffering" screen shown after signing in / out. It does the
/// slow work (cloud sync, sign-out) behind the animation, then moves on:
/// to Home after signing in, back to Login after signing out.
class AuthTransitionScreen extends StatefulWidget {
  final AuthTransition mode;
  const AuthTransitionScreen({super.key, required this.mode});

  static AuthTransition parse(String? value) => AuthTransition.values.firstWhere(
        (m) => m.name == value,
        orElse: () => AuthTransition.login,
      );

  @override
  State<AuthTransitionScreen> createState() => _AuthTransitionScreenState();
}

class _AuthTransitionScreenState extends State<AuthTransitionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  late final AnimationController _progress =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  int _step = 0;

  bool get _isLogout => widget.mode == AuthTransition.logout;

  List<String> get _steps => switch (widget.mode) {
        AuthTransition.logout => [
            'Saving your progress...',
            'Signing you out...',
            'See you in the arena!',
          ],
        AuthTransition.guest => [
            'Setting up guest profile...',
            'Loading your villains...',
            'Entering the arena!',
          ],
        _ => [
            'Authenticating...',
            'Syncing your progress...',
            'Loading your villains...',
            'Entering the arena!',
          ],
      };

  @override
  void initState() {
    super.initState();
    _progress.addListener(() {
      final step = (_progress.value * _steps.length).floor().clamp(0, _steps.length - 1);
      if (step != _step) setState(() => _step = step);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final supabase = context.read<SupabaseService>();
    final storage = context.read<LocalStorageService>();
    final gs = context.read<GameStateService>();
    final sync = context.read<SyncService>();
    context.read<AudioService>().playSfx(_isLogout ? 'button_back' : 'special_activate');

    final animation = _progress.forward();
    Future<void> work() async {
      try {
        if (_isLogout) {
          await storage.saveProgress(gs.progress);
          await supabase.signOut();
          await storage.setGuestChosen(false);
        } else if (widget.mode == AuthTransition.guest) {
          await storage.setGuestChosen(true);
        } else if (supabase.isAuthenticated) {
          await storage.setGuestChosen(false);
          await sync.syncData(gs.progress);
          gs.replaceProgress(gs.progress);
        }
      } catch (e) {
        debugPrint('[AuthTransition] $e');
      }
    }

    // Never keep the player waiting on a slow network.
    await Future.wait([
      animation,
      work().timeout(const Duration(seconds: 6), onTimeout: () {}),
    ]);
    if (!mounted) return;
    context.go(_isLogout ? '/login' : '/home');
  }

  @override
  void dispose() {
    _spin.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _isLogout ? AppColors.secondary : AppColors.primary;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              colors: [Color(0xFF1F2B55), AppColors.background],
              radius: 1.1,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: AnimatedBuilder(
                    animation: _spin,
                    builder: (context, child) => CustomPaint(
                      painter: _EnergyRingsPainter(_spin.value, color),
                      child: child,
                    ),
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _spin,
                        builder: (context, child) => Transform.scale(
                          scale: 0.92 + 0.08 * math.sin(_spin.value * math.pi * 4),
                          child: child,
                        ),
                        child: const PixelPunchLogoWidget(width: 120, height: 120, showShadow: true),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    _steps[_step],
                    key: ValueKey(_step),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 220,
                  child: AnimatedBuilder(
                    animation: _progress,
                    builder: (context, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: Curves.easeInOut.transform(_progress.value),
                        minHeight: 8,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three orbiting energy arcs plus little sparks circling the logo.
class _EnergyRingsPainter extends CustomPainter {
  final double t;
  final Color color;
  _EnergyRingsPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final colors = [color, AppColors.accent, AppColors.secondary];
    for (int i = 0; i < 3; i++) {
      final r = size.width / 2 - 8 - i * 16;
      final start = (i.isEven ? 1 : -1) * t * math.pi * 2 * (1 + i * 0.5);
      final paint = Paint()
        ..color = colors[i].withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 - i.toDouble()
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3);
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, math.pi * 0.7, false, paint);
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), start + math.pi, math.pi * 0.35, false, paint);
    }
    for (int i = 0; i < 8; i++) {
      final a = t * math.pi * 2 + i * math.pi / 4;
      final r = size.width / 2 - 2 + 4 * math.sin(t * math.pi * 6 + i);
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * r,
        2.5,
        Paint()..color = AppColors.accent.withValues(alpha: 0.4 + 0.6 * ((i + t * 8) % 1)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EnergyRingsPainter old) => old.t != t || old.color != color;
}
