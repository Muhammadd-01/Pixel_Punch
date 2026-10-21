import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class DialogueOverlay extends StatefulWidget {
  final String villainName;
  final String villainTitle;
  final String text;
  final Color color;
  final Uint8List? portrait;
  final VoidCallback onDismiss;

  const DialogueOverlay({
    super.key,
    required this.villainName,
    required this.villainTitle,
    required this.text,
    required this.color,
    this.portrait,
    required this.onDismiss,
  });

  @override
  State<DialogueOverlay> createState() => _DialogueOverlayState();
}

class _DialogueOverlayState extends State<DialogueOverlay> {
  String _displayedText = '';
  int _charIndex = 0;
  Timer? _typewriterTimer;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _startTypewriter();
  }

  void _startTypewriter() {
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 25), (
      timer,
    ) {
      if (_charIndex < widget.text.length) {
        setState(() {
          _charIndex++;
          _displayedText = widget.text.substring(0, _charIndex);
        });
      } else {
        timer.cancel();
        setState(() => _isComplete = true);
      }
    });
  }

  void _skipTypewriter() {
    _typewriterTimer?.cancel();
    setState(() {
      _displayedText = widget.text;
      _isComplete = true;
    });
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: _isComplete ? widget.onDismiss : _skipTypewriter,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xE60D1B2A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.25),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.color, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: widget.portrait != null
                    ? Image.memory(
                        widget.portrait!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      )
                    : Center(
                        child: Text(
                          widget.villainName.isNotEmpty
                              ? widget.villainName[0]
                              : '?',
                          style: TextStyle(
                            color: widget.color,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.villainName,
                          style: TextStyle(
                            color: widget.color,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.villainTitle,
                            style: TextStyle(
                              color: widget.color.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _displayedText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _isComplete ? 'Tap to continue ▸' : 'Tap to skip ▸',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
