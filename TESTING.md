# PixelPunch — Testing Documentation

## 1. Automated Test Suites
The project contains 26 automated unit and widget tests covering all critical components:

| Test File | Focus Area | Key Assertions |
|---|---|---|
| `test/unit/game_models_test.dart` | Data Models | JSON deserialization, round-trips, default stats, config constants |
| `test/unit/combat_calculations_test.dart` | Combat Engine | Defense reduction formula, shield 80% mitigation, invulnerability frames, knockout enforcement, healing cap |
| `test/unit/dialogue_system_test.dart` | Speech AI | Non-repeating dialogue selection, 8-second cooldown debouncing, forced lines (discovery/defeat), overlay callbacks |
| `test/unit/progression_test.dart` | Save & Leveling | XP curve calculation, multi-level jumps, villain discovery state machine, duplicate reward claim rejection |
| `test/unit/sync_service_test.dart` | Cloud Sync | Offline match queueing, duplicate prevention, unauthenticated safety |
| `test/widget_test.dart` | UI Smoke Test | Splash screen rendering, game title, and tagline verification |

---

## 2. Running Automated Tests

```bash
# Run all tests
flutter test

# Run a specific unit test suite
flutter test test/unit/combat_calculations_test.dart

# Run code analyzer
dart analyze lib
```
All 26 automated tests pass with 0 errors and 0 warnings.
