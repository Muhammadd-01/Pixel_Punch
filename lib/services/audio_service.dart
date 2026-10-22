import 'package:flutter/foundation.dart';
import 'package:flame_audio/flame_audio.dart';

/// Plays PixelPunch's sound effects, dialogue voice blips and music loops.
///
/// The WAV files in `assets/audio/` are synthesised by
/// `tools/generate_audio.py`, so they can be regenerated or tweaked freely.
/// Every call fails silently: audio problems must never break the game.
class AudioService {
  double _masterVolume = 1.0;
  double _musicVolume = 0.6;
  double _sfxVolume = 1.0;
  double _voiceVolume = 0.8;
  bool _isMuted = false;
  bool _isInitialized = false;

  String? _currentMusic;
  bool _musicPaused = false;
  final Map<String, int> _lastPlayed = {};

  static const _sfxFiles = [
    'button_tap', 'button_back', 'menu_hover', 'punch_hit', 'punch_heavy',
    'punch_miss', 'dodge_whoosh', 'special_activate', 'damage_taken',
    'knockout', 'health_low', 'villain_discover', 'victory_fanfare',
    'defeat_sting', 'level_up', 'countdown', 'gun_shot', 'gun_reload',
    'item_pickup', 'jump', 'land', 'footstep',
  ];

  double get masterVolume => _masterVolume;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;
  double get voiceVolume => _voiceVolume;
  bool get isMuted => _isMuted;
  bool get isInitialized => _isInitialized;
  String? get currentMusic => _currentMusic;

  /// Preloads sound effects and restores saved volumes. Call once on startup.
  Future<void> initialize({Map<String, dynamic>? settings}) async {
    if (_isInitialized) return;
    if (settings != null) applySettings(settings);
    try {
      FlameAudio.bgm.initialize();
      await FlameAudio.audioCache.loadAll([
        for (final s in _sfxFiles) 'sfx/$s.wav',
        for (final v in VoiceType.values) 'voice/${v.name}.wav',
      ]);
      debugPrint('[AudioService] Initialized');
    } catch (e) {
      debugPrint('[AudioService] Init error (continuing silently): $e');
    }
    _isInitialized = true;
  }

  /// Restores volumes saved by the settings screen.
  void applySettings(Map<String, dynamic> settings) {
    _masterVolume = (settings['master_volume'] as num?)?.toDouble() ?? _masterVolume;
    _musicVolume = (settings['music_volume'] as num?)?.toDouble() ?? _musicVolume;
    _sfxVolume = (settings['sfx_volume'] as num?)?.toDouble() ?? _sfxVolume;
    _voiceVolume = (settings['voice_volume'] as num?)?.toDouble() ?? _voiceVolume;
    _isMuted = settings['muted'] as bool? ?? _isMuted;
  }

  // ===========================================================================
  // Volume Controls

  void setMasterVolume(double volume) {
    _masterVolume = volume.clamp(0.0, 1.0);
    _updateMusicVolume();
  }

  void setMusicVolume(double volume) {
    _musicVolume = volume.clamp(0.0, 1.0);
    _updateMusicVolume();
  }

  void setSfxVolume(double volume) {
    _sfxVolume = volume.clamp(0.0, 1.0);
  }

  void setVoiceVolume(double volume) {
    _voiceVolume = volume.clamp(0.0, 1.0);
  }

  void toggleMute() => setMuted(!_isMuted);

  void setMuted(bool muted) {
    _isMuted = muted;
    if (_isMuted) {
      _safe(() => FlameAudio.bgm.pause());
      _musicPaused = true;
    } else if (_currentMusic != null) {
      final track = _currentMusic!;
      _currentMusic = null;
      playMusic(track);
    }
  }

  double get _effectiveVolume => _isMuted ? 0.0 : _masterVolume;

  void _updateMusicVolume() {
    final vol = _effectiveVolume * _musicVolume;
    _safe(() => FlameAudio.bgm.audioPlayer.setVolume(vol));
  }

  // ===========================================================================
  // SFX

