# PixelPunch — System Architecture

## 1. Overview
PixelPunch is built using a clean architectural separation between:
1. **Simulation Layer (Flame Game Engine)**: 2D physics, character positioning, hitboxes, collision detection, camera following, local AI state machines.
2. **Presentation Layer (Flutter Overlays)**: Responsive menus, HUD, virtual joystick, dialogue overlays, game-over summaries.
3. **Domain Layer**: Typed models (`FighterData`, `ZoneData`, `AbilityData`, `DialogueProfile`, `MatchResult`, `PlayerProgress`).
4. **Data & Synchronization Layer**: Local storage (`SharedPreferences`) with an asynchronous queue for cloud persistence (`Supabase PostgreSQL`).

---

## 2. Component Diagram

```
+-------------------------------------------------------------+
|                     FLUTTER UI LAYER                        |
|                                                             |
|  SplashScreen    HomeScreen     ZoneSelection   HeroSelection|
|  LoginScreen     RegisterScreen ProfileScreen   Settings     |
|                                                             |
|  +-------------------------------------------------------+  |
|  |                 GAME SCREEN OVERLAYS                  |  |
|  |  [GameHud]  [DialogueOverlay]  [Pause]  [GameOver]   |  |
|  +-------------------------------------------------------+  |
+-------------------------------------------------------------+
                              |
                     Input & Callbacks
                              v
+-------------------------------------------------------------+
|                  FLAME SIMULATION ENGINE                    |
|                                                             |
|  PixelPunchGame (HasCollisionDetection)                     |
|  ├── ZoneComponent (Renders obstacles, floor tiles, bounds) |
|  ├── PlayerComponent (FighterBase)                          |
|  ├── TeammateComponents (AIController)                      |
|  ├── VillainComponents (AIController + DialogueProfile)    |
|  ├── CombatManager (Periodic combat events, taunts)        |
|  └── DialogueManager (Contextual speech broker)             |
+-------------------------------------------------------------+
                              |
                     State & Events
                              v
+-------------------------------------------------------------+
|                    SERVICES & PERSISTENCE                   |
|                                                             |
|  GameStateService (ChangeNotifier - In-Memory State)        |
|  LocalStorageService (Offline JSON / SharedPreferences)    |
|  SyncService (Queue, Deduplication, Cloud Reconciliation)   |
|  SupabaseService (PostgreSQL Client & Auth)                 |
+-------------------------------------------------------------+
```

---

## 3. Finite-State Machine (FSM) AI
Both AI-controlled villains and friendly AI teammates operate on a deterministic Finite-State Machine that evaluates every `GameConfig.aiDecisionInterval` (0.3 seconds):

- **IDLE**: Resting at position or waiting for targets.
- **PATROL**: Circling around their configured spawn coordinates in a zone.
- **APPROACH**: Moving toward the closest living enemy within `aiApproachDistance`.
- **ATTACK**: Executing an attack when target is within `attackRange`.
- **USE_SPECIAL**: Activating archetype ability (dash, shield, heal, slam) when cooldown is ready.
- **RETREAT**: Repositioning away when health drops below 30% (`aiRetreatHealthPercent`).
- **FOLLOW**: Teammates following player while maintaining tactical distance.
- **KNOCKED_OUT**: Ceasing all physics, movement, and abilities upon defeat.

---

## 4. Offline-First Reconciliation Pattern
1. Every battle, unlock, and XP gain is immediately persisted to `LocalStorageService`.
2. Matches are queued with a unique UUID (`matchId`).
3. When online, `SyncService` verifies the active Supabase session.
4. Conflicting XP/Levels reconcile deterministically by taking `max(localLevel, cloudLevel)` and `max(localWins, cloudWins)`.
5. Queued matches are submitted idempotently.
