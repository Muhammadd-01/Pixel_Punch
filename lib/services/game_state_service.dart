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
import '../core/config/game_config.dart';
import 'local_storage_service.dart';

/// What a finished match unlocked, shown on the results screen.
class MatchRewards {
  final int xpEarned;
  final bool leveledUp;
  final int level;
  final List<String> unlockedZones;
  final List<String> unlockedHeroes;

  const MatchRewards({
    required this.xpEarned,
    required this.leveledUp,
    required this.level,
    this.unlockedZones = const [],
    this.unlockedHeroes = const [],
  });
}

/// Central service managing game state, data loading, and progression.
class GameStateService extends ChangeNotifier {
  List<FighterData> _heroes = [];
  List<FighterData> _villains = [];
  List<ZoneData> _zones = [];
  List<AbilityData> _abilities = [];
  Map<String, DialogueProfile> _dialogueProfiles = {};
  PlayerProgress _progress = PlayerProgress();
  final List<MatchResult> _matchHistory = [];
  LocalStorageService? _storage;
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
    for (final h in _heroes) {
      if (h.id == id) return h;
    }
    return null;
  }

  FighterData? getVillain(String id) {
    for (final v in _villains) {
      if (v.id == id) return v;
    }
    return null;
  }

  ZoneData? getZone(String id) {
    for (final z in _zones) {
      if (z.id == id) return z;
    }
    return null;
  }

  AbilityData? getAbility(String id) {
    for (final a in _abilities) {
      if (a.id == id) return a;
    }
    return null;
  }

  DialogueProfile? getDialogueProfile(String villainId) {
    return _dialogueProfiles[villainId];
  }

  List<FighterData> getVillainsForZone(String zoneId) {
    return _villains.where((v) => v.zoneId == zoneId).toList();
  }

  List<FighterData> get unlockedHeroes =>
      _heroes.where(isHeroUnlocked).toList();

  bool isHeroUnlocked(FighterData hero) =>
      hero.unlocked || _progress.unlockedCharacters.contains(hero.id);

  bool isZoneUnlocked(ZoneData zone) =>
      zone.unlocked || (_progress.unlockedZones[zone.id] ?? false);

  bool isZoneCompleted(String zoneId) {
    final zone = getZone(zoneId);
    if (zone == null || zone.villainIds.isEmpty) return false;
    return zone.villainIds.every(_progress.isVillainDefeated);
  }

  int get defeatedVillainCount =>
      _villains.where((v) => _progress.isVillainDefeated(v.id)).length;

  /// Load all game data from bundled JSON assets.
  Future<void> loadGameData() async {
    if (_isLoaded) return;

    try {
      final heroesJson =
          await rootBundle.loadString('assets/data/characters/heroes.json');
      _heroes = (jsonDecode(heroesJson) as List)
          .map((h) => FighterData.fromJson(h as Map<String, dynamic>))
          .toList();

      final villainsJson =
          await rootBundle.loadString('assets/data/villains/villains.json');
      _villains = (jsonDecode(villainsJson) as List)
          .map((v) => FighterData.fromJson(v as Map<String, dynamic>,
              isVillain: true))
          .toList();

      final zonesJson =
          await rootBundle.loadString('assets/data/zones/zones.json');
      _zones = (jsonDecode(zonesJson) as List)
          .map((z) => ZoneData.fromJson(z as Map<String, dynamic>))
          .toList();

      final abilitiesJson =
          await rootBundle.loadString('assets/data/abilities/abilities.json');
      _abilities = (jsonDecode(abilitiesJson) as List)
          .map((a) => AbilityData.fromJson(a as Map<String, dynamic>))
          .toList();

      final dialogueJson =
          await rootBundle.loadString('assets/data/dialogue/dialogue.json');
      final dialogueMap = jsonDecode(dialogueJson) as Map<String, dynamic>;
      _dialogueProfiles = dialogueMap.map(
        (key, value) => MapEntry(
          key,
          DialogueProfile.fromJson(key, value as Map<String, dynamic>),
        ),
      );

      if (_selectedHeroIds.isEmpty && _heroes.isNotEmpty) {
        _selectedHeroIds = [_heroes.first.id];
      }

      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading game data: $e');
    }
  }

  /// Loads saved progress and match history from the device.
  Future<void> loadSavedData(LocalStorageService storage) async {
    _storage = storage;
    _progress = await storage.loadProgress();
    final history = await storage.loadMatchHistory();
    _matchHistory
      ..clear()
      ..addAll(history);
    _applyUnlocks();
    _sanitizeSelection();
    notifyListeners();
  }

  Future<void> _persist() async {
    final storage = _storage;
    if (storage == null) return;
    try {
      await storage.saveProgress(_progress);
      await storage.saveMatchHistory(_matchHistory.take(50).toList());
    } catch (e) {
      debugPrint('Error saving progress: $e');
    }
  }

  void _sanitizeSelection() {
    _selectedHeroIds.removeWhere((id) {
      final hero = getHero(id);
      return hero == null || !isHeroUnlocked(hero);
    });
    if (_selectedHeroIds.isEmpty && unlockedHeroes.isNotEmpty) {
      _selectedHeroIds = [unlockedHeroes.first.id];
    }
    final zone = getZone(_selectedZoneId);
    if (zone == null || !isZoneUnlocked(zone)) _selectedZoneId = 'zone_office';
  }

  /// Unlocks zones and heroes whose requirements are now met.
  ({List<String> zones, List<String> heroes}) _applyUnlocks() {
    final newZones = <String>[];
    final newHeroes = <String>[];

    // Each zone unlocks when the previous one is completed.
    for (int i = 1; i < _zones.length; i++) {
      final zone = _zones[i];
      if (isZoneUnlocked(zone)) continue;
      if (isZoneCompleted(_zones[i - 1].id)) {
        _progress.unlockedZones[zone.id] = true;
        newZones.add(zone.name);
      }
    }

    for (final hero in _heroes) {
      if (isHeroUnlocked(hero)) continue;
      if (requirementMet(hero.unlockRequirement)) {
        _progress.unlockedCharacters.add(hero.id);
        newHeroes.add(hero.name);
      }
    }
    return (zones: newZones, heroes: newHeroes);
  }

  /// Understands requirements like "Defeat 3 villains", "Complete Zone 1"
  /// and "Defeat Bug Phantom".
  bool requirementMet(String? requirement) {
    if (requirement == null || requirement.trim().isEmpty) return true;
    final text = requirement.trim();
    final countMatch = RegExp(r'^defeat\s+(\d+)\s+villains?$', caseSensitive: false)
        .firstMatch(text);
    if (countMatch != null) {
      return defeatedVillainCount >= int.parse(countMatch.group(1)!);
    }
    final zoneMatch = RegExp(r'^complete\s+zone\s+(\d+)$', caseSensitive: false)
        .firstMatch(text);
    if (zoneMatch != null) {
      final index = int.parse(zoneMatch.group(1)!) - 1;
      return index >= 0 &&
          index < _zones.length &&
          isZoneCompleted(_zones[index].id);
    }
    final nameMatch =
        RegExp(r'^defeat\s+(.+)$', caseSensitive: false).firstMatch(text);
    if (nameMatch != null) {
      final name = nameMatch.group(1)!.toLowerCase();
      return _villains.any((v) =>
          v.name.toLowerCase() == name && _progress.isVillainDefeated(v.id));
    }
    return false;
  }

  /// Picks the villains for a match: requested ones first, then undefeated
  /// zone villains, then face-generated villains, then the rest. Villains
  /// repeat when the mode needs more fighters than the zone has.
  List<FighterData> villainsForMatch(
    String zoneId,
    GameMode mode, {
    List<FighterData> customVillains = const [],
    List<String> featuredIds = const [],
  }) {
    final zoneVillains = getVillainsForZone(zoneId);
    final all = [...zoneVillains, ...customVillains];
    final pool = <FighterData>[
      ...all.where((v) => featuredIds.contains(v.id)),
      ...zoneVillains.where((v) =>
          !featuredIds.contains(v.id) && !_progress.isVillainDefeated(v.id)),
      ...customVillains.where((v) => !featuredIds.contains(v.id)),
      ...zoneVillains.where((v) =>
          !featuredIds.contains(v.id) && _progress.isVillainDefeated(v.id)),
    ];
    if (pool.isEmpty) return [];
    return [for (int i = 0; i < mode.enemyCount; i++) pool[i % pool.length]];
  }

  static int xpFor(MatchOutcome outcome, int villainsDefeated) =>
      outcome == MatchOutcome.victory
          ? GameConfig.xpPerMissionComplete +
              villainsDefeated * GameConfig.xpPerVillainDefeat
          : 10 + villainsDefeated * 20;

  /// Records a finished match, updates discovery/defeat state, XP and
  /// unlocks, saves everything and reports what changed.
  MatchRewards applyMatchResult(
    MatchResult result, {
    Iterable<String> discoveredIds = const [],
    Iterable<String> defeatedIds = const [],
  }) {
    final levelBefore = _progress.playerLevel;
    for (final id in discoveredIds) {
      _progress.updateVillainState(id, DiscoveryState.located);
    }
    for (final id in defeatedIds) {
      _progress.updateVillainState(id, DiscoveryState.defeated);
    }
    _matchHistory.insert(0, result);
    _progress.recordMatch(result.outcome);
    _progress.addXp(result.xpEarned);
    final unlocks = _applyUnlocks();
    notifyListeners();
    _persist();
    return MatchRewards(
      xpEarned: result.xpEarned,
      leveledUp: _progress.playerLevel > levelBefore,
      level: _progress.playerLevel,
      unlockedZones: unlocks.zones,
      unlockedHeroes: unlocks.heroes,
    );
  }

  void setSelectedMode(GameMode mode) {
    _selectedMode = mode;
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
    final hero = getHero(heroId);
    if (hero == null || !isHeroUnlocked(hero)) return;
    if (_selectedMode.friendlyCount == 1) {
      _selectedHeroIds = [heroId];
      notifyListeners();
      return;
    }
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
    applyMatchResult(result);
  }

  void updateVillainDiscovery(String villainId, DiscoveryState state) {
    _progress.updateVillainState(villainId, state);
    notifyListeners();
    _persist();
  }

  /// Replaces local progress (used after a cloud sync merge).
  void replaceProgress(PlayerProgress progress) {
    _progress = progress;
    _applyUnlocks();
    notifyListeners();
    _persist();
  }
}
