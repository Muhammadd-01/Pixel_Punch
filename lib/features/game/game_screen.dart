import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/music_scope.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../game/pixel_punch_game.dart';
import '../../game/models/custom_villain.dart';
import '../../game/models/dialogue_data.dart';
import '../../game/models/fighter_data.dart';
import '../../game/models/game_enums.dart';
import '../../game/models/match_result.dart';
import '../../services/custom_villain_service.dart';
import '../../services/audio_service.dart';
import '../../services/game_state_service.dart';
import '../../services/local_storage_service.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';
import 'widgets/game_hud.dart';
import 'widgets/dialogue_overlay.dart';
import 'widgets/game_over_overlay.dart';
import 'widgets/pause_overlay.dart';

class GameScreen extends StatefulWidget {
  final String zoneId;
  final String mode;
  final List<String> heroIds;
  final List<String> villainIds;

  const GameScreen({
    super.key,
    required this.zoneId,
    required this.mode,
    required this.heroIds,
    this.villainIds = const [],
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  PixelPunchGame? _game;
  int _session = 0;
  String? _error;
  bool _showDialogue = false;
  bool _showGameOver = false;
  bool _showPause = false;
  String _dialogueVillainName = '';
  String _dialogueVillainTitle = '';
  String _dialogueText = '';
  Color _dialogueColor = Colors.white;
  MatchOutcome? _matchOutcome;
  MatchRewards? _rewards;
  int _damageDealt = 0;
  int _damageTaken = 0;
  int _matchDuration = 0;
  int _villainsDefeated = 0;
  int _villainsTotal = 0;
  final Map<String, Uint8List> _faces = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initGame();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto-pause when the app goes to the background.
    if (state != AppLifecycleState.resumed &&
        _game != null &&
        !_showPause &&
        !_showGameOver) {
      _togglePause();
    }
  }

  void _quitToMenu() {
    context.go('/home');
  }

  Future<void> _initGame() async {
    final gs = context.read<GameStateService>();
    final customService = context.read<CustomVillainService>();
    final storage = context.read<LocalStorageService>();
    final settings = await storage.loadSettings();
    if (!mounted) return;

    final zoneData = gs.getZone(widget.zoneId) ?? (gs.zones.isNotEmpty ? gs.zones.first : null);
    if (zoneData == null) {
      setState(() => _error = 'Game data is still loading. Please go back and try again.');
      return;
    }

    final gameMode = GameMode.values.firstWhere(
      (m) => m.name == widget.mode,
      orElse: () => GameMode.solo,
    );

    final heroDataList = widget.heroIds
        .map(gs.getHero)
        .whereType<FighterData>()
        .toList();
    if (heroDataList.isEmpty && gs.heroes.isNotEmpty) {
      heroDataList.add(gs.heroes.first);
    }

    // Face-generated villains for this zone plus any explicitly requested.
    final customs = <CustomVillain>{
      ...customService.forZone(zoneData.id),
      ...widget.villainIds.map(customService.byId).whereType<CustomVillain>(),
    }.toList();

    final villainDataList = gs.villainsForMatch(
      zoneData.id,
      gameMode,
      customVillains: customs.map((c) => c.toFighterData()).toList(),
      featuredIds: widget.villainIds,
    );

    final profiles = Map<String, DialogueProfile>.from(gs.dialogueProfiles);
    final traits = <String, FaceTraits>{};
    _faces.clear();
    for (final c in customs) {
      profiles[c.id] = c.toDialogueProfile();
      traits[c.id] = c.traits;
      _faces[c.id] = c.portraitPng;
    }

    final game = PixelPunchGame(
      zoneData: zoneData,
      heroDataList: heroDataList,
      villainDataList: villainDataList,
      abilities: {for (final a in gs.abilities) a.id: a},
      dialogueProfiles: profiles,
      mode: gameMode,
      villainFaces: Map.of(_faces),
      villainTraits: traits,
      hapticsEnabled: settings['vibration'] as bool? ?? true,
      reducedMotion: settings['reduced_motion'] as bool? ?? false,
      audioService: context.read<AudioService>(),
    );

    game.onDialogue = (villainId, name, title, text, color) {
      if (!mounted) return;
      setState(() {
        _showDialogue = true;
        _dialogueVillainName = name;
        _dialogueVillainTitle = title;
        _dialogueText = text;
        _dialogueColor = color;
      });
    };

    game.onPauseRequested = () {
      if (mounted && !_showGameOver && !_showDialogue) _togglePause();
    };

    game.onVillainDiscovered = (villainId, name, title) {
      gs.updateVillainDiscovery(villainId, DiscoveryState.located);
    };

    game.onGameOver = (outcome, damageDealt, damageTaken, duration) {
      if (!mounted) return;
      final defeated = game.defeatedVillains.toSet();
      final defeatedCount =
          game.villainComponents.where((v) => v.isKnockedOut).length;
      final matchResult = MatchResult(
        matchId: const Uuid().v4(),
        mode: gameMode,
        zoneId: zoneData.id,
        playerCharacterIds: heroDataList.map((h) => h.id).toList(),
        enemyIds: villainDataList.map((v) => v.id).toList(),
        outcome: outcome,
        durationSeconds: duration,
        damageDealt: damageDealt,
        damageTaken: damageTaken,
        xpEarned: GameStateService.xpFor(outcome, defeatedCount),
        completedAt: DateTime.now(),
      );
      final rewards = gs.applyMatchResult(
        matchResult,
        discoveredIds: game.discoveredVillains,
        defeatedIds: defeated,
      );
      _syncMatch(matchResult);

      setState(() {
        _showGameOver = true;
        _showPause = false;
        _matchOutcome = outcome;
        _damageDealt = damageDealt;
        _damageTaken = damageTaken;
        _matchDuration = duration;
        _rewards = rewards;
        _villainsDefeated = defeatedCount;
        _villainsTotal = game.villainComponents.length;
      });
      MusicScope.switchTo(
          context,
          outcome == MatchOutcome.victory
              ? MusicTrack.victoryTheme
              : MusicTrack.exploration);
    };

    setState(() {
      _game = game;
      _session++;
      _error = null;
    });
  }

  void _syncMatch(MatchResult result) {
    try {
      final supabase = context.read<SupabaseService>();
      final sync = context.read<SyncService>();
      sync.queueMatch(result);
      if (supabase.isAuthenticated) {
        sync.syncData(context.read<GameStateService>().progress);
      }
    } catch (e) {
      debugPrint('Match sync skipped: $e');
    }
  }

  void _dismissDialogue() {
    setState(() => _showDialogue = false);
    _game?.dismissDialogue();
  }

  void _togglePause() {
    setState(() {
      _showPause = !_showPause;
      if (_showPause) {
        _game?.pauseGame();
        _game?.joystickDirection.setZero();
      } else {
        _game?.resumeGame();
      }
    });
  }

  void _retry() {
    setState(() {
      _showGameOver = false;
      _showDialogue = false;
      _showPause = false;
      _rewards = null;
      _game = null;
    });
    _initGame();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    if (game == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0B16),
        body: Center(
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _quitToMenu, child: const Text('Back to Menu')),
                    ],
                  ),
                )
              : const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Loading zone...'),
                  ],
                ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_showGameOver) {
          _quitToMenu();
        } else if (!_showDialogue) {
          _togglePause();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0B16),
        body: Stack(
          children: [
            GameWidget(key: ValueKey(_session), game: game),

            if (!_showGameOver)
              GameHud(
                key: ValueKey('hud$_session'),
                game: game,
                onPause: _togglePause,
                onAttack: () => game.attackPressed = true,
                onSpecial: () => game.specialPressed = true,
                onDodge: () => game.dodgePressed = true,
                onJoystickUpdate: (direction) {
                  game.joystickDirection = direction;
                },
              ),

            if (_showDialogue)
              DialogueOverlay(
                key: ValueKey(_dialogueText),
                villainName: _dialogueVillainName,
                villainTitle: _dialogueVillainTitle,
                text: _dialogueText,
                villainColor: _dialogueColor,
                audioService: context.read<AudioService>(),
                onDismiss: _dismissDialogue,
              ),

            if (_showPause)
              PauseOverlay(
                onResume: _togglePause,
                onRestart: _retry,
                onQuit: _quitToMenu,
              ),

            if (_showGameOver)
              GameOverOverlay(
                outcome: _matchOutcome ?? MatchOutcome.defeat,
                damageDealt: _damageDealt,
                damageTaken: _damageTaken,
                duration: _matchDuration,
                villainsDefeated: _villainsDefeated,
                villainsTotal: _villainsTotal,
                rewards: _rewards,
                onRetry: _retry,
                onQuit: _quitToMenu,
              ),
          ],
        ),
      ),
    );
  }
}
