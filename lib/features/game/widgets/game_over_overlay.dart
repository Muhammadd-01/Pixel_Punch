import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app/app_theme.dart';
import '../../../game/models/game_enums.dart';
import '../../../services/game_state_service.dart';

class GameOverOverlay extends StatefulWidget {
  final MatchOutcome outcome;
  final int damageDealt;
  final int damageTaken;
  final int duration;
  final int villainsDefeated;
  final int villainsTotal;
  final MatchRewards? rewards;
  final VoidCallback onRetry;
  final VoidCallback onQuit;

  const GameOverOverlay({
    super.key,
    required this.outcome,
    required this.damageDealt,
    required this.damageTaken,
    required this.duration,
    this.villainsDefeated = 0,
    this.villainsTotal = 0,
    this.rewards,
    required this.onRetry,
    required this.onQuit,
  });

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _confettiController;
  late AnimationController _pulseController;

  late Animation<double> _bgFade;
  late Animation<double> _cardScale;
  late Animation<double> _cardFade;
  late Animation<double> _titleSlide;
  late Animation<double> _statsFade;
  late Animation<double> _buttonsFade;
  late Animation<double> _pulse;

  final List<_ConfettiParticle> _confetti = [];
  final _rng = Random();

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _bgFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0, 0.3, curve: Curves.easeOut),
      ),
    );
    _cardScale = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.15, 0.5, curve: Curves.elasticOut),
      ),
    );
    _cardFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.15, 0.45, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<double>(begin: -30, end: 0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.25, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _statsFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.45, 0.75, curve: Curves.easeOut),
      ),
    );
    _buttonsFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.7, 1, curve: Curves.easeOut),
      ),
    );
    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Generate confetti for victory
    if (widget.outcome == MatchOutcome.victory) {
      for (int i = 0; i < 60; i++) {
        _confetti.add(_ConfettiParticle(
          x: _rng.nextDouble(),
          y: -_rng.nextDouble() * 0.3,
          speed: 0.3 + _rng.nextDouble() * 0.7,
          wobble: _rng.nextDouble() * 2 * pi,
          color: [
            AppColors.primary,
            AppColors.accent,
            AppColors.secondary,
            Colors.pinkAccent,
            Colors.greenAccent,
            Colors.purpleAccent,
          ][_rng.nextInt(6)],
          size: 4 + _rng.nextDouble() * 6,
          rotation: _rng.nextDouble() * pi,
        ));
      }
      _confettiController.repeat();
    }

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _confettiController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVictory = widget.outcome == MatchOutcome.victory;
    final color = isVictory ? AppColors.accent : AppColors.error;
    final r = widget.rewards;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _entranceController,
        _confettiController,
        _pulseController,
      ]),
      builder: (context, _) {
        return Stack(
          children: [
            // Background fade
            Container(
              color: Colors.black.withValues(alpha: 0.85 * _bgFade.value),
            ),

            // Confetti layer
            if (isVictory && _confetti.isNotEmpty)
              CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _ConfettiPainter(
                  particles: _confetti,
                  progress: _confettiController.value,
                ),
              ),

            // Main content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 16),
                  child: Opacity(
                    opacity: _cardFade.value,
                    child: Transform.scale(
                      scale: _cardScale.value,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 520),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.surface,
                              color.withValues(alpha: 0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: color.withValues(alpha: 0.6),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(
                                  alpha: 0.2 +
                                      _pulse.value * 0.15 -
                                      0.95 * 0.15),
                              blurRadius: 30 + (_pulse.value - 0.95) * 100,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Title with entrance animation
                            Transform.translate(
                              offset: Offset(0, _titleSlide.value),
                              child: Column(
                                children: [
                                  // Animated icon
                                  AnimatedBuilder(
                                    animation: _pulse,
                                    builder: (_, child) => Transform.scale(
                                      scale: _pulse.value,
                                      child: child,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            color.withValues(alpha: 0.3),
                                            color.withValues(alpha: 0.05),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: color.withValues(alpha: 0.5),
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        isVictory
                                            ? Icons.emoji_events_rounded
                                            : Icons
                                                .sentiment_very_dissatisfied_rounded,
                                        size: 48,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    isVictory ? 'VICTORY!' : 'DEFEAT',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: color,
                                      letterSpacing: 5,
                                      shadows: [
                                        Shadow(
                                          color: color.withValues(alpha: 0.6),
                                          blurRadius: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isVictory
                                        ? 'All enemies vanquished!'
                                        : 'Better luck next time...',
                                    style: TextStyle(
                                      color: AppColors.textSecondary
                                          .withValues(alpha: 0.8),
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Stats grid with staggered fade
                            Opacity(
                              opacity: _statsFade.value,
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _statCard(
                                          'VILLAINS KO',
                                          '${widget.villainsDefeated}/${widget.villainsTotal}',
                                          Icons.sports_mma_rounded,
                                          Colors.redAccent,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _statCard(
                                          'DMG DEALT',
                                          '${widget.damageDealt}',
                                          Icons.flash_on_rounded,
                                          Colors.orangeAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _statCard(
                                          'DMG TAKEN',
                                          '${widget.damageTaken}',
                                          Icons.shield_rounded,
                                          Colors.blueAccent,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _statCard(
                                          'TIME',
                                          '${widget.duration ~/ 60}:${(widget.duration % 60).toString().padLeft(2, '0')}',
                                          Icons.timer_rounded,
                                          Colors.cyanAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Rewards section
                            if (r != null)
                              Opacity(
                                opacity: _statsFade.value,
                                child: Column(
                                  children: [
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.accent
                                                .withValues(alpha: 0.15),
                                            AppColors.accent
                                                .withValues(alpha: 0.05),
                                          ],
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: AppColors.accent
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.star_rounded,
                                              color: AppColors.accent,
                                              size: 22),
                                          const SizedBox(width: 8),
                                          Text(
                                            '+${r.xpEarned} XP',
                                            style: const TextStyle(
                                              color: AppColors.accent,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 18,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                          if (r.leveledUp) ...[
                                            const SizedBox(width: 16),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.accent
                                                    .withValues(alpha: 0.3),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'LEVEL UP! Lv ${r.level}',
                                                style: const TextStyle(
                                                  color: AppColors.accent,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    for (final z in r.unlockedZones)
                                      _unlock(Icons.map_rounded,
                                          'New zone unlocked: $z'),
                                    for (final h in r.unlockedHeroes)
                                      _unlock(Icons.person_add_rounded,
                                          'New hero unlocked: $h'),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 20),

                            // Action buttons with fade in
                            Opacity(
                              opacity: _buttonsFade.value,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: widget.onQuit,
                                      icon: const Icon(Icons.home_rounded,
                                          size: 20),
                                      label: const Text('MENU'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            AppColors.textSecondary,
                                        side: const BorderSide(
                                            color: Colors.white24),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed: widget.onRetry,
                                      icon: const Icon(Icons.replay_rounded,
                                          size: 20),
                                      label: Text(
                                        isVictory
                                            ? 'PLAY AGAIN'
                                            : 'TRY AGAIN',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: color,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        elevation: 8,
                                        shadowColor:
                                            color.withValues(alpha: 0.5),
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
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _unlock(IconData icon, String text) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.success.withValues(alpha: 0.2),
              AppColors.success.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.success.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.success, size: 20),
            const SizedBox(width: 10),
            Text(text,
                style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ],
        ),
      );

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              )),
        ],
      ),
    );
  }
}

// ===========================================================================
// Confetti System
// ===========================================================================

class _ConfettiParticle {
  final double x;
  final double y;
  final double speed;
  final double wobble;
  final Color color;
  final double size;
  final double rotation;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.wobble,
    required this.color,
    required this.size,
    required this.rotation,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = progress;
      final px = p.x * size.width + sin(t * 6 + p.wobble) * 30;
      final py = p.y * size.height + t * p.speed * size.height;
      if (py > size.height + 20) continue;

      final fade = (1 - (py / size.height)).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation + t * 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(1),
        ),
        Paint()..color = p.color.withValues(alpha: 0.8 * fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
