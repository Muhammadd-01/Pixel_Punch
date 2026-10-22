// Opens the Unity 3D match (exported to android/unityLibrary via
// Flutter → Export Android Release in Unity). See unity/README.md.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_unity_widget_2/flutter_unity_widget_2.dart';
import 'package:provider/provider.dart';
import '../../app/app_theme.dart';
import '../../services/game_state_service.dart';
import 'royale_config.dart';

class RoyaleLauncher {
  RoyaleLauncher._();

  static bool get isAvailable => true;

  static Future<void> launch(BuildContext context, Map<String, dynamic> config) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RoyaleGameScreen(config: config), fullscreenDialog: true),
    );
  }
}

/// Hosts the Unity 3D match full-screen and relays messages both ways.
class RoyaleGameScreen extends StatefulWidget {
  final Map<String, dynamic> config;
  const RoyaleGameScreen({super.key, required this.config});

  @override
  State<RoyaleGameScreen> createState() => _RoyaleGameScreenState();
}

class _RoyaleGameScreenState extends State<RoyaleGameScreen> {
  UnityWidgetController? _unity;
  String? _sessionCode;
  bool _started = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _unity?.postMessage('GameBridge', 'QuitMatch', '');
    _unity?.pause();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _onUnityCreated(UnityWidgetController controller) {
    _unity = controller;
    // Normally the game says "unity_ready"; this is a fallback in case that
    // message was sent before Flutter started listening.
    Future.delayed(const Duration(seconds: 3), _startMatch);
  }

  void _startMatch() {
    if (_started || _unity == null) return;
    _started = true;
    _unity!.resume();
    _unity!.postMessage('GameBridge', 'StartMatch', jsonEncode(widget.config));
  }

  void _onUnityMessage(dynamic raw) {
    Map<String, dynamic> message;
    try {
      message = jsonDecode(raw.toString()) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final data = (message['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    switch (message['type']) {
      case 'unity_ready':
        _startMatch();
      case 'session_code':
        setState(() => _sessionCode = data['code'] as String?);
      case 'match_over':
        final rewards = RoyaleResults.record(context.read<GameStateService>(), data, widget.config);
        _toast('+${rewards.xpEarned} XP${rewards.leveledUp ? ' · Level ${rewards.level}!' : ''}');
      case 'error':
        _toast(data['message'] as String? ?? 'Something went wrong.');
        if (!_started) _close();
      case 'disconnected':
        _toast(data['reason'] as String? ?? 'Disconnected.');
      case 'exit_requested':
      case 'match_closed':
        _close();
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _closing,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Leave the match?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Stay')),
              TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Leave')),
            ],
          ),
        );
        if (leave == true) {
          _unity?.postMessage('GameBridge', 'QuitMatch', '');
          _close();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            UnityWidget(
              onUnityCreated: _onUnityCreated,
              onUnityMessage: _onUnityMessage,
              useAndroidViewSurface: true,
              fullscreen: true,
            ),
            if (_sessionCode != null)
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _sessionCode!));
                        _toast('Squad code copied — send it to your friends!');
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.group, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text('SQUAD CODE  $_sessionCode',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                            const SizedBox(width: 8),
                            const Icon(Icons.copy, color: Colors.white70, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
