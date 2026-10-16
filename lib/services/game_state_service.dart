import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../game/models/fighter_data.dart';
import '../game/models/zone_data.dart';
import '../game/models/ability_data.dart';
import '../game/models/dialogue_data.dart';
import '../game/models/game_enums.dart';
import '../game/models/player_progress.dart';
import '../game/models/match_result.dart';

/// Central service managing game state, data loading, and progression.
class GameStateService extends ChangeNotifier {
  List<FighterData> _heroes = [];
  List<FighterData> _villains = [];
  List<ZoneData> _zones = [];
  List<AbilityData> _abilities = [];
  Map<String, DialogueProfile> _dialogueProfiles = {};
  final PlayerProgress _progress = PlayerProgress();
  final List<MatchResult> _matchHistory = [];
  GameMode _selectedMode = GameMode.solo;
  List<String> _selectedHeroIds = [];
  String _selectedZoneId = 'zone_office';
  bool _isLoaded = false;

  // Getters
  List<FighterData> get heroes => _heroes;
  List<FighterData> get villains => _villains;
  List<ZoneData> get zones => _zones;
  List<AbilityData> get abilities => _abilities;
  Map<String, DialogueProfile> get dialogueProfiles => _dialogueProfiles;
  PlayerProgress get progress => _progress;
  List<MatchResult> get matchHistory => _matchHistory;
  GameMode get selectedMode => _selectedMode;
  List<String> get selectedHeroIds => _selectedHeroIds;
  String get selectedZoneId => _selectedZoneId;
  bool get isLoaded => _isLoaded;

  FighterData? getHero(String id) {
    try {
      return _heroes.firstWhere((h) => h.id == id);
    } catch (_) {
      return null;
    }
  }

  FighterData? getVillain(String id) {
    try {
      return _villains.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  ZoneData? getZone(String id) {
    try {
      return _zones.firstWhere((z) => z.id == id);
    } catch (_) {
      return null;
    }
  }

  AbilityData? getAbility(String id) {
    try {
      return _abilities.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  DialogueProfile? getDialogueProfile(String villainId) {
    return _dialogueProfiles[villainId];
  }

  List<FighterData> getVillainsForZone(String zoneId) {
    return _villains.where((v) => v.zoneId == zoneId).toList();
  }

  List<FighterData> get unlockedHeroes {
    return _heroes.where((h) {
      return h.unlocked || _progress.unlockedCharacters.contains(h.id);
    }).toList();
  }

  /// Load all game data from bundled JSON assets.
  Future<void> loadGameData() async {
    if (_isLoaded) return;

    try {
      // Load heroes
      final heroesJson = await rootBundle.loadString('assets/data/characters/heroes.json');
      final herosList = jsonDecode(heroesJson) as List;
      _heroes = herosList.map((h) => FighterData.fromJson(h as Map<String, dynamic>)).toList();

      // Load villains
      final villainsJson = await rootBundle.loadString('assets/data/villains/villains.json');
      final villainsList = jsonDecode(villainsJson) as List;
      _villains = villainsList.map((v) => FighterData.fromJson(v as Map<String, dynamic>, isVillain: true)).toList();

      // Load zones
      final zonesJson = await rootBundle.loadString('assets/data/zones/zones.json');
      final zonesList = jsonDecode(zonesJson) as List;
      _zones = zonesList.map((z) => ZoneData.fromJson(z as Map<String, dynamic>)).toList();

      // Load abilities
      final abilitiesJson = await rootBundle.loadString('assets/data/abilities/abilities.json');
      final abilitiesList = jsonDecode(abilitiesJson) as List;
      _abilities = abilitiesList.map((a) => AbilityData.fromJson(a as Map<String, dynamic>)).toList();

      // Load dialogue
      final dialogueJson = await rootBundle.loadString('assets/data/dialogue/dialogue.json');
      final dialogueMap = jsonDecode(dialogueJson) as Map<String, dynamic>;
      _dialogueProfiles = dialogueMap.map(
        (key, value) => MapEntry(
          key,
          DialogueProfile.fromJson(key, value as Map<String, dynamic>),
        ),
      );

      // Set initial selected hero
      if (_selectedHeroIds.isEmpty && _heroes.isNotEmpty) {
        _selectedHeroIds = [_heroes.first.id];
      }

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading game data: $e');
    }
  }

  void setSelectedMode(GameMode mode) {
    _selectedMode = mode;
    // Adjust hero selection count
    while (_selectedHeroIds.length > mode.friendlyCount) {
      _selectedHeroIds.removeLast();
    }
    notifyListeners();
  }

  void setSelectedZone(String zoneId) {
    _selectedZoneId = zoneId;
    notifyListeners();
  }

  void toggleHeroSelection(String heroId) {
    if (_selectedHeroIds.contains(heroId)) {
      if (_selectedHeroIds.length > 1) {
        _selectedHeroIds.remove(heroId);
      }
    } else if (_selectedHeroIds.length < _selectedMode.friendlyCount) {
      _selectedHeroIds.add(heroId);
    }
    notifyListeners();
  }

  void setSelectedHeroes(List<String> heroIds) {
    _selectedHeroIds = heroIds;
    notifyListeners();
  }

  void recordMatchResult(MatchResult result) {
    _matchHistory.insert(0, result);
    _progress.recordMatch(result.outcome);
    _progress.addXp(result.xpEarned);
    notifyListeners();
  }

  void updateVillainDiscovery(String villainId, DiscoveryState state) {
    _progress.updateVillainState(villainId, state);
    notifyListeners();
  }
}
