import '../pixel_punch_game.dart';

/// Manages combat state, turn logic, and periodic villain taunts.
class CombatManager {
  final PixelPunchGame game;
  double _tauntTimer = 0;
  static const double _tauntInterval = 10.0;

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
    final aliveVillains =
        game.villainComponents.where((v) => !v.isKnockedOut).toList();
    if (aliveVillains.isEmpty) return;

    final villain =
        aliveVillains[DateTime.now().millisecondsSinceEpoch % aliveVillains.length];
    villain.tryCombatTaunt();
  }
}
