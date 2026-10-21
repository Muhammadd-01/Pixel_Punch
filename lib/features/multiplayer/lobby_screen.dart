import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/animated_background.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/pixel_button.dart';
import '../../services/lobby_service.dart';
import '../../services/game_state_service.dart';
import '../../services/supabase_service.dart';
import '../../game/models/game_enums.dart';

class LobbyScreen extends StatefulWidget {
  final String? inviteCode;
  const LobbyScreen({super.key, this.inviteCode});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.inviteCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _joinWithCode(widget.inviteCode!);
      });
    }
  }

  Future<void> _joinWithCode(String code) async {
    final lobby = context.read<LobbyService>();
    final gs = context.read<GameStateService>();
    final heroId = gs.selectedHeroIds.isNotEmpty
        ? gs.selectedHeroIds.first
        : 'hero_striker';
    final error = await lobby.joinLobby(inviteCode: code, heroId: heroId);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await context.read<LobbyService>().leaveLobby();
        if (context.mounted) context.pop();
      },
      child: Scaffold(
        body: AnimatedBackground(
          particleCount: 20,
          showGrid: true,
          child: SafeArea(
            child: Consumer<LobbyService>(
              builder: (_, lobby, __) {
                final info = lobby.currentLobby;
                if (lobby.isLoading) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text('Connecting...',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }
                if (info == null) {
                  return _buildNoLobby();
                }
                return _buildLobbyView(info);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoLobby() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups_rounded,
                size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              'MULTIPLAYER',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 32),
            PixelButton(
              label: 'CREATE LOBBY',
              icon: Icons.add_circle_rounded,
              color: AppColors.primary,
              isLarge: true,
              showGlow: true,
              width: double.infinity,
              onTap: () => _createLobby(context),
            ),
            const SizedBox(height: 16),
            PixelButton(
              label: 'JOIN WITH CODE',
              icon: Icons.qr_code_rounded,
              color: AppColors.secondary,
              isOutlined: true,
              width: double.infinity,
              onTap: () => _showJoinDialog(context),
            ),
            const SizedBox(height: 16),
            PixelButton(
              label: 'BACK',
              icon: Icons.arrow_back_rounded,
              color: AppColors.textSecondary,
              isOutlined: true,
              onTap: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLobbyView(LobbyInfo info) {
    final userId = context.read<SupabaseService>().currentUser?.id;
    final amHost = info.hostId == userId;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              IconButton(
                onPressed: () async {
                  final lobbyService = context.read<LobbyService>();
                  final nav = GoRouter.of(context);
                  await lobbyService.leaveLobby();
                  if (mounted) nav.pop();
                },
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.textPrimary),
              ),
              const Expanded(
                child: Text(
                  'LOBBY',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),

          // Invite code banner
          if (info.inviteCode != null)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: info.inviteCode!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invite code copied!'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: GlowCard(
                glowColor: AppColors.accent,
                animate: true,
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.share_rounded,
                        color: AppColors.accent, size: 20),
                    const SizedBox(width: 10),
                    Column(
                      children: [
                        Text(
                          'INVITE CODE',
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.7),
                            fontSize: 10,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          info.inviteCode!,
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.copy_rounded,
                        color: AppColors.accent, size: 18),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),

          // Mode + Zone info
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _infoPill('Mode', info.mode.displayName, AppColors.primary),
              const SizedBox(width: 12),
              _infoPill('Players', '${info.players.length}/${info.maxPlayers}',
                  AppColors.secondary),
            ],
          ),
          const SizedBox(height: 20),

          // Player slots
          const Text(
            'TEAM',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              children: [
                for (final player in info.players)
                  _playerSlot(player),
                for (int i = info.players.length; i < info.maxPlayers; i++)
                  _emptySlot(i),
              ],
            ),
          ),

          // Action buttons
          const SizedBox(height: 16),
          if (amHost)
            PixelButton(
              label: 'START GAME',
              icon: Icons.play_arrow_rounded,
              color: AppColors.primary,
              isLarge: true,
              showGlow: true,
              width: double.infinity,
              enabled: info.allReady && info.players.length >= 2,
              onTap: () async {
                final lobbyService = context.read<LobbyService>();
                final messenger = ScaffoldMessenger.of(context);
                final error = await lobbyService.startGame();
                if (error != null && mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                        content: Text(error),
                        backgroundColor: AppColors.error),
                  );
                }
              },
            )
          else
            PixelButton(
              label: info.players
                      .any((p) => p.userId == userId && p.isReady)
                  ? 'NOT READY'
                  : 'READY UP!',
              icon: Icons.check_circle_rounded,
              color: info.players
                      .any((p) => p.userId == userId && p.isReady)
                  ? AppColors.textSecondary
                  : AppColors.success,
              isLarge: true,
              showGlow: true,
              width: double.infinity,
              onTap: () => context.read<LobbyService>().toggleReady(),
            ),
        ],
      ),
    );
  }

  Widget _playerSlot(LobbyPlayer player) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: player.isReady
              ? AppColors.success.withValues(alpha: 0.5)
              : Colors.white12,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Slot number
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.2),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(
                '${player.slot + 1}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Name + hero
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      player.displayName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (player.isHost) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'HOST',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Hero: ${player.heroId}',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Ready indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: player.isReady
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.textSecondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: player.isReady
                    ? AppColors.success.withValues(alpha: 0.5)
                    : Colors.white12,
              ),
            ),
            child: Text(
              player.isReady ? 'READY' : 'WAITING',
              style: TextStyle(
                color: player.isReady
                    ? AppColors.success
                    : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptySlot(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: Colors.white12),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Waiting for player...',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.4),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _createLobby(BuildContext context) async {
    final gs = context.read<GameStateService>();
    final lobby = context.read<LobbyService>();
    final messenger = ScaffoldMessenger.of(context);
    final heroId = gs.selectedHeroIds.isNotEmpty
        ? gs.selectedHeroIds.first
        : 'hero_striker';
    final error = await lobby.createLobby(
      mode: gs.selectedMode == GameMode.solo ? GameMode.duo : gs.selectedMode,
      zoneId: gs.selectedZoneId,
      heroId: heroId,
    );
    if (error != null && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  void _showJoinDialog(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bc) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(bc).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'JOIN LOBBY',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: 'XXXXXX',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                      letterSpacing: 6,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                PixelButton(
                  label: 'JOIN',
                  icon: Icons.login_rounded,
                  color: AppColors.secondary,
                  isLarge: true,
                  width: double.infinity,
                  onTap: () {
                    Navigator.pop(bc);
                    _joinWithCode(controller.text);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
