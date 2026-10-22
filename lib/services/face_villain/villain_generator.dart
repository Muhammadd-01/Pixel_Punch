import 'dart:math' as math;
import 'dart:ui';
import '../../game/models/custom_villain.dart';
import 'face_cartoonizer.dart';

/// Turns face measurements into a full villain: archetype, stats, title,
/// colours and dialogue.
class VillainGenerator {
  VillainGenerator._();

  static const archetypes = [
    'balanced',
    'tank',
    'speedster',
    'heavy_hitter',
    'support',
    'trickster',
  ];

  static const archetypeLabels = {
    'balanced': 'Balanced',
    'tank': 'Tank',
    'speedster': 'Speedster',
    'heavy_hitter': 'Heavy Hitter',
    'support': 'Support',
    'trickster': 'Trickster',
  };

  static const _villainPalette = [
    Color(0xFFE53935), // crimson
    Color(0xFF8E24AA), // purple
    Color(0xFF43A047), // toxic green
    Color(0xFFFB8C00), // hazard orange
    Color(0xFFD81B60), // magenta
    Color(0xFF00897B), // teal
    Color(0xFF3949AB), // indigo
  ];

  static const _titles = {
    'balanced': ['The Mirror Menace', 'The Copycat Commander', 'The Face Off'],
    'tank': ['The Unbreakable Wall', 'The Iron Jaw', 'The Immovable Boss'],
    'speedster': ['The Blink Bandit', 'The Turbo Terror', 'The Speed Bump'],
    'heavy_hitter': ['The Knuckle Crusher', 'The Wrecking Face', 'The Big Slam'],
    'support': ['The Smug Strategist', 'The Meeting Overlord', 'The Pep Talk Tyrant'],
    'trickster': ['The Grinning Glitch', 'The Prank Phantom', 'The Smirk Lord'],
  };

  static const _prefixes = ['Dr.', 'Captain', 'Evil', 'Lord', 'Mega', 'Baron'];

  /// Picks the archetype that best matches the face.
  static String inferArchetype(CartoonResult r) {
    if (!r.faceDetected) return archetypes[r.seed % archetypes.length];
    if ((r.smiling ?? 0) >= 0.7) return 'trickster';
    if (r.headTilt.abs() > 12) return 'trickster';
    if (r.eyesOpen != null && r.eyesOpen! < 0.35) return 'support';
    if (r.faceAspect >= 0.92) return 'tank';
    if (r.faceAspect < 0.74) return 'speedster';
    if (r.contrast > 0.6) return 'heavy_hitter';
    return 'balanced';
  }

  static String suggestName(String personName, int seed) {
    final clean = personName.trim();
    if (clean.isEmpty) return 'Mystery Face';
    return '${_prefixes[seed % _prefixes.length]} $clean';
  }

  static String suggestTitle(String archetype, int seed) {
    final list = _titles[archetype] ?? _titles['balanced']!;
    return list[seed % list.length];
  }