  /// Play a named sound effect (file name in assets/audio/sfx without .wav).
  void playSfx(String name, {double volume = 1.0, int minGapMs = 45}) {
    final vol = _effectiveVolume * _sfxVolume * volume;
    if (vol <= 0.01) return;
    // Rapid-fire guard so a flurry of hits does not stack 20 players.
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_lastPlayed[name] ?? 0) < minGapMs) return;
    _lastPlayed[name] = now;
    _safe(() => FlameAudio.play('sfx/$name.wav', volume: vol.clamp(0.0, 1.0)));
  }

  void playUiSound(UiSound sound) => playSfx(sound.name, volume: 0.6);

  void playCombatSound(CombatSound sound) => playSfx(sound.name);

  void playGameEvent(GameEventSound sound) => playSfx(sound.name, minGapMs: 400);

  // ===========================================================================
  // Villain Voice Blips (Animal Crossing style)

  void playVoiceBlip(VoiceType voice) {
    final vol = _effectiveVolume * _voiceVolume * 0.5;
    if (vol <= 0.01) return;
    final key = 'voice_${voice.name}';
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (_lastPlayed[key] ?? 0) < 70) return;
    _lastPlayed[key] = now;
    _safe(() => FlameAudio.play('voice/${voice.name}.wav', volume: vol));
  }

  // ===========================================================================
  // Background Music

  void playTrack(MusicTrack track) => playMusic(track.name);

  /// Loops a music track; does nothing if it is already playing.
  void playMusic(String name) {
    if (_currentMusic == name && !_musicPaused) return;
    _currentMusic = name;
    if (_isMuted) return;
    _musicPaused = false;
    final vol = _effectiveVolume * _musicVolume;
    _safe(() => FlameAudio.bgm.play('music/$name.wav', volume: vol));
  }

  void stopMusic() {
    _currentMusic = null;
    _safe(() => FlameAudio.bgm.stop());
  }

  void stopAll() => stopMusic();

  /// App went to the background.
  void onPause() {
    _musicPaused = true;
    _safe(() => FlameAudio.bgm.pause());
  }

  /// App came back to the foreground.
  void onResume() {
    if (_currentMusic != null && !_isMuted) {
      _musicPaused = false;
      _safe(() => FlameAudio.bgm.resume());
    }
  }

  void dispose() {
    _safe(() => FlameAudio.bgm.dispose());
  }

  void _safe(Object? Function() action) {
    try {
      final result = action();
      if (result is Future) {
        result.catchError((Object e) {
          debugPrint('[Audio] $e');
          return null;
        });
      }
    } catch (e) {
      debugPrint('[Audio] $e');
    }
  }
}

/// Waveform shapes for synthesis.
enum Waveform { sine, square, sawtooth, noise }

/// UI interaction sounds.
enum UiSound {
  buttonTap,
  buttonBack,
  menuHover,
  menuSelect,
  toggleOn,
  toggleOff;

  String get name => switch (this) {
    UiSound.buttonTap => 'button_tap',
    UiSound.buttonBack => 'button_back',
    UiSound.menuHover => 'menu_hover',
    UiSound.menuSelect => 'button_tap',
    UiSound.toggleOn => 'button_tap',
    UiSound.toggleOff => 'button_back',
  };
}

/// Combat sound effects.
enum CombatSound {
  punchHit,
  punchHeavy,
  punchMiss,
  dodgeWhoosh,
  specialActivate,
  damageTaken,
  knockout,
  blockImpact,
  healthLow;

  String get name => switch (this) {
    CombatSound.punchHit => 'punch_hit',
    CombatSound.punchHeavy => 'punch_heavy',
    CombatSound.punchMiss => 'punch_miss',
    CombatSound.dodgeWhoosh => 'dodge_whoosh',
    CombatSound.specialActivate => 'special_activate',
    CombatSound.damageTaken => 'damage_taken',
    CombatSound.knockout => 'knockout',
    CombatSound.blockImpact => 'punch_hit',
    CombatSound.healthLow => 'health_low',
  };
}

/// Game event sounds.
enum GameEventSound {
  villainDiscover,
  victoryFanfare,
  defeatSting,
  levelUp,
  unlock,
  countdown;

  String get name => switch (this) {
    GameEventSound.villainDiscover => 'villain_discover',
    GameEventSound.victoryFanfare => 'victory_fanfare',
    GameEventSound.defeatSting => 'defeat_sting',
    GameEventSound.levelUp => 'level_up',
    GameEventSound.unlock => 'level_up',
    GameEventSound.countdown => 'countdown',
  };
}

/// Voice types for dialogue blips — each archetype gets a unique sound.
enum VoiceType {
  balanced,
  tank,
  speedster,
  heavyHitter,
  trickster,
  support,
  villain,
  narrator;
}

/// Music tracks.
enum MusicTrack {
  menuTheme,
  battleTheme1,
  battleTheme2,
  exploration,
  victoryTheme,
  villainLab;

  String get name => switch (this) {
    MusicTrack.menuTheme => 'menu_theme',
    MusicTrack.battleTheme1 => 'battle_theme_1',
    MusicTrack.battleTheme2 => 'battle_theme_2',
    MusicTrack.exploration => 'exploration',
    MusicTrack.victoryTheme => 'victory_theme',
    MusicTrack.villainLab => 'villain_lab',
  };
}
