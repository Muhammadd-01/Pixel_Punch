import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/animated_background.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/pixel_button.dart';
import '../../core/widgets/pixel_punch_logo.dart';
import '../../core/widgets/shimmer_text.dart';
import '../../services/friends_service.dart';
import '../../services/game_state_service.dart';
import '../../game/models/game_enums.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _breatheController;
  late Animation<double> _logoFade;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;
  late Animation<double> _breathe;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0, 0.5, curve: Curves.easeOut),
      ),
    );
    _contentFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
    ));
    _breathe = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      body: AnimatedBackground(
        particleCount: 25,
        showGrid: true,
        showFloatingPixels: true,
        child: SafeArea(
          child: isLandscape
              ? Row(
                  children: [
                    Expanded(flex: 2, child: _buildBranding()),
                    Expanded(flex: 3, child: _buildMenu()),
                  ],
                )
              : _buildPortraitContent(),
        ),
      ),
    );
  }

  Widget _buildPortraitContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),

          // Animated Logo
          FadeTransition(
            opacity: _logoFade,
            child: AnimatedBuilder(
              animation: _breathe,
              builder: (_, child) =>
                  Transform.scale(scale: _breathe.value, child: child),
              child: const PixelPunchLogoWidget(
                width: 130,
                height: 130,
                showShadow: true,
              ),
            ),
          ),
          const SizedBox(height: 6),
          FadeTransition(
            opacity: _logoFade,
            child: const ShimmerText(
              text: 'Your Zone. Your Rivals. Your Victory.',
              shimmerColor: AppColors.accent,
              style: TextStyle(
                fontSize: 13,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Player Stats Card
          SlideTransition(
            position: _contentSlide,
            child: FadeTransition(
              opacity: _contentFade,
              child: _buildPlayerStatsCard(),
            ),
          ),
          const SizedBox(height: 22),

          // Main Action Buttons
          SlideTransition(
            position: _contentSlide,
            child: FadeTransition(
              opacity: _contentFade,
              child: Column(
                children: [
                  // PLAY BRAWL — Primary
                  PixelButton(
                    label: 'PLAY BRAWL',
                    icon: Icons.play_arrow_rounded,
                    color: AppColors.primary,
                    isLarge: true,
                    showGlow: true,
                    width: double.infinity,
                    onTap: () => _showModeSelection(context),
                  ),
                  const SizedBox(height: 12),

                  // Villain Lab
                  PixelButton(
                    label: 'VILLAIN LAB',
                    icon: Icons.face_retouching_natural,
                    color: const Color(0xFFE040FB),
                    width: double.infinity,
                    onTap: () => context.push('/villain-lab'),
                  ),
                  const SizedBox(height: 12),
                  PixelButton(
                    label: '3D ROYALE',
                    icon: Icons.public,
                    color: const Color(0xFF00E5FF),
                    width: double.infinity,
                    onTap: () => context.push('/royale'),
                  ),
                  const SizedBox(height: 12),

                  // 2x2 Grid + Friends
                  Row(
                    children: [
                      Expanded(
                        child: _menuTile(
                          icon: Icons.map_rounded,
                          label: 'Zones',
                          color: AppColors.secondary,
                          onTap: () => context.push('/zones'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _menuTile(
                          icon: Icons.people_rounded,
                          label: 'Heroes',
                          color: AppColors.accent,
                          onTap: () => context.push('/characters'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _menuTile(
                          icon: Icons.group_rounded,
                          label: 'Friends',
                          color: AppColors.success,
                          onTap: () => context.push('/friends'),
                          badge: context.watch<FriendsService>().pendingRequests.length,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _menuTile(
                          icon: Icons.person_rounded,
                          label: 'Profile',
                          color: AppColors.info,
                          onTap: () => context.push('/profile'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _menuTile(
                          icon: Icons.settings_rounded,
                          label: 'Settings',
                          color: AppColors.textSecondary,
                          onTap: () => context.push('/settings'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerStatsCard() {
    return Consumer<GameStateService>(
      builder: (_, gs, __) {
        final progress = gs.progress;
        final winRate = progress.totalMatches > 0
            ? (progress.wins / progress.totalMatches * 100).toInt()
            : 0;

        return GlowCard(
          glowColor: AppColors.primary,
          animate: false,
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              // Level + W/L row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.3),
                              AppColors.primary.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                color: AppColors.accent, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Level ${progress.playerLevel}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _miniStat('${progress.wins}', 'W',
                          AppColors.success),
                      const SizedBox(width: 8),
                      _miniStat('${progress.losses}', 'L',
                          AppColors.error),
                      const SizedBox(width: 8),
                      _miniStat('$winRate%', 'WR',
                          AppColors.accent),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // XP Progress Bar
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: progress.levelProgress.clamp(0.0, 1.0),
                      ),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOutCubic,
                      builder: (_, value, __) => LinearProgressIndicator(
                        value: value,
                        backgroundColor:
                            AppColors.surfaceLight.withValues(alpha: 0.5),
                        valueColor: AlwaysStoppedAnimation(
                          Color.lerp(
                              AppColors.primary, AppColors.accent, value)!,
                        ),
                        minHeight: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'XP Progress',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    '${progress.totalXp} / ${progress.xpForNextLevel} XP',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.15),
                color.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (badge > 0)
                Positioned(
                  top: -10,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Branding panel for landscape mode
  Widget _buildBranding() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _breathe,
            builder: (_, child) =>
                Transform.scale(scale: _breathe.value, child: child),
            child: const PixelPunchLogoWidget(
              width: 100,
              height: 100,
              showShadow: true,
            ),
          ),
          const SizedBox(height: 16),
          _buildPlayerStatsCard(),
        ],
      ),
    );
  }

  Widget _buildMenu() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          PixelButton(
            label: 'PLAY BRAWL',
            icon: Icons.play_arrow_rounded,
            color: AppColors.primary,
            isLarge: true,
            showGlow: true,
            width: double.infinity,
            onTap: () => _showModeSelection(context),
          ),
          const SizedBox(height: 12),
          PixelButton(
            label: 'VILLAIN LAB',
            icon: Icons.face_retouching_natural,
            color: const Color(0xFFE040FB),
            width: double.infinity,
            onTap: () => context.push('/villain-lab'),
          ),
          const SizedBox(height: 12),
          PixelButton(
            label: '3D ROYALE',
            icon: Icons.public,
            color: const Color(0xFF00E5FF),
            width: double.infinity,
            onTap: () => context.push('/royale'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _menuTile(
                  icon: Icons.map_rounded,
                  label: 'Zones',
                  color: AppColors.secondary,
                  onTap: () => context.push('/zones'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _menuTile(
                  icon: Icons.people_rounded,
                  label: 'Heroes',
                  color: AppColors.accent,
                  onTap: () => context.push('/characters'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _menuTile(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  color: AppColors.info,
                  onTap: () => context.push('/profile'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _menuTile(
                  icon: Icons.group_rounded,
                  label: 'Friends',
                  color: AppColors.success,
                  onTap: () => context.push('/friends'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _menuTile(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  color: AppColors.textSecondary,
                  onTap: () => context.push('/settings'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showModeSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (dc) => _ModeSelectionSheet(
        onModeSelected: (mode) {
          context.read<GameStateService>().setSelectedMode(mode);
          Navigator.pop(dc);
          context.push('/characters');
        },
      ),
    );
  }
}

/// Bottom sheet for mode selection — much more polished than a dialog.
class _ModeSelectionSheet extends StatelessWidget {
  final ValueChanged<GameMode> onModeSelected;

  const _ModeSelectionSheet({required this.onModeSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'SELECT MODE',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose your battle style',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),

            _modeCard(
              mode: GameMode.solo,
              icon: Icons.person_rounded,
              emoji: '⚔️',
              subtitle: '1 Hero vs 1 Villain',
              color: AppColors.primary,
            ),
            const SizedBox(height: 10),
            _modeCard(
              mode: GameMode.duo,
              icon: Icons.people_rounded,
              emoji: '🤝',
              subtitle: '2 Heroes vs 2 Villains',
              color: AppColors.secondary,
            ),
            const SizedBox(height: 10),
            _modeCard(
              mode: GameMode.squad,
              icon: Icons.groups_rounded,
              emoji: '🔥',
              subtitle: '3 Heroes vs 3 Villains',
              color: AppColors.accent,
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 10),
            _modeCard(
              mode: GameMode.duo,
              icon: Icons.wifi_rounded,
              emoji: '🌐',
              subtitle: 'Play with friends online',
              color: const Color(0xFF00BFA5),
              customLabel: 'ONLINE MULTIPLAYER',
              onTapOverride: () {
                Navigator.pop(context);
                context.push('/lobby');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeCard({
    required GameMode mode,
    required IconData icon,
    required String emoji,
    required String subtitle,
    required Color color,
    String? customLabel,
    VoidCallback? onTapOverride,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTapOverride ?? () => onModeSelected(mode),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.15),
                color.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customLabel ?? '${mode.displayName} (${mode.shortName})',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: color.withValues(alpha: 0.6), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
