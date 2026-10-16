# PixelPunch

> *"Your Zone. Your Rivals. Your Victory."*

**PixelPunch** is an original, lightweight, cartoon-style 2D fighting, exploration, and team brawler game built with **Flutter**, **Flame**, and **Supabase**.

Explore corporate-themed cartoon districts, track down eccentric fictional workplace villains, engage in local AI combat, and build hero squads across **Solo (1v1)**, **Duo (2v2)**, and **Squad (3v3)** modes — all fully playable offline or synced to the cloud.

---

## 🎮 Core Features

- **2D Elevated Arena & Exploration**: Smooth top-down exploration with virtual joystick controls, boundary collisions, environmental obstacles, and dynamic camera tracking.
- **Fictional Company Villains**: Encounter fictional villains inspired by workplace humor (The Bug Phantom, Captain Deadline, Firewall Guardian, Lag Lord, Dark Designer, and Chaos Manager).
- **Living Dialogue System**: Contextual on-screen dialogue with typewriter animations, portrait popups, reaction taunts, low-health lines, and discovery announcements.
- **Dynamic Combat Mechanics**: Real-time hitboxes, attack ranges, cooldown meters, defense calculation, knockback impulse, temporary invulnerability, and dodge mechanics.
- **6 Playable Hero Archetypes**:
  - **Striker** (Balanced Fighter — Charged Strike)
  - **Bulwark** (Tank — Protective Shield)
  - **Flash** (Speedster — Rapid Dash)
  - **Hammer** (Heavy Hitter — Ground Slam)
  - **Mend** (Support — Team Recovery)
  - **Phantom** (Trickster — Evasive Burst)
- **3 Game Modes**:
  - **Solo (1v1)**: Player vs AI villain
  - **Duo (2v2)**: Player + AI Teammate vs 2 AI Villains
  - **Squad (3v3)**: Player + 2 AI Teammates vs 3 AI Villains
- **3 Playable Zones**:
  - **Zone 1: NexoVate Office District** (Reception, Open Office, Meeting Room, Server Room)
  - **Zone 2: Neon Battle District** (Training Arenas, Speed Tracks, Glowing Platforms)
  - **Zone 3: Pixel Rooftop** (Skyline Platforms, Ventilation Ducts, Boss Arena)
- **Progression & Unlocks**: Local XP tracking, leveling curve, villain discovery state machines, defeat records, and match history.
- **Offline-First & Guest Mode**: Play immediately without registration.
- **Optional Supabase Cloud Sync**: Link an email/password account to sync career stats, unlock progress, and match history across devices.

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK `^3.35.0` / Dart `^3.9.0`
- Android Studio / Xcode for device emulators or physical deployment

### Installation

```bash
# Clone the repository
git clone https://github.com/your-username/pixel_punch.git
cd pixel_punch

# Install dependencies
flutter pub get

# Run analyzer
dart analyze lib

# Run automated tests
flutter test

# Run game on connected device or emulator (Landscape recommended)
flutter run
```

---

## 📂 Project Architecture

```
lib/
├── app/                  # App theme, router configuration, entry points
├── core/
│   └── config/           # GameConfig, SupabaseConfig
├── data/                 # Bundled static configurations
├── features/
│   ├── auth/             # Login, Register, Forgot Password
│   ├── characters/       # Hero selection & team formation
│   ├── game/             # Game screen, virtual joystick, dialogue, HUD
│   ├── home/             # Main menu, level & career summary
│   ├── onboarding/       # 3-page interactive onboarding tutorial
│   ├── profile/          # Career stats, win/loss records, cloud status
│   ├── settings/         # Audio sliders, controls, reduced motion
│   ├── splash/           # Branded logo reveal & async initialization
│   └── zones/            # Zone selection carousel, preview & stats
├── game/
│   ├── ai/               # Finite-state machine AI (approach, attack, retreat)
│   ├── combat/           # Combat manager, taunt timers, damage resolution
│   ├── components/       # Flame components (Player, Villain, Zone, FighterBase)
│   ├── dialogue/         # Dialogue manager, cooldown pools
│   ├── models/           # FighterData, ZoneData, AbilityData, DialogueProfile
│   └── pixel_punch_game.dart # Main Flame game loop
└── services/
    ├── audio_service.dart          # Audio controls and SFX/BGM fallbacks
    ├── game_state_service.dart     # Central data loader & progression provider
    ├── local_storage_service.dart  # Offline persistence (SharedPreferences)
    ├── supabase_service.dart       # Supabase Auth & PostgreSQL client
    └── sync_service.dart           # Offline-first conflict reconciliation
```

---

## ☁️ Supabase Cloud Setup

See [`SUPABASE_SETUP.md`](SUPABASE_SETUP.md) and [`DATABASE_SCHEMA.md`](DATABASE_SCHEMA.md) for full instructions on applying migrations and Row-Level Security (RLS) policies.
