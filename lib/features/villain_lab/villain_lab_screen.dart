import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/app_theme.dart';
import '../../game/models/custom_villain.dart';
import '../../game/models/game_enums.dart';
import '../../services/custom_villain_service.dart';
import '../../services/face_villain/villain_generator.dart';
import '../../services/game_state_service.dart';
import 'villain_forge_screen.dart';
import 'widgets/villain_avatar.dart';

/// Roster of villains generated from real faces.
class VillainLabScreen extends StatelessWidget {
  const VillainLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<CustomVillainService>();
    final gs = context.watch<GameStateService>();
    final villains = service.villains;
    final full = villains.length >= CustomVillainService.maxVillains;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Villain Lab')),
      floatingActionButton: villains.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: full ? null : () => showVillainSourcePicker(context),
              backgroundColor: full ? Colors.grey : AppColors.primary,
              icon: const Icon(Icons.add_a_photo),
              label: Text(full ? 'Lab full' : 'New Villain'),
            ),
      body: SafeArea(
        child: villains.isEmpty
            ? _EmptyLab(onCreate: () => showVillainSourcePicker(context))
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: villains.length,
                itemBuilder: (context, i) {
                  final v = villains[i];
                  final defeated = gs.progress.isVillainDefeated(v.id);
                  return _VillainCard(
                    villain: v,
                    zoneName: gs.getZone(v.zoneId)?.name ?? v.zoneId,
                    defeated: defeated,
                    onTap: () => _showDetails(context, v),
                  );
                },
              ),
      ),
    );
  }

  void _showDetails(BuildContext context, CustomVillain villain) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _VillainDetails(villain: villain),
    );
  }
}

class _EmptyLab extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyLab({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.face_retouching_natural,
                  size: 64, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'Turn any face into a villain',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            const Text(
              'Snap a selfie or pick a photo of a friend. PixelPunch finds the face, '
              'reads its features, draws a cartoon version and gives it a fighting '
              'style, stats and trash talk. Then it shows up in your zones to fight.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Create My First Villain'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Photos are processed on your device and never uploaded.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _VillainCard extends StatelessWidget {
  final CustomVillain villain;
  final String zoneName;
  final bool defeated;
  final VoidCallback onTap;

  const _VillainCard({
    required this.villain,
    required this.zoneName,
    required this.defeated,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = villain.traits.accentColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [accent.withValues(alpha: 0.35), AppColors.surface],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VillainAvatar.of(villain, size: 150, animate: false),
                      if (defeated)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('BEATEN',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  villain.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  '${VillainGenerator.archetypeLabels[villain.archetype]} · $zoneName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VillainDetails extends StatelessWidget {
  final CustomVillain villain;
  const _VillainDetails({required this.villain});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameStateService>();
    final zone = gs.getZone(villain.zoneId);
    final zoneUnlocked = zone != null && gs.isZoneUnlocked(zone);

    void fight(GameMode mode) {
      gs.setSelectedMode(mode);
      final heroes = gs.selectedHeroIds.isNotEmpty
          ? gs.selectedHeroIds
          : [gs.unlockedHeroes.first.id];
      // Fill the team with unlocked heroes if the mode needs more.
      final team = [...heroes];
      for (final h in gs.unlockedHeroes) {
        if (team.length >= mode.friendlyCount) break;
        if (!team.contains(h.id)) team.add(h.id);
      }
      Navigator.pop(context);
      context.push('/game', extra: {
        'zoneId': zoneUnlocked ? villain.zoneId : 'zone_office',
        'mode': mode.name,
        'heroIds': team.take(mode.friendlyCount).toList(),
        'villainIds': [villain.id],
      });
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: VillainAvatar.of(villain, size: 200)),
          Text(
            villain.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          Text(
            villain.title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 10),
          Text(
            villain.biography,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _tag(VillainGenerator.archetypeLabels[villain.archetype] ?? villain.archetype),
              _tag('HP ${villain.baseHealth}'),
              _tag('ATK ${villain.attackDamage}'),
              _tag('DEF ${villain.defense}'),
              _tag('SPD ${villain.moveSpeed.round()}'),
              _tag(zone?.name ?? villain.zoneId),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '"${villain.dialogue['discovery']?.first ?? '...'}"',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 20),
          const Text('FIGHT', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final mode in GameMode.values) ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => fight(mode),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(mode.shortName),
                  ),
                ),
                if (mode != GameMode.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/villain-lab/create', extra: {'editId': villain.id});
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (d) => AlertDialog(
                        title: Text('Delete ${villain.name}?'),
                        content: const Text('This villain and its cartoon face will be removed.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (ok == true && context.mounted) {
                      await context.read<CustomVillainService>().delete(villain.id);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      );
}
