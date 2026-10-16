# PixelPunch — Assets & Licensing

## 1. Asset Strategy
PixelPunch uses a lightweight procedural and vector styling paradigm built directly on Flutter Canvas and Flame component rendering:
- **Procedural Characters**: Chibi/cartoon style geometric rendering with dynamic eyes, hit flashes, invulnerability animations, direction facing, and custom color accents.
- **Procedural Environments**: Tiled flooring, styled obstacles (desks, server racks, holographic platforms, vents), and zone boundary rendering.
- **Visual Effects**: Built-in canvas arcs, glow circles, and particle approximations.

---

## 2. Bundled Configuration Assets
All static configurations are bundled in JSON inside `assets/data/`:
- `assets/data/characters/heroes.json`: 6 playable heroes with stats, abilities, and unlock rules.
- `assets/data/villains/villains.json`: 6 fictional villains with spawn points and difficulty tiers.
- `assets/data/zones/zones.json`: 3 explorable zone layouts with coordinates and obstacles.
- `assets/data/dialogue/dialogue.json`: Comprehensive dialogue lines for all villains.
- `assets/data/abilities/abilities.json`: Ability definitions and multipliers.

---

## 3. Fonts & Licensing
- **Google Fonts (Poppins, Press Start 2P)**: Open Font License (OFL).
- **Material Icons / Cupertino Icons**: Apache 2.0 / MIT.
- **Audio Service**: Designed with silent fallback and zero mandatory external proprietary audio assets.
