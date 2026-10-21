import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/app_theme.dart';
import '../../services/game_state_service.dart';
import '../../game/models/zone_data.dart';

class ZoneSelectionScreen extends StatefulWidget {
  const ZoneSelectionScreen({super.key});

  @override
  State<ZoneSelectionScreen> createState() => _ZoneSelectionScreenState();
}

class _ZoneSelectionScreenState extends State<ZoneSelectionScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    final gs = context.read<GameStateService>();
    final index = gs.zones.indexWhere((z) => z.id == gs.selectedZoneId);
    if (index >= 0) _selectedIndex = index;
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Zone Selection'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: Consumer<GameStateService>(
        builder: (context, gs, _) {
          final zones = gs.zones;
          if (zones.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final selectedZone = zones[_selectedIndex.clamp(0, zones.length - 1)];
          final isUnlocked = gs.isZoneUnlocked(selectedZone);

          final zoneVillains = gs.getVillainsForZone(selectedZone.id);
          int discoveredCount = 0;
          int defeatedCount = 0;
          for (final v in zoneVillains) {
            final state = gs.progress.villainStates[v.id];
            if (state != null && state.isDiscovered) discoveredCount++;
            if (state != null && state.isDefeated) defeatedCount++;
          }
          final completionPercent = zoneVillains.isEmpty
              ? 0
              : ((defeatedCount / zoneVillains.length) * 100).toInt();

          return SafeArea(
            child: isLandscape
                ? Row(
                    children: [
                      // Zone list on left
                      Expanded(
                        flex: 2,
                        child: _buildZoneListView(zones, gs),
                      ),
                      // Details on right
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
                      // Horizontal Zone Selector Tabs at top
                      SizedBox(
                        height: 90,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          scrollDirection: Axis.horizontal,
                          itemCount: zones.length,
                          itemBuilder: (context, index) {
                            final zone = zones[index];
                            final isSelected = index == _selectedIndex;
                            final unlocked = gs.isZoneUnlocked(zone);

                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedIndex = index),
                              child: Container(
                                width: 140,
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.25)
                                      : AppColors.surface,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : Colors.white12,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: zone.backgroundColor,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        unlocked
                                            ? Icons.landscape
                                            : Icons.lock,
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
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
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
                          },
                        ),
                      ),

                      // Full Details Card
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
                    ],
                  ),
          );
        },
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
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.25)
                      : AppColors.surface,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.white10,
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
                        unlocked ? Icons.landscape : Icons.lock,
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
                      const Icon(Icons.lock, color: Colors.orange, size: 18),
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  selectedZone.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? AppColors.success.withValues(alpha: 0.2)
                      : AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isUnlocked ? 'UNLOCKED' : 'LOCKED',
                  style: TextStyle(
                    color: isUnlocked ? AppColors.success : AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            selectedZone.description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          // Stats Grid
          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  'Villains Located',
                  '$discoveredCount / $totalVillains',
                  Icons.person_search,
                ),
              ),
              Expanded(
                child: _buildMetric(
                  'Defeated',
                  '$defeatedCount / $totalVillains',
                  Icons.sports_mma,
                ),
              ),
              Expanded(
                child: _buildMetric(
                  'Completion',
                  '$completionPercent%',
                  Icons.pie_chart,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: completionPercent / 100.0,
              backgroundColor: AppColors.surfaceLight,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 24),

          // Launch or Locked Requirement
          if (isUnlocked)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  gs.setSelectedZone(selectedZone.id);
                  context.push('/characters');
                },
                icon: const Icon(Icons.play_arrow),
                label: Text('Choose Heroes for ${selectedZone.name}'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
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

  Widget _buildMetric(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.secondary),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
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
