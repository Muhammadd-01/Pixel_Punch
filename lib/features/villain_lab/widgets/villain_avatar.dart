import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../game/models/custom_villain.dart';
import '../../../game/render/character_painter.dart';

/// Full-body 2D preview of a face-generated villain (or any fighter look).
class VillainAvatar extends StatefulWidget {
  final Uint8List portraitPng;
  final FaceTraits traits;
  final String archetype;
  final double size;
  final bool animate;

  const VillainAvatar({
    super.key,
    required this.portraitPng,
    required this.traits,
    required this.archetype,
    this.size = 120,
    this.animate = true,
  });

  factory VillainAvatar.of(CustomVillain v, {double size = 120, bool animate = true}) =>
      VillainAvatar(
        key: ValueKey('${v.id}-${v.archetype}'),
        portraitPng: v.portraitPng,
        traits: v.traits,
        archetype: v.archetype,
        size: size,
        animate: animate,
      );

  @override
  State<VillainAvatar> createState() => _VillainAvatarState();
}

class _VillainAvatarState extends State<VillainAvatar>
    with SingleTickerProviderStateMixin {
  ui.Image? _image;
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    _decode();
    if (widget.animate) _anim.repeat();
  }

  @override
  void didUpdateWidget(covariant VillainAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.portraitPng, widget.portraitPng)) _decode();
  }

  Future<void> _decode() async {
    final image = await decodeImageFromList(widget.portraitPng);
    if (!mounted) return;
    setState(() => _image = image);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return SizedBox(
      width: widget.size * 0.75,
      height: widget.size,
      child: image == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                final t = _anim.value;
                // A little idle "taunt": punch once per loop.
                final punch = t > 0.7 && t < 0.85 ? 1 - (t - 0.7) / 0.15 : 0.0;
                return CustomPaint(
                  painter: CharacterPreviewPainter(
                    CharacterLook(
                      color: widget.traits.accentColor,
                      archetype: widget.archetype,
                      isVillain: true,
                      skin: widget.traits.skinTone,
                      face: image,
                      traits: widget.traits,
                    ),
                    pose: CharacterPose(
                      walkPhase: t * 6.283,
                      moving: false,
                      attack: punch,
                      facing: const Offset(1, 0.2),
                      angry: punch > 0,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
