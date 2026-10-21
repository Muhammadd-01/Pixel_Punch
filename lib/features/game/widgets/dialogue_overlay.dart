import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app/app_theme.dart';
import '../../../services/audio_service.dart';

/// In-game dialogue overlay with typewriter text and villain voice blips.
class DialogueOverlay extends StatefulWidget {
  final String villainName;
  final String villainTitle;
  final String text;
  final Color villainColor;
  final VoidCallback onDismiss;
  final AudioService? audioService;
  final String? archetype;

  const DialogueOverlay({
    super.key,
    required this.villainName,
    required this.villainTitle,
    required this.text,
    required this.villainColor,
    required this.onDismiss,
    this.audioService,
    this.archetype,
  });

  @override
  State<DialogueOverlay> createState() => _DialogueOverlayState();
}

class _DialogueOverlayState extends State<DialogueOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  int _revealedChars = 0;
  bool _textComplete = false;
  final Random _rng = Random();

  VoiceType get _voiceType {
    return switch (widget.archetype?.toLowerCase()) {
      'tank' => VoiceType.tank,
      'speedster' => VoiceType.speedster,
      'heavy_hitter' => VoiceType.heavyHitter,
      'trickster' => VoiceType.trickster,
      'support' => VoiceType.support,
      _ => VoiceType.villain,
    };
  }

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0, 0.6, curve: Curves.easeIn),
      ),
    );
    _entranceController.forward();

    // Play discovery/encounter sound
    widget.audioService?.playGameEvent(GameEventSound.villainDiscover);

    // Start typewriter
    _startTypewriter();
  }

  void _startTypewriter() async {
    for (int i = 0; i < widget.text.length; i++) {
      await Future.delayed(const Duration(milliseconds: 30));
      if (!mounted) return;

      setState(() => _revealedChars = i + 1);

      // Play voice blip on non-space characters (every 2-3 chars for natural feel)
      final char = widget.text[i];
      if (char != ' ' && char != '\n' && i % (2 + _rng.nextInt(2)) == 0) {
        widget.audioService?.playVoiceBlip(_voiceType);
      }
    }
    if (mounted) setState(() => _textComplete = true);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_textComplete) {
          widget.onDismiss();
        } else {
          // Skip to end
          setState(() {
            _revealedChars = widget.text.length;
            _textComplete = true;
          });
        }
      },
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  constraints: const BoxConstraints(maxWidth: 600),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.villainColor.withValues(alpha: 0.6),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.villainColor.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Villain header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.villainColor.withValues(alpha: 0.2),
                              widget.villainColor.withValues(alpha: 0.05),
                            ],
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Villain avatar circle
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    widget.villainColor.withValues(alpha: 0.2),
                                border: Border.all(
                                  color: widget.villainColor
                                      .withValues(alpha: 0.6),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  widget.villainName.isNotEmpty
                                      ? widget.villainName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: widget.villainColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.villainName,
                                    style: TextStyle(
                                      color: widget.villainColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (widget.villainTitle.isNotEmpty)
                                    Text(
                                      widget.villainTitle,
                                      style: TextStyle(
                                        color: widget.villainColor
                                            .withValues(alpha: 0.7),
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Speaking indicator
                            if (!_textComplete)
                              _SpeakingIndicator(color: widget.villainColor),
                          ],
                        ),
                      ),

                      // Dialogue text (typewriter)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: widget.text
                                    .substring(0, _revealedChars),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                              if (!_textComplete)
                                TextSpan(
                                  text: '▌',
                                  style: TextStyle(
                                    color: widget.villainColor,
                                    fontSize: 15,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Tap to continue hint
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                        child: AnimatedOpacity(
                          opacity: _textComplete ? 1.0 : 0.3,
                          duration: const Duration(milliseconds: 300),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                _textComplete
                                    ? 'Tap to continue'
                                    : 'Tap to skip',
                                style: TextStyle(
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.6),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.touch_app_rounded,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.5),
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated speaking indicator (pulsing dots).
class _SpeakingIndicator extends StatefulWidget {
  final Color color;
  const _SpeakingIndicator({required this.color});

  @override
  State<_SpeakingIndicator> createState() => _SpeakingIndicatorState();
}

class _SpeakingIndicatorState extends State<_SpeakingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final delay = i * 0.2;
          final value = (((_controller.value + delay) % 1.0) * 2)
              .clamp(0.0, 1.0);
          final scale = 0.5 + 0.5 * sin(value * pi);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 6,
            height: 6 * scale,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.5 + 0.5 * scale),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }
}
