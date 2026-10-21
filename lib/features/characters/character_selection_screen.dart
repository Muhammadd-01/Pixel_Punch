import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/app_theme.dart';
import '../../services/game_state_service.dart';
import '../../game/models/fighter_data.dart';
import '../../game/render/character_painter.dart';

class CharacterSelectionScreen extends StatefulWidget {
  const CharacterSelectionScreen({super.key});

  @override
  State<CharacterSelectionScreen> createState() =>
      _CharacterSelectionScreenState();
}

class _CharacterSelectionScreenState extends State<CharacterSelectionScreen> {
  int _focusedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Consumer<GameStateService>(
          builder: (_, gs, __) => Text(
            'Select Hero (${gs.selectedHeroIds.length}/${gs.selectedMode.friendlyCount}) - ${gs.selectedMode.displayName}',
            style: const TextStyle(fontSize: 16),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: Consumer<GameStateService>(
        builder: (context, gs, _) {
          final heroes = gs.heroes;
          if (heroes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final focusedHero = heroes[_focusedIndex.clamp(0, heroes.length - 1)];
          final requiredCount = gs.selectedMode.friendlyCount;
          final isTeamReady = gs.selectedHeroIds.length == requiredCount;

          return SafeArea(
            child: isLandscape
                ? Row(
                    children: [
                      // Roster Grid on left
                      Expanded(
                        flex: 3,
                        child: _buildRosterGrid(heroes, gs),
                      ),
                      // Details on right
                      Expanded(
                        flex: 3,
                        child: _buildHeroDetailsCard(
                          focusedHero,
                          isTeamReady,
                          requiredCount,
                          gs,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      // Compact Roster Grid at top (takes ~190 height)
                      Container(
                        height: 195,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 1.45,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: heroes.length,
                          itemBuilder: (context, index) {
                            return _buildHeroCard(heroes[index], index, gs, isCompact: true);
                          },
                        ),
                      ),

                      // Scrollable Details & Action at bottom
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: _buildHeroDetailsCard(
                            focusedHero,
                            isTeamReady,
                            requiredCount,
                            gs,
                          ),
                        ),
                      ),
                    ],
                  ),
          );
        },
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
      onTap: () {
        setState(() => _focusedIndex = index);
        if (unlocked) {
          gs.toggleHeroSelection(hero.id);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isFocused ? AppColors.surfaceLight : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: inTeam
                ? AppColors.primary
                : (isFocused ? Colors.white38 : Colors.white12),
            width: inTeam ? 2.5 : 1,
          ),
          boxShadow: inTeam
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
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
                        _heroFigure(hero, 48, unlocked: gs.isHeroUnlocked(hero)),
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
                                hero.archetype.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.accent,
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
                        _heroFigure(hero, 72, unlocked: gs.isHeroUnlocked(hero)),
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
                          hero.archetype.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.accent,
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
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 11,
                  ),
                ),
              ),
            if (!unlocked)
              Positioned(
                top: 4,
                left: 4,
                child: const Icon(
                  Icons.lock,
                  color: Colors.orange,
                  size: 14,
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _heroFigure(focusedHero, 66, unlocked: gs.isHeroUnlocked(focusedHero)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      focusedHero.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      focusedHero.title,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
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
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),

          // Stats
          _buildStatBar('Health', focusedHero.baseHealth, 160, Colors.redAccent),
          _buildStatBar('Damage', focusedHero.attackDamage, 30, Colors.orangeAccent),
          _buildStatBar('Speed', focusedHero.moveSpeed.toInt(), 240, Colors.cyanAccent),
          _buildStatBar('Defense', focusedHero.defense, 30, Colors.blueAccent),

          const SizedBox(height: 10),
          // Special Ability Card
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.flash_on, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Special: ${(gs.getAbility(focusedHero.specialAbility)?.name ?? focusedHero.specialAbility.replaceAll('_', ' ')).toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                      if (gs.getAbility(focusedHero.specialAbility) != null)
                        Text(
                          gs.getAbility(focusedHero.specialAbility)!.description,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textPrimary),
                        ),
                      Text(
                        'Cooldown: ${gs.getAbility(focusedHero.specialAbility)?.cooldown ?? focusedHero.specialCooldown}s',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (!gs.isHeroUnlocked(focusedHero)) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.lock, color: Colors.orange, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Unlock: ${focusedHero.unlockRequirement ?? 'Keep playing'}',
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          InkWell(
            onTap: () => context.push('/zones'),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.map, color: AppColors.secondary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Zone: ${gs.getZone(gs.selectedZoneId)?.name ?? 'Arena'}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                  const Text('Change',
                      style: TextStyle(color: AppColors.secondary, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Launch button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isTeamReady
                  ? () {
                      context.push(
                        '/game',
                        extra: {
                          'zoneId': gs.selectedZoneId,
                          'mode': gs.selectedMode.name,
                          'heroIds': gs.selectedHeroIds,
                        },
                      );
                    }
                  : null,
              icon: const Icon(Icons.sports_mma),
              label: Text(
                isTeamReady
                    ? 'Fight in ${gs.getZone(gs.selectedZoneId)?.name ?? "Arena"}'
                    : 'Select $requiredCount Hero${requiredCount > 1 ? "es" : ""}',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroFigure(FighterData hero, double size, {required bool unlocked}) {
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
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          SizedBox(
            width: 55,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.surfaceLight,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 25,
            child: Text(
              '$value',
              style: const TextStyle(
                color: AppColors.textPrimary,
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
