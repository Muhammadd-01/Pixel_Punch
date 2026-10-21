import 'package:flutter/material.dart';
import '../../../app/app_theme.dart';

class PauseOverlay extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback? onRestart;
  final VoidCallback onQuit;

  const PauseOverlay({
    super.key,
    required this.onResume,
    this.onRestart,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primaryLight.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'PAUSED',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume Game'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(190, 46),
                  ),
                ),
                if (onRestart != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onRestart,
                    icon: const Icon(Icons.replay),
                    label: const Text('Restart Match'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(190, 46),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onQuit,
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Quit to Menu'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(190, 46),
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
