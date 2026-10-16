import 'package:flutter/foundation.dart';

/// Audio service for managing game sounds.
/// Uses placeholder implementation until audio assets are available.
class AudioService {
  double _masterVolume = 1.0;
  double _musicVolume = 0.7;
  double _sfxVolume = 1.0;
  bool _isMuted = false;

  double get masterVolume => _masterVolume;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;
  bool get isMuted => _isMuted;

  void setMasterVolume(double volume) {
    _masterVolume = volume.clamp(0.0, 1.0);
  }

  void setMusicVolume(double volume) {
    _musicVolume = volume.clamp(0.0, 1.0);
  }

  void setSfxVolume(double volume) {
    _sfxVolume = volume.clamp(0.0, 1.0);
  }

  void toggleMute() {
    _isMuted = !_isMuted;
  }

  /// Play a sound effect. Falls back silently if asset not available.
  void playSfx(String name) {
    if (_isMuted) return;
    debugPrint('[Audio] SFX: $name');
    // Audio playback will be implemented when assets are available
  }

  /// Play background music. Falls back silently if asset not available.
  void playMusic(String name) {
    if (_isMuted) return;
    debugPrint('[Audio] Music: $name');
  }

  /// Stop all audio.
  void stopAll() {
    debugPrint('[Audio] Stop all');
  }

  /// Handle app lifecycle pause.
  void onPause() {
    stopAll();
  }

  /// Handle app lifecycle resume.
  void onResume() {
    // Resume music if it was playing
  }

  void dispose() {
    stopAll();
  }
}
