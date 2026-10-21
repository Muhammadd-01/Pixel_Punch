import 'package:flutter/material.dart';
import '../../../app/app_theme.dart';
import '../../../game/models/game_enums.dart';
import '../../../services/game_state_service.dart';

class GameOverOverlay extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isVictory = outcome == MatchOutcome.victory;
    final color = isVictory ? AppColors.accent : AppColors.error;
    final r = rewards;

    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 1),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color, width: 3),
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 30),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isVictory
                              ? Icons.emoji_events
                              : Icons.sentiment_very_dissatisfied,
                          size: 40,
                          color: color,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isVictory ? 'VICTORY!' : 'DEFEAT',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: color,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _stat('Villains KO', '$villainsDefeated/$villainsTotal', Icons.sports_mma),
                        _stat('Damage Dealt', '$damageDealt', Icons.flash_on),
                        _stat('Damage Taken', '$damageTaken', Icons.shield),
                        _stat('Time', '${duration ~/ 60}:${(duration % 60).toString().padLeft(2, '0')}', Icons.timer),
                      ],
                    ),
                    if (r != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        '+${r.xpEarned} XP${r.leveledUp ? '   ·   LEVEL UP! Lv ${r.level}' : ''}',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      for (final z in r.unlockedZones)
                        _unlock(Icons.map, 'New zone unlocked: $z'),
                      for (final h in r.unlockedHeroes)
                        _unlock(Icons.person_add, 'New hero unlocked: $h'),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: onQuit,
                          icon: const Icon(Icons.home, size: 18),
                          label: const Text('Menu'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.replay, size: 18),
                          label: Text(isVictory ? 'Play Again' : 'Try Again'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _unlock(IconData icon, String text) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.success, size: 18),
            const SizedBox(width: 8),
            Text(text,
                style: const TextStyle(
                    color: AppColors.success, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _stat(String label, String value, IconData icon) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppColors.secondary),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }
}
