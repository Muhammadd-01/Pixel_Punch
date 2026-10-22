import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../services/audio_service.dart';

/// Plays [track] while this widget is on screen. When it goes away, the
/// track of the screen underneath (if any) resumes automatically.
class MusicScope extends StatefulWidget {
  final MusicTrack track;
  final Widget child;

  const MusicScope({super.key, required this.track, required this.child});

  static final List<_MusicScopeState> _stack = [];

  /// Changes the track for the screen currently on top (e.g. battle starts).
  static void switchTo(BuildContext context, MusicTrack track) {
    final state = context.findAncestorStateOfType<_MusicScopeState>();
    state?._track = track;
    if (state != null && _stack.isNotEmpty && identical(_stack.last, state)) {
      state._audio?.playTrack(track);
    }
  }

  @override
  State<MusicScope> createState() => _MusicScopeState();
}

class _MusicScopeState extends State<MusicScope> {
  late MusicTrack _track = widget.track;
  AudioService? _audio;

  @override
  void initState() {
    super.initState();
    _audio = context.read<AudioService>();
    MusicScope._stack.add(this);
    _audio?.playTrack(_track);
  }

  @override
  void dispose() {
    MusicScope._stack.remove(this);
    if (MusicScope._stack.isNotEmpty) {
      final top = MusicScope._stack.last;
      _audio?.playTrack(top._track);
    } else {
      _audio?.stopMusic();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Pauses music when the app is backgrounded and resumes it afterwards.
class AudioLifecycle extends StatefulWidget {
  final Widget child;
  const AudioLifecycle({super.key, required this.child});

  @override
  State<AudioLifecycle> createState() => _AudioLifecycleState();
}

class _AudioLifecycleState extends State<AudioLifecycle> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final audio = context.read<AudioService>();
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      audio.onPause();
    } else if (state == AppLifecycleState.resumed) {
      audio.onResume();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
