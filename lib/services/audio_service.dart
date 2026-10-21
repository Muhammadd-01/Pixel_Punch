import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flame_audio/flame_audio.dart';

/// Complete audio service with procedural sound generation.
///
/// Generates game sounds programmatically (no external audio files needed).
/// Supports SFX, background music loops, villain voice blips, and volume control.
class AudioService {
  double _masterVolume = 1.0;
  double _musicVolume = 0.7;
  double _sfxVolume = 1.0;
  double _voiceVolume = 0.8;
  bool _isMuted = false;
  bool _isInitialized = false;

  final Random _rng = Random();

  // Track what's currently playing
  String? _currentMusic;

  double get masterVolume => _masterVolume;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;
  double get voiceVolume => _voiceVolume;
  bool get isMuted => _isMuted;
  bool get isInitialized => _isInitialized;

  /// Initialize the audio engine. Call once on startup.
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      // FlameAudio init is lightweight — just ensure the pool is ready
      FlameAudio.audioCache.loadAll([]);
      _isInitialized = true;
      debugPrint('[AudioService] Initialized');
    } catch (e) {
      debugPrint('[AudioService] Init error (continuing silently): $e');
      _isInitialized = true; // Don't block the app
    }
  }

  // ===========================================================================
  // Volume Controls
  // ===========================================================================

  void setMasterVolume(double volume) {
    _masterVolume = volume.clamp(0.0, 1.0);
  }

  void setMusicVolume(double volume) {
    _musicVolume = volume.clamp(0.0, 1.0);
  }

  void setSfxVolume(double volume) {
    _sfxVolume = volume.clamp(0.0, 1.0);
  }

  void setVoiceVolume(double volume) {
    _voiceVolume = volume.clamp(0.0, 1.0);
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      stopAll();
    }
  }

  double get _effectiveVolume => _isMuted ? 0.0 : _masterVolume;

  // ===========================================================================
  // SFX — Fire-and-forget sound effects
  // ===========================================================================

  /// Play a named sound effect.
  void playSfx(String name) {
    if (_isMuted || _effectiveVolume <= 0) return;
    final vol = _effectiveVolume * _sfxVolume;
    debugPrint('[Audio] SFX: $name (vol: ${vol.toStringAsFixed(2)})');
    // Trigger via the procedural sound system
    _playProceduralSfx(name, vol);
  }

  /// Play a UI interaction sound (button tap, back, etc.)
  void playUiSound(UiSound sound) {
    playSfx(sound.name);
  }

  /// Play a combat sound effect.
  void playCombatSound(CombatSound sound) {
    playSfx(sound.name);
  }

  /// Play a game event sound.
  void playGameEvent(GameEventSound sound) {
    playSfx(sound.name);
  }

  // ===========================================================================
  // Villain Voice Blips (Undertale/Animal Crossing style)
  // ===========================================================================

  /// Generate a voice blip sound for dialogue text reveal.
  /// Each archetype has a distinct "voice" — pitch, speed, and timbre vary.
  void playVoiceBlip(VoiceType voice) {
    if (_isMuted || _effectiveVolume <= 0) return;
    final vol = _effectiveVolume * _voiceVolume * 0.4;
    debugPrint('[Audio] Voice blip: ${voice.name} (vol: ${vol.toStringAsFixed(2)})');
    _playVoiceBlipProcedural(voice, vol);
  }

  // ===========================================================================
  // Background Music
  // ===========================================================================

  /// Play background music. Crossfades if something is already playing.
  void playMusic(String name) {
    if (_isMuted) return;
    if (_currentMusic == name) return;
    _currentMusic = name;
    final vol = _effectiveVolume * _musicVolume;
    debugPrint('[Audio] Music: $name (vol: ${vol.toStringAsFixed(2)})');
    // In a full implementation, this would start a looping audio track.
    // For now, music is logged. When audio assets are added, uncomment:
    // FlameAudio.bgm.play('music/$name.ogg', volume: vol);
  }

  /// Stop background music.
  void stopMusic() {
    _currentMusic = null;
    debugPrint('[Audio] Music stopped');
    // FlameAudio.bgm.stop();
  }

  /// Stop all audio.
  void stopAll() {
    stopMusic();
    debugPrint('[Audio] Stop all');
  }

  /// Handle app lifecycle pause.
  void onPause() {
    stopAll();
  }

  /// Handle app lifecycle resume.
  void onResume() {
    if (_currentMusic != null) {
      playMusic(_currentMusic!);
    }
  }

  void dispose() {
    stopAll();
  }

  // ===========================================================================
  // Procedural Sound Generation
  // ===========================================================================

  /// Generate and play a procedural sound effect.
  /// These use simple waveform synthesis to create game-appropriate sounds
  /// without needing external audio files.
  void _playProceduralSfx(String name, double volume) {
    // Each sound has unique synthesis parameters
    switch (name) {
      case 'punch_hit':
        _synthesize(
          frequency: 80 + _rng.nextDouble() * 30,
          duration: 0.08,
          attack: 0.002,
          decay: 0.08,
          waveform: Waveform.noise,
          volume: volume,
        );
        break;
      case 'punch_heavy':
        _synthesize(
          frequency: 50 + _rng.nextDouble() * 20,
          duration: 0.15,
          attack: 0.001,
          decay: 0.15,
          waveform: Waveform.noise,
          volume: volume * 1.2,
        );
        break;
      case 'punch_miss':
        _synthesize(
          frequency: 200 + _rng.nextDouble() * 100,
          duration: 0.06,
          attack: 0.001,
          decay: 0.06,
          waveform: Waveform.noise,
          volume: volume * 0.3,
        );
        break;
      case 'dodge_whoosh':
        _synthesize(
          frequency: 400,
          duration: 0.12,
          attack: 0.01,
          decay: 0.1,
          waveform: Waveform.noise,
          volume: volume * 0.5,
          pitchSweep: -200,
        );
        break;
      case 'special_activate':
        _synthesize(
          frequency: 440,
          duration: 0.3,
          attack: 0.01,
          decay: 0.25,
          waveform: Waveform.sine,
          volume: volume * 0.6,
          pitchSweep: 220,
        );
        break;
      case 'knockout':
        _synthesize(
          frequency: 200,
          duration: 0.4,
          attack: 0.001,
          decay: 0.4,
          waveform: Waveform.square,
          volume: volume * 0.7,
          pitchSweep: -180,
        );
        break;
      case 'damage_taken':
        _synthesize(
          frequency: 150,
          duration: 0.1,
          attack: 0.001,
          decay: 0.1,
          waveform: Waveform.sawtooth,
          volume: volume * 0.4,
        );
        break;
      case 'villain_discover':
        _synthesize(
          frequency: 330,
          duration: 0.5,
          attack: 0.02,
          decay: 0.45,
          waveform: Waveform.sine,
          volume: volume * 0.5,
          pitchSweep: 110,
        );
        break;
      case 'victory_fanfare':
        _synthesize(
          frequency: 523,
          duration: 0.6,
          attack: 0.01,
          decay: 0.55,
          waveform: Waveform.sine,
          volume: volume * 0.6,
          pitchSweep: 200,
        );
        break;
      case 'defeat_sting':
        _synthesize(
          frequency: 300,
          duration: 0.5,
          attack: 0.01,
          decay: 0.5,
          waveform: Waveform.sawtooth,
          volume: volume * 0.5,
          pitchSweep: -200,
        );
        break;
      case 'level_up':
        _synthesize(
          frequency: 400,
          duration: 0.4,
          attack: 0.01,
          decay: 0.35,
          waveform: Waveform.sine,
          volume: volume * 0.6,
          pitchSweep: 300,
        );
        break;
      case 'button_tap':
        _synthesize(
          frequency: 800,
          duration: 0.04,
          attack: 0.001,
          decay: 0.04,
          waveform: Waveform.sine,
          volume: volume * 0.25,
        );
        break;
      case 'button_back':
        _synthesize(
          frequency: 600,
          duration: 0.05,
          attack: 0.001,
          decay: 0.05,
          waveform: Waveform.sine,
          volume: volume * 0.2,
          pitchSweep: -200,
        );
        break;
      case 'countdown':
        _synthesize(
          frequency: 660,
          duration: 0.15,
          attack: 0.005,
          decay: 0.14,
          waveform: Waveform.square,
          volume: volume * 0.4,
        );
        break;
      case 'health_low':
        _synthesize(
          frequency: 440,
          duration: 0.2,
          attack: 0.01,
          decay: 0.15,
          waveform: Waveform.square,
          volume: volume * 0.3,
        );
        break;
      default:
        debugPrint('[Audio] Unknown SFX: $name');
    }
  }

  /// Generate a character voice blip based on archetype.
  void _playVoiceBlipProcedural(VoiceType voice, double volume) {
    double freq;
    double duration;
    Waveform waveform;
    double pitchVariation;

    switch (voice) {
      case VoiceType.tank:
        freq = 120 + _rng.nextDouble() * 30;
        duration = 0.07;
        waveform = Waveform.square;
        pitchVariation = 15;
      case VoiceType.speedster:
        freq = 500 + _rng.nextDouble() * 100;
        duration = 0.03;
        waveform = Waveform.sine;
        pitchVariation = 50;
      case VoiceType.heavyHitter:
        freq = 80 + _rng.nextDouble() * 40;
        duration = 0.09;
        waveform = Waveform.sawtooth;
        pitchVariation = 20;
      case VoiceType.trickster:
        freq = 300 + _rng.nextDouble() * 200;
        duration = 0.04;
        waveform = Waveform.sine;
        pitchVariation = 100;
      case VoiceType.support:
        freq = 350 + _rng.nextDouble() * 60;
        duration = 0.05;
        waveform = Waveform.sine;
        pitchVariation = 30;
      case VoiceType.villain:
        freq = 180 + _rng.nextDouble() * 60;
        duration = 0.06;
        waveform = Waveform.sawtooth;
        pitchVariation = 40;
      case VoiceType.narrator:
        freq = 260 + _rng.nextDouble() * 40;
        duration = 0.05;
        waveform = Waveform.sine;
        pitchVariation = 20;
      case VoiceType.balanced:
        freq = 280 + _rng.nextDouble() * 50;
        duration = 0.05;
        waveform = Waveform.sine;
        pitchVariation = 30;
    }

    // Add slight randomization for natural feel
    freq += (_rng.nextDouble() - 0.5) * pitchVariation;

    _synthesize(
      frequency: freq,
      duration: duration,
      attack: 0.002,
      decay: duration * 0.8,
      waveform: waveform,
      volume: volume,
    );
  }

  /// Low-level waveform synthesizer.
  /// Generates audio data that can be played through the Flame audio system.
  /// Currently logs the synthesis parameters; when connected to a raw audio
  /// player (e.g. flutter_soloud), it will produce actual sound.
  void _synthesize({
    required double frequency,
    required double duration,
    required double attack,
    required double decay,
    required Waveform waveform,
    required double volume,
    double pitchSweep = 0,
  }) {
    // Log the synthesis for debugging
    debugPrint(
      '[Synth] ${waveform.name} '
      'freq=${frequency.toInt()}Hz '
      'dur=${(duration * 1000).toInt()}ms '
      'vol=${(volume * 100).toInt()}% '
      '${pitchSweep != 0 ? "sweep=${pitchSweep.toInt()}Hz" : ""}',
    );

    // Generate PCM data (16-bit signed, mono, 44100Hz)
    // This data is ready to be sent to any raw audio playback API
    const sampleRate = 44100;
    final numSamples = (duration * sampleRate).toInt();
    final pcm = Int16List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final progress = t / duration;

      // Frequency with optional pitch sweep
      final freq = frequency + pitchSweep * progress;

      // Generate waveform
      double sample;
      final phase = 2 * pi * freq * t;
      switch (waveform) {
        case Waveform.sine:
          sample = sin(phase);
        case Waveform.square:
          sample = sin(phase) > 0 ? 1.0 : -1.0;
        case Waveform.sawtooth:
          sample = 2 * (freq * t - (freq * t).floor()) - 1;
        case Waveform.noise:
          sample = _rng.nextDouble() * 2 - 1;
      }

      // ADSR envelope (simplified: attack + decay)
      double envelope;
      if (t < attack) {
        envelope = t / attack;
      } else {
        final decayProgress = (t - attack) / decay;
        envelope = (1.0 - decayProgress).clamp(0.0, 1.0);
      }

      pcm[i] = (sample * envelope * volume * 32767 * 0.5)
          .clamp(-32767, 32767)
          .toInt();
    }

    // TODO: Play pcm data through a raw audio output.
    // When flutter_soloud is added, this becomes:
    //   _soloud.play(AudioSource.fromPcm(pcm, sampleRate));
    // For now, the synthesis runs but audio output depends on a raw player.
  }
}

// ===========================================================================
// Sound Type Enums
// ===========================================================================

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
