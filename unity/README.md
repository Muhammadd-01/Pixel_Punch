# PixelPunch Royale 3D (Unity)

The 3D battle royale mode. Flutter keeps onboarding, login, menus, the Villain Lab
and the **3D Royale** lobby; this Unity project runs the match itself and is
embedded with [flutter_unity_widget](https://github.com/juicycleff/flutter-unity-view-widget).

Everything (map, buildings, characters, weapons, UI) is generated from code, so
there are no scenes or prefabs to build by hand.

## What's in the game

| Feature | Details |
|---|---|
| Huge procedural island | 1–2.4 km terrain with a mountain border, 4–12 towns of enterable 1–2 storey buildings (doors, windows, ramps to upper floors), trees, rocks, cover crates. Same seed = same map for everyone. |
| Skydive drop | Every player free-falls in, then glides down under a "parachute" and steers to a landing spot. |
| TPP / FPP | Over-the-shoulder 3rd person with wall collision, or first person at the eyes. Toggle with the **TPP/FPP** button or **V**. |
| Movement | Walk, sprint, **jump**, **crouch**, **prone** (crawl), with matching collision height so you can hide behind low cover. |
| Punching | 3-hit combo (jab → cross → hook), aim assist, lunge, impact-frame hit check, camera shake, heavy-hook shockwave. |
| Weapons | Pistol, SMG, rifle, shotgun (8 pellets), sniper (scoped zoom). Spread, damage falloff, headshots ×1.8, recoil, reloads, 2 weapon slots + fists. |
| Loot | Weapons, ammo (auto-pickup), medkits, body armor, spread through buildings and the wild. |
| Safe zone | 5 shrinking phases with rising damage, shown in the world, on the minimap and in the HUD. |
| Villains | Your roster from Flutter (built-in villains + Villain Lab faces). AI roams, sees/hears you (crouch & prone make you stealthier), chases, punches or shoots, strafes, taunts with speech bubbles, avoids the zone. |
| Real faces | Villain Lab villains get the person's actual face photo wrapped onto the front of a 3D head, feathered into their skin tone, with matching hair colour. |
| Online squads | Host gets a short squad code; up to 3 friends join with it (Unity Relay, works across networks). LAN mode for testing without an account. |
| Sound | Positional gunshots, punches, footsteps, landings, zone alarms and music, using the same WAVs as the Flutter app. |
| HUD | Health/armor, weapon & ammo, crosshair + hit markers, damage flash, minimap with zone rings and teammates, kill feed, alive counters. |

## 1. Install Unity

1. Open **Unity Hub** (already installed) → **Installs → Install Editor** → **Unity 6 LTS (6000.0.38 or newer)**.
2. Add modules: **Android Build Support** (with OpenJDK and Android SDK & NDK). Add **iOS Build Support** on a Mac.
3. Sign in to the Hub with a free Unity account (Personal licence).

## 2. Open and play in the editor

1. Hub → **Projects → Add → Add project from disk** → choose `unity/PixelPunch3D`.
2. Open it. Unity downloads the packages (Netcode, Multiplayer Services) and compiles.
3. **Setup runs automatically** the first time: it creates the network prefabs, the `Main` scene, build settings and player settings. You will see a "Setup complete" dialog. (Re-run any time: **PixelPunch → Setup Project**.)
4. Open `Assets/Scenes/Main.unity` and press **Play**. With no Flutter around, an offline test match starts.

Keyboard/mouse: click to capture the mouse, **WASD** move, **Shift** sprint, **Space** jump, **C** crouch,
**Z** prone, **left click** punch/fire, **right click** aim, **R** reload, **Q / 1 / 2 / wheel** switch weapon,
**F/E** pick up, **V** TPP/FPP, **Esc** release the mouse.

## 3. Turn on online squads (optional)

1. **Edit → Project Settings → Services** → link the project to a Unity Cloud project (create one, it is free).
2. In the [Unity Cloud dashboard](https://cloud.unity.com) enable **Relay** for that project.
3. That's it: "Host squad" in the app now creates a session and shows the **squad code**; friends choose
   "Join squad" and type it in.

## 4. Embed in the Flutter app

1. Download `fuw-6000.0.2.unitypackage` from
   [flutter-unity-view-widget/unitypackages](https://github.com/juicycleff/flutter-unity-view-widget/tree/master/unitypackages)
   and import it: **Assets → Import Package → Custom Package**.
2. In Unity: **Flutter → Export Android Release** (creates `android/unityLibrary`; on a Mac also **Export iOS**).
3. In the Flutter project:
   ```bash
   flutter pub add flutter_unity_widget_2
   ```
   (Use the `_2` fork: it supports Unity 6. The original `flutter_unity_widget` fails to compile with Unity 6.)
   Also add your machine's paths to `android/gradle.properties`:
   `unity.androidSdkPath=<Android SDK>` and `unity.androidNdkPath=<NDK 27.2.12479018>`
   (Unity ships this NDK in `Editor/Data/PlaybackEngines/AndroidPlayer/NDK`).
   Then follow the plugin's Android steps (add `include ":unityLibrary"` to `android/settings.gradle.kts` and the
   `unityLibrary` dependency/`flatDir` to `android/app/build.gradle.kts`). See its README, section *Android setup*.
4. Replace the placeholder launcher with the real one:
   ```bash
   cp unity/flutter_integration/royale_launcher.dart lib/features/royale/royale_launcher.dart
   ```
5. `flutter run` on a phone, go to **Home → 3D ROYALE → DROP IN**.

## How Flutter and Unity talk

Flutter → Unity (`GameBridge` object): `StartMatch(json)`, `SetView("tpp"|"fpp")`, `PauseGame`, `ResumeGame`, `QuitMatch`.
The JSON is built by `lib/features/royale/royale_config.dart` and parsed by `Scripts/Core/MatchConfig.cs`.

Unity → Flutter: `{"type": ..., "data": ...}` messages: `unity_ready`, `session_code`, `match_over`
(victory, kills, damage, seconds, villainsDefeated → recorded as XP in Flutter), `exit_requested`,
`match_closed`, `disconnected`, `error`.

## Code map (`Assets/PixelPunch/Scripts`)

| Folder | Files |
|---|---|
| `Core` | `GameBridge` (Flutter messages), `MatchConfig`, `MatchManager` (offline / host / join / LAN start-up) |
| `Net` | `NetworkRuntime` (NetworkManager at runtime), `SessionService` (Relay sessions), `MatchState` (seed, roster + faces, safe zone, win/lose), `Combatant` (health, pose sync, damage RPCs) |
| `World` | `WorldGenerator` (terrain, towns, nature, loot spots, minimap), `Mats` (materials + procedural textures) |
| `Characters` | `CharacterVisual` (3D humanoid + procedural animation), `FaceLibrary` (photo → head texture/mesh), `PlayerController`, `PlayerCamera` |
| `Combat` | `WeaponSystem` (punch combo + guns), `Weapons` (stats, loot table), `LootItem`, `Effects` |
| `AI` | `VillainNet` (villain setup + server-side brain) |
| `UI` | `TouchControls` (mobile + keyboard input), `HUD`, `Screens` (loading, results), `UIFactory` |
| `Editor` | `PixelPunchSetup` (one-click project setup) |

## Honest limits

- Characters are built from simple shapes, not rigged artist models. To use real models (e.g. Mixamo),
  replace the body built in `CharacterVisual.Build` while keeping the joint names. The procedural poses keep working.
- The face is a photo projected onto the front of the head. It is clearly the person from the front but
  softer from the sides. A fully accurate 3D head from one photo needs a dedicated 3D face-reconstruction model or service.
- Hit detection is client-reported with server sanity checks. That is fine for playing with friends; a public
  competitive game would need server-side hit validation.
- These scripts were compile-checked against Unity reference assemblies and API stand-ins for Netcode and
  Multiplayer Services. They have not yet been run inside the Unity editor, so expect a little tuning on the
  first run (speeds, camera offsets, AI difficulty).
