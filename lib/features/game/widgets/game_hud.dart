import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../app/app_theme.dart';
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
  Offset _joystickCenter = Offset.zero;
  Offset _joystickKnob = Offset.zero;
  bool _joystickActive = false;
  static const double _joystickRadius = 50.0;
  static const double _knobRadius = 20.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildTopBar(),
        _buildJoystick(),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 8,
      left: 16,
      right: 16,
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildHealthIndicator(
              name: widget.game.player.fighterData.name,
              healthPercent: widget.game.player.healthPercent,
              color: AppColors.friendly,
              isFriendly: true,
            ),
            IconButton(
              onPressed: widget.onPause,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.pause, color: Colors.white, size: 20),
              ),
            ),
            if (widget.game.villainComponents.isNotEmpty)
              _buildHealthIndicator(
                name: widget.game.villainComponents.first.fighterData.name,
                healthPercent: widget.game.villainComponents.first.healthPercent,
                color: AppColors.enemy,
                isFriendly: false,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthIndicator({
    required String name,
    required double healthPercent,
    required Color color,
    required bool isFriendly,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            isFriendly ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(
            name,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: 100,
            height: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: healthPercent.clamp(0.0, 1.0),
                backgroundColor: Colors.grey[800],
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoystick() {
    return Positioned(
      left: 24,
      bottom: 24,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _joystickActive = true;
            _joystickCenter = details.localPosition;
            _joystickKnob = details.localPosition;
          });
        },
        onPanUpdate: (details) {
          if (!_joystickActive) return;
          final delta = details.localPosition - _joystickCenter;
          final distance = delta.distance;
          final clampedDistance = distance.clamp(0.0, _joystickRadius);
          final direction = delta / (distance == 0 ? 1 : distance);

          setState(() {
            _joystickKnob = _joystickCenter + direction * clampedDistance;
          });

          final normalizedDir = Vector2(
            direction.dx * (clampedDistance / _joystickRadius),
            direction.dy * (clampedDistance / _joystickRadius),
          );
          widget.onJoystickUpdate(normalizedDir);
        },
        onPanEnd: (details) {
          setState(() {
            _joystickActive = false;
            _joystickKnob = _joystickCenter;
          });
          widget.onJoystickUpdate(Vector2.zero());
        },
        onPanCancel: () {
          setState(() {
            _joystickActive = false;
            _joystickKnob = _joystickCenter;
          });
          widget.onJoystickUpdate(Vector2.zero());
        },
        child: Container(
          width: _joystickRadius * 2 + 30,
          height: _joystickRadius * 2 + 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black38,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              if (_joystickActive)
                Positioned(
                  left: _joystickKnob.dx - _knobRadius + _joystickRadius + 15 - _joystickCenter.dx,
                  top: _joystickKnob.dy - _knobRadius + _joystickRadius + 15 - _joystickCenter.dy,
                  child: Container(
                    width: _knobRadius * 2,
                    height: _knobRadius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Center(
                  child: Container(
                    width: _knobRadius * 2,
                    height: _knobRadius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    child: const Icon(
                      Icons.control_camera,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Positioned(
      right: 24,
      bottom: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildActionButton(
            icon: Icons.flash_on,
            label: 'Special',
            color: AppColors.accent,
            onTap: widget.onSpecial,
            size: 50,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(
                icon: Icons.shield,
                label: 'Dodge',
                color: AppColors.secondary,
                onTap: widget.onDodge,
                size: 46,
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                icon: Icons.sports_mma,
                label: 'Attack',
                color: AppColors.primary,
                onTap: widget.onAttack,
                size: 62,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    double size = 52,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.35),
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: size * 0.42),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
