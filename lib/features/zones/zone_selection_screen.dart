import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/animated_background.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/pixel_button.dart';
import '../../services/game_state_service.dart';
import '../../game/models/zone_data.dart';

class ZoneSelectionScreen extends StatefulWidget {
  const ZoneSelectionScreen({super.key});

  @override
  State<ZoneSelectionScreen> createState() => _ZoneSelectionScreenState();
}

class _ZoneSelectionScreenState extends State<ZoneSelectionScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _entranceController;
  late Animation<double> _headerFade;
  late Animation<double> _listFade;
  late Animation<double> _detailsFade;

  @override
  void initState() {
    super.initState();
    final gs = context.read<GameStateService>();
    final index = gs.zones.indexWhere((z) => z.id == gs.selectedZoneId);
    if (index >= 0) _selectedIndex = index;

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0, 0.4, curve: Curves.easeOut),
      ),
    );
    _listFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
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
    super.dispose();
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
                  final zones = gs.zones;
                  if (zones.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final selectedZone =
                      zones[_selectedIndex.clamp(0, zones.length - 1)];
                  final isUnlocked = gs.isZoneUnlocked(selectedZone);

                  final zoneVillains =
                      gs.getVillainsForZone(selectedZone.id);
                  int discoveredCount = 0;
                  int defeatedCount = 0;
                  for (final v in zoneVillains) {
                    final state = gs.progress.villainStates[v.id];
                    if (state != null && state.isDiscovered) {
                      discoveredCount++;
                    }
                    if (state != null && state.isDefeated) {
                      defeatedCount++;
                    }
                  }
                  final completionPercent = zoneVillains.isEmpty
                      ? 0
                      : ((defeatedCount / zoneVillains.length) * 100)
                          .toInt();

                  return isLandscape
                      ? Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildZoneListView(zones, gs),
                            ),
                            Expanded(
                              flex: 3,
                              child: _buildZoneDetailsCard(
                                selectedZone,
                                isUnlocked,
                                zoneVillains.length,
                                discoveredCount,
                                defeatedCount,
                                completionPercent,
                                gs,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            // Header
                            FadeTransition(
                              opacity: _headerFade,
                              child: _buildHeader(),
                            ),

                            // Horizontal zone tabs
                            FadeTransition(
                              opacity: _listFade,
                              child: SizedBox(
                                height: 90,
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  scrollDirection: Axis.horizontal,
                                  itemCount: zones.length,
                                  itemBuilder: (context, index) {
                                    return _buildZoneTab(
                                        zones[index], index, gs);
                                  },
                                ),
                              ),
                            ),

                            // Details
                            Expanded(
                              child: FadeTransition(
                                opacity: _detailsFade,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 4, 16, 16),
                                  child: _buildZoneDetailsCard(
                                    selectedZone,
                                    isUnlocked,
                                    zoneVillains.length,
                                    discoveredCount,
                                    defeatedCount,
                                    completionPercent,
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

  Widget _buildHeader() {
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
          const Expanded(
            child: Text(
              'SELECT ZONE',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.map_rounded,
                    color: AppColors.secondary, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${context.read<GameStateService>().zones.length} Zones',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneTab(ZoneData zone, int index, GameStateService gs) {
    final isSelected = index == _selectedIndex;
    final unlocked = gs.isZoneUnlocked(zone);

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    zone.backgroundColor.withValues(alpha: 0.35),
                    zone.backgroundColor.withValues(alpha: 0.1),
                  ],
                )
              : null,
          color: isSelected ? null : AppColors.surface,
          border: Border.all(
            color: isSelected
                ? zone.backgroundColor.withValues(alpha: 0.7)
                : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: zone.backgroundColor.withValues(alpha: 0.2),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: zone.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: zone.backgroundColor.withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Icon(
                unlocked ? Icons.landscape_rounded : Icons.lock_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                zone.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneListView(List<ZoneData> zones, GameStateService gs) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: zones.length,
      itemBuilder: (context, index) {
        final zone = zones[index];
        final isSelected = index == _selectedIndex;
        final unlocked = gs.isZoneUnlocked(zone);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _selectedIndex = index),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            zone.backgroundColor.withValues(alpha: 0.3),
                            zone.backgroundColor.withValues(alpha: 0.08),
                          ],
                        )
                      : null,
                  color: isSelected ? null : AppColors.surface,
                  border: Border.all(
                    color: isSelected
                        ? zone.backgroundColor.withValues(alpha: 0.6)
                        : Colors.white10,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: zone.backgroundColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        unlocked
                            ? Icons.landscape_rounded
                            : Icons.lock_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            zone.name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 15,
                              color: isSelected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Difficulty: ${zone.recommendedDifficulty}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!unlocked)
                      const Icon(Icons.lock_rounded,
                          color: Colors.orange, size: 18),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildZoneDetailsCard(
    ZoneData selectedZone,
    bool isUnlocked,
    int totalVillains,
    int discoveredCount,
    int defeatedCount,
    int completionPercent,
    GameStateService gs,
  ) {
    return GlowCard(
      glowColor: selectedZone.backgroundColor,
      animate: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedZone.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: selectedZone.backgroundColor,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      'Difficulty: ${selectedZone.recommendedDifficulty}',
                      style: TextStyle(
                        color:
                            AppColors.textSecondary.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isUnlocked
                        ? [
                            AppColors.success.withValues(alpha: 0.2),
                            AppColors.success.withValues(alpha: 0.05),
                          ]
                        : [
                            Colors.orange.withValues(alpha: 0.2),
                            Colors.orange.withValues(alpha: 0.05),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isUnlocked
                        ? AppColors.success.withValues(alpha: 0.5)
                        : Colors.orange.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUnlocked
                          ? Icons.lock_open_rounded
                          : Icons.lock_rounded,
                      size: 14,
                      color: isUnlocked ? AppColors.success : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isUnlocked ? 'UNLOCKED' : 'LOCKED',
                      style: TextStyle(
                        color:
                            isUnlocked ? AppColors.success : Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            selectedZone.description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),

          // Stats Grid
          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  'Located',
                  '$discoveredCount/$totalVillains',
                  Icons.person_search_rounded,
                  AppColors.info,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetric(
                  'Defeated',
                  '$defeatedCount/$totalVillains',
                  Icons.sports_mma_rounded,
                  Colors.redAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetric(
                  'Complete',
                  '$completionPercent%',
                  Icons.pie_chart_rounded,
                  AppColors.accent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: completionPercent / 100.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, val, __) => LinearProgressIndicator(
                value: val,
                backgroundColor: AppColors.surfaceLight,
                valueColor: AlwaysStoppedAnimation(
                  Color.lerp(
                    selectedZone.backgroundColor,
                    AppColors.accent,
                    val,
                  )!,
                ),
                minHeight: 8,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Launch or Locked
          if (isUnlocked)
            PixelButton(
              label:
                  'CHOOSE HEROES FOR ${selectedZone.name.toUpperCase()}',
              icon: Icons.play_arrow_rounded,
              color: selectedZone.backgroundColor,
              isLarge: true,
              showGlow: true,
              width: double.infinity,
              onTap: () {
                gs.setSelectedZone(selectedZone.id);
                context.push('/characters');
              },
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withValues(alpha: 0.1),
                    Colors.orange.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedZone.unlockRequirement ??
                          'Defeat previous zone villains to unlock',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetric(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