  static Color pickAccent(int skinArgb, int seed) {
    final skin = Color(skinArgb);
    // Prefer a palette colour that stands out against the skin tone.
    Color best = _villainPalette[seed % _villainPalette.length];
    double bestScore = -1;
    for (int i = 0; i < _villainPalette.length; i++) {
      final c = _villainPalette[(seed + i) % _villainPalette.length];
      final d = (c.r - skin.r).abs() + (c.g - skin.g).abs() + (c.b - skin.b).abs();
      // Small bias toward the seed's first pick for variety.
      final score = d - i * 0.05;
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return best;
  }

  static CustomVillain create({
    required String id,
    required CartoonResult face,
    required String name,
    required String title,
    required String archetype,
    required String zoneId,
    required String zoneName,
  }) {
    final traits = FaceTraits(
      skinTone: Color(face.skinTone),
      hairColor: Color(face.hairColor),
      accentColor: pickAccent(face.skinTone, face.seed),
      brightness: face.brightness,
      contrast: face.contrast,
      faceAspect: face.faceAspect,
      smiling: face.smiling,
      eyesOpen: face.eyesOpen,
      headTilt: face.headTilt,
      faceDetected: face.faceDetected,
      seed: face.seed,
      leftEye: Offset(face.leftEye[0], face.leftEye[1]),
      rightEye: Offset(face.rightEye[0], face.rightEye[1]),
    );
    final stats = statsFor(archetype, face.seed, face.contrast);
    return CustomVillain(
      id: id,
      name: name,
      title: title,
      biography: describe(face, archetype),
      archetype: archetype,
      zoneId: zoneId,
      portraitPng: face.png,
      facePhoto: face.photoJpg,
      traits: traits,
      baseHealth: stats.health,
      moveSpeed: stats.speed,
      attackDamage: stats.attack,
      attackRange: stats.range,
      attackCooldown: stats.cooldown,
      defense: stats.defense,
      dialogue: dialogueFor(name, title, archetype, zoneName),
      createdAt: DateTime.now(),
    );
  }

  /// Re-derives everything that depends on name/archetype/zone.
  static CustomVillain restyle(
    CustomVillain v, {
    required String name,
    required String title,
    required String archetype,
    required String zoneId,
    required String zoneName,
  }) {
    final stats = statsFor(archetype, v.traits.seed, v.traits.contrast);
    return v.copyWith(
      name: name,
      title: title,
      archetype: archetype,
      zoneId: zoneId,
      baseHealth: stats.health,
      moveSpeed: stats.speed,
      attackDamage: stats.attack,
      attackRange: stats.range,
      attackCooldown: stats.cooldown,
      defense: stats.defense,
      dialogue: dialogueFor(name, title, archetype, zoneName),
    );
  }

  static ({int health, double speed, int attack, double range, double cooldown, int defense})
      statsFor(String archetype, int seed, double contrast) {
    final rng = math.Random(seed);
    double vary(double v) => v * (0.92 + rng.nextDouble() * 0.16);
    final (h, s, a, r, c, d) = switch (archetype) {
      'tank' => (150, 85.0, 14, 45.0, 1.0, 22),
      'speedster' => (75, 220.0, 10, 40.0, 0.55, 5),
      'heavy_hitter' => (120, 95.0, 22, 50.0, 1.1, 14),
      'support' => (95, 120.0, 10, 45.0, 0.9, 10),
      'trickster' => (85, 170.0, 11, 42.0, 0.7, 6),
      _ => (100, 140.0, 16, 45.0, 0.8, 12),
    };
    return (
      health: vary(h.toDouble()).round(),
      speed: vary(s).roundToDouble(),
      attack: (vary(a.toDouble()) * (1 + contrast * 0.1)).round(),
      range: r,
      cooldown: c,
      defense: vary(d.toDouble()).round(),
    );
  }

  static String describe(CartoonResult r, String archetype) {
    final parts = <String>[];
    if (!r.faceDetected) {
      parts.add('A mysterious face scan');
    } else {
      final smile = r.smiling ?? 0;
      parts.add(smile > 0.7
          ? 'A suspiciously wide grin'
          : smile > 0.3
              ? 'A smug little smirk'
              : 'A dead-serious stare');
      parts.add(r.faceAspect >= 0.9
          ? 'a jaw built like a vault door'
          : r.faceAspect < 0.75
              ? 'a sharp, aerodynamic face'
              : 'perfectly villainous proportions');
    }
    final role = switch (archetype) {
      'tank' => 'shrugs off every punch',
      'speedster' => 'zips around faster than gossip',
      'heavy_hitter' => 'hits like a Monday morning',
      'support' => 'keeps the whole gang patched up',
      'trickster' => 'teleports out of trouble',
      _ => 'is good at a bit of everything',
    };
    return '${parts.join(' and ')}. Forged in the Villain Lab, this rival $role.';
  }

  static Map<String, List<String>> dialogueFor(
      String name, String title, String archetype, String zoneName) {
    final flavor = switch (archetype) {
      'tank' => [
          'Is that a punch or a gentle breeze?',
          'You will tire long before I do!',
        ],
      'speedster' => [
          'Too slow! Way too slow!',
          'Blink and you will miss me. Oh wait, you already did!',
        ],
      'heavy_hitter' => [
          'One good swing is all I need!',
          'Brace yourself, this one is going to sting!',
        ],
      'support' => [
          'My team never stays down for long!',
          'I have scheduled your defeat for right now.',
        ],
      'trickster' => [
          'Now you see me... now you do not!',
          'Was that me? Or my evil twin?',
        ],
      _ => [
          'I know every move you are about to make!',
          'Balance in all things... especially beating you!',
        ],
    };
    return {
      'discovery': [
        'So you found me! I am $name, $title!',
        'Welcome to my corner of $zoneName. Nobody leaves unpunched!',
        'You recognise this face? Good. Fear it.',
      ],
      'encounter_intro': [
        'Let us settle this, face to face!',
        '$name does not lose. Ever.',
      ],
      'combat_taunt': [
        'Is that all you have got?',
        'This face was made for winning!',
        ...flavor,
      ],
      'special_attack': [
        'Behold the power of $name!',
        'Signature move, coming right up!',
      ],
      'low_health': [
        'Wait, wait! Not the face!',
        'This was not in my evil plan...',
      ],
      'victory': [
        'Ha! Remember this face next time!',
      ],
      'defeat': [
        'I will be back... with a better selfie!',
        'Fine. You win this round.',
      ],
    };
  }
}
