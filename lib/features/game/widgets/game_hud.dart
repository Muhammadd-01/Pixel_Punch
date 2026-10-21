import 'dart:async';
import 'dart:math' as math;
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import '../../../app/app_theme.dart';
import '../../../game/components/fighter_base.dart';
import '../../../game/pixel_punch_game.dart';

class GameHud extends StatefulWidget {
  final PixelPunchGame game;
  final VoidCallback onPause;
  final VoidCallback onAttack;
  final VoidCallback onSpecial;
  final VoidCallback onDodge;
  final ValueChanged<Vector2> onJoystickUpdate;

  const GameHud({
    super.key,
    required this.game,
    required this.onPause,
    required this.onAttack,
    required this.onSpecial,
    required this.onDodge,
    required this.onJoystickUpdate,
  });

  @override
  State<GameHud> createState() => _GameHudState();
}

class _GameHudState extends State<GameHud> {
  // Floating joystick (multi-touch safe: raw pointer tracking).
  int? _joyPointer;
  Offset _joyCenter = Offset.zero;
  Offset _joyKnob = Offset.zero;
  static const double _joyRadius = 52.0;
  static const double _knobRadius = 22.0;

  Timer? _attackRepeat;

  @override
  void dispose() {
    _attackRepeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.game.hudTick,
      builder: (context, _, __) {
        if (!widget.game.isReady) return const SizedBox.shrink();
        return Stack(
          children: [
            _buildJoystickArea(),
            _buildTopBar(),
            _buildActionButtons(),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Top bar

  Widget _buildTopBar() {
    final game = widget.game;
    final friends = <FighterBase>[game.player, ...game.teammateComponents];
    final enemies = game.villainComponents;
    final defeated = enemies.where((v) => v.isKnockedOut).length;
    final anyFound = enemies.any((v) => v.discovered);
    final objective = !anyFound
        ? 'Explore the zone and find the villains'
        : 'Defeat the villains  $defeated/${enemies.length}';
    final t = game.matchTimer.toInt();
    final time = '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final f in friends)
                      _healthCard(f, AppColors.friendly, isMain: f == game.player),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _pill(time, Icons.timer_outlined),
                      const SizedBox(width: 6),
                      Material(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: widget.onPause,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.pause, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 230),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      objective,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final v in enemies)
                      _healthCard(v, AppColors.enemy,
                          hidden: !v.discovered && !v.isKnockedOut),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text(text,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _healthCard(FighterBase f, Color color,
      {bool isMain = false, bool hidden = false}) {
    final ko = f.isKnockedOut;
    final name = hidden ? '???' : f.fighterData.name;
    final width = isMain ? 120.0 : 90.0;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
        border: isMain ? Border.all(color: color.withValues(alpha: 0.6)) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: width,
            child: Text(
              ko ? '$name  KO' : name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ko ? Colors.white38 : color,
                fontSize: isMain ? 11 : 9.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: width,
            height: isMain ? 7 : 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: hidden ? 1 : f.healthPercent.clamp(0.0, 1.0),
                backgroundColor: Colors.grey[850],
                valueColor: AlwaysStoppedAnimation(
                    hidden ? Colors.white24 : (f.isLowHealth ? AppColors.healthLow : color)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Joystick

  Widget _buildJoystickArea() {
    return Positioned(
      left: 0,
      bottom: 0,
      width: MediaQuery.of(context).size.width * 0.5,
      height: MediaQuery.of(context).size.height * 0.75,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) {
          if (_joyPointer != null) return;
          setState(() {
            _joyPointer = e.pointer;
            _joyCenter = e.localPosition;
            _joyKnob = e.localPosition;
          });
        },
        onPointerMove: (e) {
          if (e.pointer != _joyPointer) return;
          final delta = e.localPosition - _joyCenter;
          final distance = delta.distance;
          final clamped = math.min(distance, _joyRadius);
          final dir = distance == 0 ? Offset.zero : delta / distance;
          setState(() => _joyKnob = _joyCenter + dir * clamped);
          final strength = clamped / _joyRadius;
          widget.onJoystickUpdate(
            strength < 0.15 ? Vector2.zero() : Vector2(dir.dx * strength, dir.dy * strength),
          );
        },
        onPointerUp: (e) => _releaseJoystick(e.pointer),
        onPointerCancel: (e) => _releaseJoystick(e.pointer),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final active = _joyPointer != null;
            final center = active
                ? _joyCenter
                : Offset(24 + _joyRadius + 10, constraints.maxHeight - 24 - _joyRadius - 10);
            final knob = active ? _joyKnob : center;
            return Stack(
              children: [
                Positioned(
                  left: center.dx - _joyRadius - 10,
                  top: center.dy - _joyRadius - 10,
                  child: IgnorePointer(
                    child: Container(
                      width: (_joyRadius + 10) * 2,
                      height: (_joyRadius + 10) * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: active ? 0.35 : 0.22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: knob.dx - _knobRadius,
                  top: knob.dy - _knobRadius,
                  child: IgnorePointer(
                    child: Container(
                      width: _knobRadius * 2,
                      height: _knobRadius * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.3),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: active
                          ? null
                          : const Icon(Icons.open_with, color: Colors.white70, size: 20),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _releaseJoystick(int pointer) {
    if (pointer != _joyPointer) return;
    setState(() => _joyPointer = null);
    widget.onJoystickUpdate(Vector2.zero());
  }

  // ---------------------------------------------------------------------------
  // Action buttons

  Widget _buildActionButtons() {
    final player = widget.game.player;
    final special = player.abilityData;
    return Positioned(
      right: 20,
      bottom: 18,
      child: SafeArea(
        top: false,
        left: false,
        child: SizedBox(
          width: 170,
          height: 150,
          child: Stack(
            children: [
              Positioned(
                right: 0,
                bottom: 0,
                child: _actionButton(
                  icon: Icons.sports_mma,
                  label: 'Punch',
                  color: AppColors.primary,
                  size: 76,
                  progress: 1,
                  onDown: () {
                    widget.onAttack();
                    _attackRepeat?.cancel();
                    _attackRepeat = Timer.periodic(
                      const Duration(milliseconds: 120),
                      (_) => widget.onAttack(),
                    );
                  },
                  onUp: () => _attackRepeat?.cancel(),
                ),
              ),
              Positioned(
                right: 78,
                bottom: 0,
                child: _actionButton(
                  icon: Icons.directions_run,
                  label: 'Dodge',
                  color: AppColors.secondary,
                  size: 54,
                  progress: player.dodgeCooldownProgress,
                  onDown: widget.onDodge,
                ),
              ),
              Positioned(
                right: 6,
                bottom: 84,
                child: _actionButton(
                  icon: Icons.flash_on,
                  label: special?.name.split(' ').last ?? 'Special',
                  color: AppColors.accent,
                  size: 60,
                  progress: player.specialCooldownProgress,
                  onDown: widget.onSpecial,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required double size,
    required double progress,
    required VoidCallback onDown,
    VoidCallback? onUp,
  }) {
    final ready = progress >= 1;
    return Listener(
      onPointerDown: (_) => onDown(),
      onPointerUp: (_) => onUp?.call(),
      onPointerCancel: (_) => onUp?.call(),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: ready ? 0.4 : 0.15),
                border: Border.all(
                    color: ready ? color : color.withValues(alpha: 0.4), width: 2),
                boxShadow: ready
                    ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10)]
                    : null,
              ),
            ),
            if (!ready)
              SizedBox(
                width: size - 4,
                height: size - 4,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 3,
                  color: color,
                  backgroundColor: Colors.black26,
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    color: ready ? Colors.white : Colors.white54, size: size * 0.4),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: ready ? Colors.white : Colors.white54,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
