# PixelPunch — Dialogue System

## 1. Overview
Villains in PixelPunch visibly speak to the player without requiring external AI APIs or network connections. All dialogue is driven by local deterministic profiles bundled in `assets/data/dialogue/dialogue.json`.

---

## 2. Dialogue Categories
Dialogue triggers dynamically based on game simulation events:

| Category | Trigger Condition | Cooldown Behavior |
|---|---|---|
| **`discovery`** | Player walks within 80px radius of a villain during exploration | Forced (ignores cooldown) |
| **`encounter_intro`** | Combat starts between player and villain | Forced (ignores cooldown) |
| **`combat_taunt`** | Random timer during combat while villain is above 30% HP | 8.0s cooldown per villain |
| **`special_attack`** | Villain activates archetype ability | 5.0s cooldown |
| **`low_health`** | Villain health drops below 30% | Prioritized over regular taunt |
| **`victory`** | Villain knocks out all friendly heroes | Forced on match end |
| **`defeat`** | Villain is knocked out | Forced on match end |

---

## 3. Repetition Avoidance Algorithm
`DialogueProfile.getLine()` implements non-repeating line selection:
1. It maintains `_lastUsedIndex` for each category.
2. When picking a line from an array of $N > 1$ lines, it generates random indices until `newIndex != lastIndex`.
3. It stamps `_lastPlayedTime` and enforces an 8-second debounce window so taunts do not flood the screen.

---

## 4. On-Screen Overlay Features
- **Typewriter Effect**: 25ms per character text rendering.
- **Quick Skip**: Tapping anywhere while the line is typing immediately reveals full text.
- **Dismiss**: Tapping when the line is complete dismisses the speech box and resumes action.
- **Portrait Initial & Color Styling**: Distinct border glow matching the villain's unique archetype color palette.
