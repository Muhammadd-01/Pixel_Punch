import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/pixel_punch_logo.dart';
import '../../services/game_state_service.dart';
import '../../game/models/game_enums.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

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
        child: SafeArea(
          child: isLandscape
              ? Row(
                  children: [
                    Expanded(flex: 2, child: _buildLandscapeBranding(context)),
                    Expanded(flex: 3, child: _buildLandscapeMenu(context)),
                  ],
                )
              : _buildPortraitContent(context),
        ),
      ),
    );
  }

  /// Responsive portrait layout (Default for mobile phone screen)
  Widget _buildPortraitContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          // Game Logo
          const PixelPunchLogoWidget(
            width: 140,
            height: 140,
            showShadow: true,
          ),
          const SizedBox(height: 8),
          Text(
            'Your Zone. Your Rivals. Your Victory.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 1.1,
                ),
          ),
          const SizedBox(height: 20),

          // Player Profile & Progress Card
          _buildPlayerStatsCard(context),
          const SizedBox(height: 24),

          // Primary Play Button
          _btn(
            context,
            Icons.play_arrow_rounded,
            'PLAY BRAWL',
            AppColors.primary,
            () => _showModeSelection(context),
            isLarge: true,
          ),
          const SizedBox(height: 12),
          _btn(
            context,
            Icons.face_retouching_natural,
            'VILLAIN LAB',
            const Color(0xFFE040FB),
            () => context.push('/villain-lab'),
          ),
          const SizedBox(height: 12),

          // Secondary Navigation Grid (2 x 2)
          Row(
            children: [
              Expanded(
                child: _btn(
                  context,
                  Icons.map,
                  'Zones',
                  AppColors.secondary,
                  () => context.push('/zones'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _btn(
                  context,
                  Icons.people,
                  'Heroes',
                  AppColors.accent,
                  () => context.push('/characters'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _btn(
                  context,
                  Icons.person,
                  'Profile',
                  AppColors.info,
                  () => context.push('/profile'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _btn(
                  context,
                  Icons.settings,
                  'Settings',
                  AppColors.textSecondary,
                  () => context.push('/settings'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Compact Player Card
  Widget _buildPlayerStatsCard(BuildContext context) {
    return Consumer<GameStateService>(
      builder: (_, gs, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Level ${gs.progress.playerLevel}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${gs.progress.wins}W - ${gs.progress.losses}L',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: gs.progress.levelProgress.clamp(0.0, 1.0),
                backgroundColor: AppColors.surfaceLight,
                valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'XP Progress',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  '${gs.progress.totalXp} / ${gs.progress.xpForNextLevel} XP',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Landscape Left Panel (Branding & Stats)
  Widget _buildLandscapeBranding(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const PixelPunchLogoWidget(
            width: 100,
            height: 100,
            showShadow: true,
          ),
          const SizedBox(height: 16),
          _buildPlayerStatsCard(context),
        ],
      ),
    );
  }

  /// Landscape Menu
  Widget _buildLandscapeMenu(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _btn(
            context,
            Icons.play_arrow_rounded,
            'PLAY',
            AppColors.primary,
            () => _showModeSelection(context),
            isLarge: true,
          ),
          const SizedBox(height: 12),
          _btn(
            context,
            Icons.face_retouching_natural,
            'VILLAIN LAB',
            const Color(0xFFE040FB),
            () => context.push('/villain-lab'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _btn(
                  context,
                  Icons.map,
                  'Zones',
                  AppColors.secondary,
                  () => context.push('/zones'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _btn(
                  context,
                  Icons.people,
                  'Characters',
                  AppColors.accent,
                  () => context.push('/characters'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _btn(
                  context,
                  Icons.person,
                  'Profile',
                  AppColors.info,
                  () => context.push('/profile'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _btn(
                  context,
                  Icons.settings,
                  'Settings',
                  AppColors.textSecondary,
                  () => context.push('/settings'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn(
    BuildContext ctx,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap, {
    bool isLarge = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: isLarge ? 20 : 16, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
            ),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: isLarge ? 28 : 22),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: isLarge ? 20 : 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: isLarge ? 3 : 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showModeSelection(BuildContext context) {
    showDialog(
      context: context,
      builder: (dc) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Select Mode', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _modeOpt(context, dc, GameMode.solo, Icons.person, 'Player vs AI (1v1)'),
            const SizedBox(height: 8),
            _modeOpt(context, dc, GameMode.duo, Icons.people, '2 Heroes vs 2 Villains (2v2)'),
            const SizedBox(height: 8),
            _modeOpt(context, dc, GameMode.squad, Icons.groups, '3 Heroes vs 3 Villains (3v3)'),
          ],
        ),
      ),
    );
  }

  Widget _modeOpt(
    BuildContext ctx,
    BuildContext dc,
    GameMode mode,
    IconData icon,
    String sub,
  ) {
    return InkWell(
      onTap: () {
        ctx.read<GameStateService>().setSelectedMode(mode);
        Navigator.pop(dc);
        ctx.push('/characters');
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.surfaceLight.withValues(alpha: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${mode.displayName} (${mode.shortName})',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
