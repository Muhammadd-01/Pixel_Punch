import 'dart:ui';
import '../models/dialogue_data.dart';

typedef ShowDialogueCallback = void Function(
  String villainId, String name, String title, String text, Color color);

/// Manages dialogue triggering, cooldowns, and state.
class DialogueManager {
  final Map<String, DialogueProfile> profiles;
  final ShowDialogueCallback? onShowDialogue;

  bool isShowingDialogue = false;
  double _globalCooldown = 0;

  DialogueManager({required this.profiles, this.onShowDialogue});

  void update(double dt) {
    if (_globalCooldown > 0) _globalCooldown -= dt;
  }

  bool triggerDialogue(
    String profileId,
    DialogueCategory category,
    String displayName,
    String displayTitle,
    Color color,
  ) {
    if (isShowingDialogue || _globalCooldown > 0) return false;

    final profile = profiles[profileId];
    if (profile == null) return false;

    String? line;
    if (category == DialogueCategory.discovery ||
        category == DialogueCategory.encounterIntro ||
        category == DialogueCategory.victory ||
        category == DialogueCategory.defeat) {
      line = profile.getLineForced(category);
    } else {
      line = profile.getLine(category);
    }
    if (line == null) return false;

    isShowingDialogue = true;
    _globalCooldown = 3.0;
    onShowDialogue?.call(profileId, displayName, displayTitle, line, color);
    return true;
  }

  void dismissDialogue() {
    isShowingDialogue = false;
  }
}
