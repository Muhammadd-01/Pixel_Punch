import 'package:flutter/material.dart';
import '../../../app/app_theme.dart';
import '../../../game/models/game_enums.dart';

class GameOverOverlay extends StatelessWidget {
  final MatchOutcome outcome;
  final int damageDealt;
  final int damageTaken;
  final int duration;
  final VoidCallback onRetry;
  final VoidCallback onQuit;

  const GameOverOverlay({
    super.key,
    required this.outcome,
    required this.damageDealt,
    required this.damageTaken,
    required this.duration,
    required this.onRetry,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    final isVictory = outcome == MatchOutcome.victory;

    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isVictory ? AppColors.accent : AppColors.error,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: (isVictory ? AppColors.accent : AppColors.error)
                    .withValues(alpha: 0.35),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVictory ? Icons.emoji_events : Icons.sentiment_very_dissatisfied,
                size: 56,
                color: isVictory ? AppColors.accent : AppColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                isVictory ? 'VICTORY!' : 'DEFEAT',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isVictory ? AppColors.accent : AppColors.error,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 18),
              _buildStat('Damage Dealt', damageDealt.toString()),
              _buildStat('Damage Taken', damageTaken.toString()),
              _buildStat('Duration', '${duration}s'),
              if (isVictory)
                _buildStat('XP Earned', '+50 XP', color: AppColors.accent),
              const SizedBox(height: 20),
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
                    label: const Text('Play Again'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
