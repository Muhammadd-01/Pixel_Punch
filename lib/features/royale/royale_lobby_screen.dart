import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/app_theme.dart';
import '../../services/custom_villain_service.dart';
import '../../services/game_state_service.dart';
import '../../services/supabase_service.dart';
import '../villain_lab/widgets/villain_avatar.dart';
import 'royale_config.dart';
import 'royale_launcher.dart';

/// Set-up screen for the 3D battle royale: who to fight (your Villain Lab
/// faces + the built-in villains), map size, camera view and how to play
/// (solo vs villains, host a squad, or join a friend's squad by code).
class RoyaleLobbyScreen extends StatefulWidget {
  const RoyaleLobbyScreen({super.key});

  @override
  State<RoyaleLobbyScreen> createState() => _RoyaleLobbyScreenState();
}

class _RoyaleLobbyScreenState extends State<RoyaleLobbyScreen> {
  RoyaleRole _role = RoyaleRole.offline;
  final _joinCode = TextEditingController();
  final Set<String> _picked = {};
  double _villainCount = 12;
  double _mapSize = 1600;
  bool _firstPerson = false;
  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    // Default: every face-made villain plus all built-in villains.
    final custom = context.read<CustomVillainService>().villains;
    final builtIn = context.read<GameStateService>().villains;
    _picked
      ..addAll(custom.map((v) => v.id))
      ..addAll(builtIn.map((v) => v.id));
  }

  @override
  void dispose() {
    _joinCode.dispose();
    super.dispose();
  }

  Future<void> _launch() async {
    final gs = context.read<GameStateService>();
    final customs = context.read<CustomVillainService>().villains;
    final supabase = context.read<SupabaseService>();

    if (_role == RoyaleRole.join && _joinCode.text.trim().length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter your friend's squad code first.")),
      );
      return;
    }
    final villains = <Map<String, dynamic>>[
      for (final v in customs)
        if (_picked.contains(v.id)) RoyaleConfigBuilder.customVillain(v),
      for (final v in gs.villains)
        if (_picked.contains(v.id))
          RoyaleConfigBuilder.builtInVillain(v, gs.getDialogueProfile(v.dialogueProfileId ?? v.id)),
    ];
    if (villains.isEmpty && _role != RoyaleRole.join) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one villain to hunt.')),
      );
      return;
    }

    final hero = gs.selectedHeroIds.isNotEmpty ? gs.getHero(gs.selectedHeroIds.first) : null;
    final name = supabase.currentUser?.userMetadata?['display_name'] as String? ?? 'Player';
    final config = RoyaleConfigBuilder.build(
      role: _role,
      joinCode: _joinCode.text,
      playerName: name,
      heroId: hero?.id ?? 'hero_striker',
      heroColor: hero?.color ?? AppColors.primary,
      villains: villains,
      villainCount: _villainCount.round(),
      mapSize: _mapSize,
      firstPerson: _firstPerson,
    );
    await RoyaleLauncher.launch(context, config);
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameStateService>();
    final customs = context.watch<CustomVillainService>().villains;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('PixelPunch Royale 3D'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _hero(),
            const SizedBox(height: 16),
            _section('How do you want to play?'),
            SegmentedButton<RoyaleRole>(
              segments: const [
                ButtonSegment(value: RoyaleRole.offline, icon: Icon(Icons.person), label: Text('Solo')),
                ButtonSegment(value: RoyaleRole.host, icon: Icon(Icons.group_add), label: Text('Host squad')),
                ButtonSegment(value: RoyaleRole.join, icon: Icon(Icons.login), label: Text('Join squad')),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              switch (_role) {
                RoyaleRole.offline => 'You against the villains. Works offline.',
                RoyaleRole.host => 'You get a squad code in-game. Share it with up to 3 friends so they can join you.',
                RoyaleRole.join => "Enter the code your friend sees in their game. You'll fight the host's villains.",
              },
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            if (_role == RoyaleRole.join) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _joinCode,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Squad code',
                  prefixIcon: Icon(Icons.vpn_key),
                ),
              ),
            ],
            if (_role != RoyaleRole.join) ...[
              const SizedBox(height: 20),
              _section('Villains on the island (${_picked.length} picked)'),
              if (customs.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextButton.icon(
                    onPressed: () => context.push('/villain-lab'),
                    icon: const Icon(Icons.face_retouching_natural),
                    label: const Text('Make villains from real faces in the Villain Lab'),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in customs)
                    FilterChip(
                      avatar: SizedBox(width: 22, height: 28, child: VillainAvatar.of(v, size: 28, animate: false)),
                      label: Text(v.name),
                      selected: _picked.contains(v.id),
                      onSelected: (on) => setState(() => on ? _picked.add(v.id) : _picked.remove(v.id)),
                    ),
                  for (final v in gs.villains)
                    FilterChip(
                      avatar: CircleAvatar(backgroundColor: v.color, radius: 8),
                      label: Text(v.name),
                      selected: _picked.contains(v.id),
                      onSelected: (on) => setState(() => on ? _picked.add(v.id) : _picked.remove(v.id)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _section('Villain squad size: ${_villainCount.round()}'),
              Slider(
                value: _villainCount,
                min: 4,
                max: 30,
                divisions: 26,
                label: '${_villainCount.round()}',
                onChanged: (v) => setState(() => _villainCount = v),
              ),
              _section('Map size'),
              SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 1100, label: Text('Quick 1 km')),
                  ButtonSegment(value: 1600, label: Text('Large 1.6 km')),
                  ButtonSegment(value: 2400, label: Text('Huge 2.4 km')),
                ],
                selected: {_mapSize},
                onSelectionChanged: (s) => setState(() => _mapSize = s.first),
              ),
            ],
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start in first-person (FPP)'),
              subtitle: const Text('Switch any time in-game with the TPP/FPP button or V key.'),
              value: _firstPerson,
              onChanged: (v) => setState(() => _firstPerson = v),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _launch,
                icon: const Icon(Icons.flight_takeoff),
                label: Text(switch (_role) {
                  RoyaleRole.offline => 'DROP IN',
                  RoyaleRole.host => 'HOST & DROP IN',
                  RoyaleRole.join => 'JOIN SQUAD',
                }),
              ),
            ),
            if (_role == RoyaleRole.host)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  "Villain face photos are sent to the friends who join your squad. Only use faces of people who are okay with that.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(colors: [Color(0xFF3A1C71), Color(0xFFD76D77), Color(0xFFFFAF7B)]),
        ),
        child: const Row(
          children: [
            Icon(Icons.public, size: 44, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Skydive onto a huge 3D island, loot weapons, punch and shoot your way through the villains, '
                'and stay inside the shrinking safe zone. Last squad standing wins!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, height: 1.35),
              ),
            ),
          ],
        ),
      );

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
      );
}
