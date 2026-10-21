import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/animated_background.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/pixel_button.dart';
import '../../services/game_state_service.dart';
import '../../game/models/fighter_data.dart';
import '../../game/render/character_painter.dart';

class CharacterSelectionScreen extends StatefulWidget {
  const CharacterSelectionScreen({super.key});

  @override
  State<CharacterSelectionScreen> createState() =>
      _CharacterSelectionScreenState();
}

class _CharacterSelectionScreenState extends State<CharacterSelectionScreen>
    with TickerProviderStateMixin {
  int _focusedIndex = 0;
  late AnimationController _entranceController;
  late AnimationController _selectPulse;
  late Animation<double> _headerFade;
  late Animation<double> _gridFade;
  late Animation<double> _detailsFade;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _selectPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _headerFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0, 0.4, curve: Curves.easeOut),
      ),
    );
    _gridFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );
    _detailsFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _selectPulse.dispose();
    super.dispose();
  }

  void _onHeroTap(int index, FighterData hero, GameStateService gs) {
    setState(() => _focusedIndex = index);
    if (gs.isHeroUnlocked(hero)) {
      gs.toggleHeroSelection(hero.id);
      _selectPulse.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBackground(
        particleCount: 15,
        showGrid: true,
        showFloatingPixels: false,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _entranceController,
            builder: (context, _) {
              return Consumer<GameStateService>(
                builder: (context, gs, _) {
                  final heroes = gs.heroes;
                  if (heroes.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final focusedHero =
                      heroes[_focusedIndex.clamp(0, heroes.length - 1)];
                  final requiredCount = gs.selectedMode.friendlyCount;
                  final isTeamReady =
                      gs.selectedHeroIds.length == requiredCount;

                  return isLandscape
                      ? Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildRosterGrid(heroes, gs),
                            ),
                            Expanded(
                              flex: 3,
                              child: _buildHeroDetailsCard(
                                  focusedHero, isTeamReady, requiredCount, gs),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            // Header
                            FadeTransition(
                              opacity: _headerFade,
                              child: _buildHeader(gs),
                            ),
                            const SizedBox(height: 8),

                            // Roster grid
                            FadeTransition(
                              opacity: _gridFade,
                              child: Container(
                                height: 200,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                child: GridView.builder(
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 1.45,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                                  itemCount: heroes.length,
                                  itemBuilder: (context, index) =>
                                      _buildHeroCard(
                                    heroes[index],
                                    index,
                                    gs,
                                    isCompact: true,
                                  ),
                                ),
                              ),
                            ),

                            // Details
                            Expanded(
                              child: FadeTransition(
                                opacity: _detailsFade,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 8, 16, 16),
                                  child: _buildHeroDetailsCard(
                                    focusedHero,
                                    isTeamReady,
                                    requiredCount,
                                    gs,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(GameStateService gs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimary),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SELECT HEROES',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                Text(
                  '${gs.selectedHeroIds.length}/${gs.selectedMode.friendlyCount} selected · ${gs.selectedMode.displayName}',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Selected heroes indicators
          Row(
            children: List.generate(gs.selectedMode.friendlyCount, (i) {
              final selected = i < gs.selectedHeroIds.length;
              return Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : AppColors.surfaceLight,
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : Colors.white12,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.primary, size: 14)
                    : const Icon(Icons.add_rounded,
                        color: Colors.white24, size: 14),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildRosterGrid(List<FighterData> heroes, GameStateService gs) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.95,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: heroes.length,
      itemBuilder: (context, index) {
        return _buildHeroCard(heroes[index], index, gs, isCompact: false);
      },
    );
  }

  Widget _buildHeroCard(
    FighterData hero,
    int index,
    GameStateService gs, {
    required bool isCompact,
  }) {
    final unlocked = gs.isHeroUnlocked(hero);
    final inTeam = gs.selectedHeroIds.contains(hero.id);
    final isFocused = index == _focusedIndex;

    return GestureDetector(
      onTap: () => _onHeroTap(index, hero, gs),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: inTeam
                ? [
                    hero.color.withValues(alpha: 0.25),
                    hero.color.withValues(alpha: 0.08),
                  ]
                : isFocused
                    ? [
                        AppColors.surfaceLight.withValues(alpha: 0.8),
                        AppColors.surfaceLight.withValues(alpha: 0.4),
                      ]
                    : [
                        AppColors.surface,
                        AppColors.surface.withValues(alpha: 0.8),
                      ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: inTeam
                ? hero.color.withValues(alpha: 0.7)
                : (isFocused
                    ? Colors.white30
                    : Colors.white10),
            width: inTeam ? 2.5 : 1,
          ),
          boxShadow: inTeam
              ? [
                  BoxShadow(
                    color: hero.color.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Center(
              child: isCompact
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _heroFigure(hero, 48,
                            unlocked: gs.isHeroUnlocked(hero)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hero.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: unlocked
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                hero.archetype
                                    .replaceAll('_', ' ')
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: inTeam
                                      ? hero.color
                                      : AppColors.accent,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _heroFigure(hero, 72,
                            unlocked: gs.isHeroUnlocked(hero)),
                        const SizedBox(height: 8),
                        Text(
                          hero.name,
                          style: TextStyle(
                            color: unlocked
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          hero.archetype
                              .replaceAll('_', ' ')
                              .toUpperCase(),
                          style: TextStyle(
                            color:
                                inTeam ? hero.color : AppColors.accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
            if (inTeam)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: hero.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: hero.color.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 11,
                  ),
                ),
              ),
            if (!unlocked)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Colors.orange,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroDetailsCard(
    FighterData focusedHero,
    bool isTeamReady,
    int requiredCount,
    GameStateService gs,
  ) {
    return GlowCard(
      glowColor: focusedHero.color,
      animate: false,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Hero preview with colored border
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      focusedHero.color.withValues(alpha: 0.2),
                      focusedHero.color.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: focusedHero.color.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: _heroFigure(focusedHero, 56,
                    unlocked: gs.isHeroUnlocked(focusedHero)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      focusedHero.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: focusedHero.color,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      focusedHero.title,
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            focusedHero.biography,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white10),
          const SizedBox(height: 10),

          // Stats with themed colors
          _buildStatBar('Health', focusedHero.baseHealth, 160,
              focusedHero.color),
          _buildStatBar(
              'Damage', focusedHero.attackDamage, 30, Colors.orangeAccent),
          _buildStatBar(
              'Speed', focusedHero.moveSpeed.toInt(), 240, Colors.cyanAccent),
          _buildStatBar(
              'Defense', focusedHero.defense, 30, Colors.blueAccent),

          const SizedBox(height: 12),
          // Special Ability Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.12),
                  AppColors.accent.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.flash_on_rounded,
                      color: AppColors.accent, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (gs
                                    .getAbility(focusedHero.specialAbility)
                                    ?.name ??
                                focusedHero.specialAbility
                                    .replaceAll('_', ' '))
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (gs.getAbility(focusedHero.specialAbility) !=
                          null)
                        Text(
                          gs
                              .getAbility(focusedHero.specialAbility)!
                              .description,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textPrimary),
                        ),
                      Text(
                        'Cooldown: ${gs.getAbility(focusedHero.specialAbility)?.cooldown ?? focusedHero.specialCooldown}s',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (!gs.isHeroUnlocked(focusedHero)) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded,
                      color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      focusedHero.unlockRequirement ?? 'Keep playing',
                      style: const TextStyle(
                          color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Zone selection
          InkWell(
            onTap: () => context.push('/zones'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.secondary.withValues(alpha: 0.1),
                    AppColors.secondary.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.map_rounded,
                      color: AppColors.secondary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Zone: ${gs.getZone(gs.selectedZoneId)?.name ?? 'Arena'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text('Change',
                      style: TextStyle(
                          color: AppColors.secondary.withValues(alpha: 0.7),
                          fontSize: 12)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      color: AppColors.secondary.withValues(alpha: 0.5),
                      size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Launch button
          PixelButton(
            label: isTeamReady
                ? 'FIGHT IN ${(gs.getZone(gs.selectedZoneId)?.name ?? "Arena").toUpperCase()}'
                : 'SELECT $requiredCount HERO${requiredCount > 1 ? "ES" : ""}',
            icon: isTeamReady
                ? Icons.sports_mma_rounded
                : Icons.touch_app_rounded,
            color: isTeamReady ? AppColors.primary : AppColors.textSecondary,
            isLarge: true,
            showGlow: isTeamReady,
            width: double.infinity,
            enabled: isTeamReady,
            onTap: () {
              context.push(
                '/game',
                extra: {
                  'zoneId': gs.selectedZoneId,
                  'mode': gs.selectedMode.name,
                  'heroIds': gs.selectedHeroIds,
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _heroFigure(FighterData hero, double size,
      {required bool unlocked}) {
    return Opacity(
      opacity: unlocked ? 1 : 0.4,
      child: SizedBox(
        width: size * 0.75,
        height: size,
        child: CustomPaint(
          painter: CharacterPreviewPainter(
            CharacterLook(
              color: hero.color,
              archetype: hero.archetype,
              isVillain: false,
              skin: CharacterLook.skinFor(hero.id),
            ),
            pose: const CharacterPose(facing: Offset(1, 0.3)),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBar(String label, int value, int max, Color color) {
    final progress = (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 55,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (_, val, __) => LinearProgressIndicator(
                  value: val,
                  backgroundColor: AppColors.surfaceLight,
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 6,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
