import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../game/pixel_punch_game.dart';
import '../../game/models/game_enums.dart';
import '../../game/models/match_result.dart';
import '../../services/game_state_service.dart';
import 'widgets/game_hud.dart';
import 'widgets/dialogue_overlay.dart';
import 'widgets/game_over_overlay.dart';
import 'widgets/pause_overlay.dart';

class GameScreen extends StatefulWidget {
  final String zoneId;
  final String mode;
  final List<String> heroIds;

  const GameScreen({
    super.key,
    required this.zoneId,
    required this.mode,
    required this.heroIds,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  PixelPunchGame? _game;
  bool _showDialogue = false;
  bool _showGameOver = false;
  bool _showPause = false;
  String _dialogueVillainName = '';
  String _dialogueVillainTitle = '';
  String _dialogueText = '';
  Color _dialogueColor = Colors.white;
  MatchOutcome? _matchOutcome;
  int _damageDealt = 0;
  int _damageTaken = 0;
  int _matchDuration = 0;

  @override
  void initState() {
    super.initState();
    // Switch to landscape orientation when game begins
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _initGame();
  }

  @override
  void dispose() {
    // Restore portrait orientation when exiting game
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _quitToMenu() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    context.go('/home');
  }

  void _initGame() {
    final gs = context.read<GameStateService>();
    final zoneData = gs.getZone(widget.zoneId);
    if (zoneData == null) return;

    final gameMode = GameMode.values.firstWhere(
      (m) => m.name == widget.mode,
      orElse: () => GameMode.solo,
    );

    // Get hero data
    final heroDataList = widget.heroIds
        .map((id) => gs.getHero(id))
        .where((h) => h != null)
        .map((h) => h!)
        .toList();

    if (heroDataList.isEmpty && gs.heroes.isNotEmpty) {
      heroDataList.add(gs.heroes.first);
    }

    // Get villain data for this zone
    final villainDataList = gs.getVillainsForZone(widget.zoneId);

    _game = PixelPunchGame(
      zoneData: zoneData,
      heroDataList: heroDataList,
      villainDataList: villainDataList,
      abilities: Map.fromEntries(
        gs.abilities.map((a) => MapEntry(a.id, a)),
      ),
      dialogueProfiles: gs.dialogueProfiles,
      mode: gameMode,
    );

    // Set up callbacks
    _game!.onDialogue = (villainId, name, title, text, color) {
      if (!mounted) return;
      setState(() {
        _showDialogue = true;
        _dialogueVillainName = name;
        _dialogueVillainTitle = title;
        _dialogueText = text;
        _dialogueColor = color;
      });
    };

    _game!.onGameOver = (outcome, damageDealt, damageTaken, duration) {
      if (!mounted) return;
      setState(() {
        _showGameOver = true;
        _matchOutcome = outcome;
        _damageDealt = damageDealt;
        _damageTaken = damageTaken;
        _matchDuration = duration;
      });

      final matchResult = MatchResult(
        matchId: const Uuid().v4(),
        mode: gameMode,
        zoneId: widget.zoneId,
        playerCharacterIds: widget.heroIds,
        enemyIds: villainDataList.map((v) => v.id).toList(),
        outcome: outcome,
        durationSeconds: duration,
        damageDealt: damageDealt,
        damageTaken: damageTaken,
        xpEarned: outcome == MatchOutcome.victory ? 50 : 10,
        completedAt: DateTime.now(),
      );
      gs.recordMatchResult(matchResult);

      if (outcome == MatchOutcome.victory) {
        for (final villainId in _game!.defeatedVillains) {
          gs.updateVillainDiscovery(villainId, DiscoveryState.defeated);
        }
      }
    };

    _game!.onVillainDiscovered = (villainId, name, title) {
      gs.updateVillainDiscovery(villainId, DiscoveryState.located);
    };
  }

  void _dismissDialogue() {
    setState(() => _showDialogue = false);
    _game?.dismissDialogue();

    if (_game != null && _game!.isExplorationMode) {
      for (final villainId in _game!.discoveredVillains) {
        _game!.startCombatWithVillain(villainId);
      }
    }
  }

  void _togglePause() {
    setState(() {
      _showPause = !_showPause;
      if (_showPause) {
        _game?.pauseGame();
      } else {
        _game?.resumeGame();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_game == null) {
      return const Scaffold(
        body: Center(child: Text('Loading zone...')),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: _game!),

          if (!_showGameOver)
            GameHud(
              game: _game!,
              onPause: _togglePause,
              onAttack: () => _game!.attackPressed = true,
              onSpecial: () => _game!.specialPressed = true,
              onDodge: () => _game!.dodgePressed = true,
              onJoystickUpdate: (direction) {
                _game!.joystickDirection = direction;
              },
            ),

          if (_showDialogue)
            DialogueOverlay(
              villainName: _dialogueVillainName,
              villainTitle: _dialogueVillainTitle,
              text: _dialogueText,
              color: _dialogueColor,
              onDismiss: _dismissDialogue,
            ),

          if (_showPause)
            PauseOverlay(
              onResume: _togglePause,
              onQuit: _quitToMenu,
            ),

          if (_showGameOver)
            GameOverOverlay(
              outcome: _matchOutcome ?? MatchOutcome.defeat,
              damageDealt: _damageDealt,
              damageTaken: _damageTaken,
              duration: _matchDuration,
              onRetry: () {
                setState(() => _showGameOver = false);
                _initGame();
              },
              onQuit: _quitToMenu,
            ),
        ],
      ),
    );
  }
}
