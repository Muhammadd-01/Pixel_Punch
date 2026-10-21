import 'dart:math';
import '../pixel_punch_game.dart';

/// Manages combat pacing: periodic villain taunts shown as speech bubbles.
class CombatManager {
  final PixelPunchGame game;
  double _tauntTimer = 0;
  static const double _tauntInterval = 7.0;
  final Random _random = Random();

  CombatManager({required this.game});

  void update(double dt) {
    if (game.isExplorationMode) return;

    _tauntTimer += dt;
    if (_tauntTimer >= _tauntInterval) {
      _tauntTimer = 0;
      _triggerRandomTaunt();
    }
  }

  void _triggerRandomTaunt() {
    final active = game.villainComponents
        .where((v) => !v.isKnockedOut && v.isInCombat)
        .toList();
    if (active.isEmpty) return;
    active[_random.nextInt(active.length)].tryCombatTaunt();
  }
}
