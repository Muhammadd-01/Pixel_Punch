# PixelPunch — Gameplay Guide

## 1. Core Controls
PixelPunch is designed for landscape mobile play:

| Control | Action | Details |
|---|---|---|
| **Virtual Joystick** (Bottom Left) | Move Fighter | 360-degree analog control with normalized diagonal speed |
| **Attack Button** (Bottom Right) | Basic Attack | Swings weapon/punches closest enemy in range |
| **Special Button** (Bottom Right) | Special Ability | Activates unique hero archetype ability on cooldown |
| **Dodge Button** (Bottom Right) | Tactical Dodge | Fast dash forward with 0.3s invulnerability frames |
| **Pause Button** (Top Center) | Pause Menu | Halts simulation and displays options |

---

## 2. Combat Rules & Damage Mechanics
- **Damage Formula**:
  $$\text{Effective Damage} = \max(\max(1, \lfloor 0.35 \times \text{Raw Attack} \rfloor),\ \text{Raw Attack} - \text{Target Defense})$$
  Defense subtracts from each hit, but at least 35% of the raw attack always gets through, so armoured villains stay beatable.
- **Protective Shield**: When shielded, takes only 20% of incoming damage (80% mitigation).
- **Invulnerability Frames**: When hit, a fighter flashes for 0.15s and receives 0.5s of invulnerability to prevent unfair multi-hit stunlocks.
- **Knockback**: Hits push opponents away along the attack direction vector with exponential decay.
- **Defeat State**: A knocked-out fighter displays knockout eyes, ceases velocity, and cannot attack, heal, or trigger abilities.

---

## 3. Game Modes
1. **Solo (1v1)**:
   - 1 Player Hero vs 1 AI Villain.
   - Ideal for boss encounters, learning attack timings, and vertical exploration.
2. **Duo (2v2)**:
   - 1 Player + 1 AI Teammate vs 2 AI Villains.
   - Teammate AI coordinates target selection and uses support/tanking skills.
3. **Squad (3v3)**:
   - 1 Player + 2 AI Teammates vs 3 AI Villains.
   - Full team brawl with frontline tanks, damage dealers, and healers.

---

## 4. Special Abilities

| Archetype | Ability Name | Effect | Cooldown |
|---|---|---|---|
| **Balanced** | Charged Strike | Strikes for 2x damage with heavy knockback | 5.0s |
| **Tank** | Protective Shield | Creates energy shield absorbing 80% damage for 3s | 8.0s |
| **Speedster** | Rapid Dash | Bursts forward 120px damaging all enemies in path | 3.0s |
| **Heavy Hitter** | Ground Slam | Area earthquake hitting all enemies within 80px | 7.0s |
| **Support** | Team Recovery | Heals all nearby allies within 100px for 20 HP | 10.0s |
| **Trickster** | Evasive Burst | Teleports 80px forward with invulnerability | 4.0s |
