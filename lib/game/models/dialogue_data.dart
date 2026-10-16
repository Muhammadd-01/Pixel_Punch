import 'dart:math';

/// Categories of dialogue that can be triggered.
enum DialogueCategory {
  discovery,
  encounterIntro,
  combatTaunt,
  specialAttack,
  lowHealth,
  victory,
  defeat;

  String get jsonKey => switch (this) {
    DialogueCategory.discovery => 'discovery',
    DialogueCategory.encounterIntro => 'encounter_intro',
    DialogueCategory.combatTaunt => 'combat_taunt',
    DialogueCategory.specialAttack => 'special_attack',
    DialogueCategory.lowHealth => 'low_health',
    DialogueCategory.victory => 'victory',
    DialogueCategory.defeat => 'defeat',
  };
}

/// Represents a villain's dialogue profile.
class DialogueProfile {
  final String villainId;
  final Map<DialogueCategory, List<String>> lines;
  final Map<DialogueCategory, int> _lastUsedIndex = {};
  final Map<DialogueCategory, DateTime> _lastPlayedTime = {};
  final Random _random = Random();

  DialogueProfile({
    required this.villainId,
    required this.lines,
  });

  factory DialogueProfile.fromJson(String villainId, Map<String, dynamic> json) {
    final lines = <DialogueCategory, List<String>>{};
    for (final category in DialogueCategory.values) {
      final key = category.jsonKey;
      if (json.containsKey(key)) {
        lines[category] = (json[key] as List).cast<String>();
      }
    }
    return DialogueProfile(villainId: villainId, lines: lines);
  }

  /// Gets a dialogue line for the given category, avoiding recent repeats.
  String? getLine(DialogueCategory category, {double cooldownSeconds = 8.0}) {
    final categoryLines = lines[category];
    if (categoryLines == null || categoryLines.isEmpty) return null;

    // Check cooldown
    final lastPlayed = _lastPlayedTime[category];
    if (lastPlayed != null) {
      final elapsed = DateTime.now().difference(lastPlayed).inMilliseconds / 1000.0;
      if (elapsed < cooldownSeconds) return null;
    }

    // Pick a different line than last time
    final lastIndex = _lastUsedIndex[category] ?? -1;
    int newIndex;
    if (categoryLines.length == 1) {
      newIndex = 0;
    } else {
      do {
        newIndex = _random.nextInt(categoryLines.length);
      } while (newIndex == lastIndex);
    }

    _lastUsedIndex[category] = newIndex;
    _lastPlayedTime[category] = DateTime.now();
    return categoryLines[newIndex];
  }

  /// Gets a line ignoring cooldown (for forced dialogue like discovery).
  String? getLineForced(DialogueCategory category) {
    final categoryLines = lines[category];
    if (categoryLines == null || categoryLines.isEmpty) return null;

    final lastIndex = _lastUsedIndex[category] ?? -1;
    int newIndex;
    if (categoryLines.length == 1) {
      newIndex = 0;
    } else {
      do {
        newIndex = _random.nextInt(categoryLines.length);
      } while (newIndex == lastIndex);
    }

    _lastUsedIndex[category] = newIndex;
    _lastPlayedTime[category] = DateTime.now();
    return categoryLines[newIndex];
  }
}
