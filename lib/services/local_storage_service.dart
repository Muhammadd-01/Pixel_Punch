import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../game/models/player_progress.dart';
import '../game/models/match_result.dart';

/// Service for local data persistence using SharedPreferences.
class LocalStorageService {
  static const String _progressKey = 'player_progress';
  static const String _matchHistoryKey = 'match_history';
  static const String _settingsKey = 'player_settings';
  static const String _onboardingCompleteKey = 'onboarding_complete';
  static const String _isGuestKey = 'is_guest';
  static const String _guestChosenKey = 'guest_chosen';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Save player progress.
  Future<void> saveProgress(PlayerProgress progress) async {
    final prefs = await _prefs;
    final json = jsonEncode(progress.toJson());
    await prefs.setString(_progressKey, json);
  }

  /// Load player progress.
  Future<PlayerProgress> loadProgress() async {
    try {
      final prefs = await _prefs;
      final json = prefs.getString(_progressKey);
      if (json != null) {
        return PlayerProgress.fromJson(jsonDecode(json) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Error loading progress: $e');
    }
    return PlayerProgress();
  }

  /// Save match history.
  Future<void> saveMatchHistory(List<MatchResult> matches) async {
    final prefs = await _prefs;
    final json = jsonEncode(matches.map((m) => m.toJson()).toList());
    await prefs.setString(_matchHistoryKey, json);
  }

  /// Load match history.
  Future<List<MatchResult>> loadMatchHistory() async {
    try {
      final prefs = await _prefs;
      final json = prefs.getString(_matchHistoryKey);
      if (json != null) {
        final list = jsonDecode(json) as List;
        return list.map((m) => MatchResult.fromJson(m as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('Error loading match history: $e');
    }
    return [];
  }

  /// Check if onboarding is complete.
  Future<bool> isOnboardingComplete() async {
    final prefs = await _prefs;
    return prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  /// Mark onboarding as complete.
  Future<void> setOnboardingComplete() async {
    final prefs = await _prefs;
    await prefs.setBool(_onboardingCompleteKey, true);
  }

  /// Check if user is a guest.
  Future<bool> isGuest() async {
    final prefs = await _prefs;
    return prefs.getBool(_isGuestKey) ?? true;
  }

  /// Set guest status.
  Future<void> setGuest(bool isGuest) async {
    final prefs = await _prefs;
    await prefs.setBool(_isGuestKey, isGuest);
  }

  /// Whether the player chose "Play as guest" (skips the login screen).
  Future<bool> isGuestChosen() async {
    final prefs = await _prefs;
    return prefs.getBool(_guestChosenKey) ?? false;
  }

  Future<void> setGuestChosen(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_guestChosenKey, value);
  }

  /// Save a setting.
  Future<void> saveSetting(String key, dynamic value) async {
    final prefs = await _prefs;
    final settings = await loadSettings();
    settings[key] = value;
    await prefs.setString(_settingsKey, jsonEncode(settings));
  }

  /// Load all settings.
  Future<Map<String, dynamic>> loadSettings() async {
    try {
      final prefs = await _prefs;
      final json = prefs.getString(_settingsKey);
      if (json != null) {
        return jsonDecode(json) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
    return {};
  }
}
