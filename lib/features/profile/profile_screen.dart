import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/app_theme.dart';
import '../../game/models/game_enums.dart';
import '../../services/game_state_service.dart';
import '../../services/supabase_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = context.watch<SupabaseService>();
    final gameState = context.watch<GameStateService>();
    final progress = gameState.progress;
    final isAuth = supabase.isAuthenticated;
    final userEmail = supabase.currentUser?.email ?? 'Playing as Guest';
    final displayName = supabase.currentUser?.userMetadata?['display_name'] as String? ?? 'Brawler Guest';

    // Discovered and defeated villain counts
    int discoveredVillains = 0;
    int defeatedVillains = 0;
    for (final state in progress.villainStates.values) {
      if (state.isDiscovered) discoveredVillains++;
      if (state.isDefeated) defeatedVillains++;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Player Profile'),
        actions: [
          if (isAuth)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign Out',
              onPressed: () => context.go('/transition', extra: {'mode': 'logout'}),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'B',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userEmail,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isAuth
                              ? AppColors.success.withValues(alpha: 0.2)
                              : AppColors.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isAuth ? 'CLOUD SYNC ACTIVE' : 'LOCAL GUEST ACCOUNT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isAuth ? AppColors.success : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isAuth)
                  ElevatedButton(
                    onPressed: () => context.push('/login'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: const Text('Link Account', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Level & XP Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Brawler Level ${progress.playerLevel}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${progress.totalXp} / ${progress.xpForNextLevel} XP',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.levelProgress.clamp(0.0, 1.0),
                    backgroundColor: AppColors.surfaceLight,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Career Stats Grid
          Row(
            children: [
              Expanded(
                child: _buildStatBox('Total Matches', '${progress.totalMatches}', Icons.sports_mma, AppColors.info),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatBox('Victories', '${progress.wins}', Icons.emoji_events, AppColors.success),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatBox('Defeats', '${progress.losses}', Icons.close, AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildStatBox('Villains Found', '$discoveredVillains / 6', Icons.person_search, AppColors.secondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatBox('Villains Defeated', '$defeatedVillains / 6', Icons.check_circle, AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatBox('Heroes Owned', '${progress.unlockedCharacters.length} / 6', Icons.people, AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Recent Match History
          const Text(
            'Recent Match History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          if (gameState.matchHistory.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'No battles fought yet. Step into a zone to battle villains!',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...gameState.matchHistory.take(5).map((match) {
              final isWin = match.outcome == MatchOutcome.victory;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isWin ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isWin ? Icons.check_circle : Icons.cancel,
                      color: isWin ? AppColors.success : AppColors.error,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${match.mode.displayName} - ${match.zoneId.replaceAll('zone_', '').toUpperCase()}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            'Damage: ${match.damageDealt} dealt, ${match.damageTaken} taken (${match.durationSeconds}s)',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      isWin ? '+${match.xpEarned} XP' : '0 XP',
                      style: TextStyle(
                        color: isWin ? AppColors.accent : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
