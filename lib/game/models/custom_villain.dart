import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'dialogue_data.dart';
import 'fighter_data.dart';

/// Facial traits measured from the source photo. They drive the villain's
/// archetype, stats and colour scheme.
class FaceTraits {
  final Color skinTone;
  final Color hairColor;
  final Color accentColor;
  final double brightness; // 0..1
  final double contrast; // 0..1
  final double faceAspect; // width / height of the detected face
  final double? smiling; // 0..1, null when unknown
  final double? eyesOpen; // 0..1, null when unknown
  final double headTilt; // degrees
  final bool faceDetected;
  final int seed;

  // Eye positions relative to the portrait (0..1), used to draw villain
  // brows and glowing eyes on top of the cartoon face.
  final Offset leftEye;
  final Offset rightEye;

  const FaceTraits({
    required this.skinTone,
    required this.hairColor,
    required this.accentColor,
    required this.brightness,
    required this.contrast,
    required this.faceAspect,
    required this.smiling,
    required this.eyesOpen,
    required this.headTilt,
    required this.faceDetected,
    required this.seed,
    required this.leftEye,
    required this.rightEye,
  });

  Map<String, dynamic> toJson() => {
        'skinTone': skinTone.toARGB32(),
        'hairColor': hairColor.toARGB32(),
        'accentColor': accentColor.toARGB32(),
        'brightness': brightness,
        'contrast': contrast,
        'faceAspect': faceAspect,
        'smiling': smiling,
        'eyesOpen': eyesOpen,
        'headTilt': headTilt,
        'faceDetected': faceDetected,
        'seed': seed,
        'leftEye': [leftEye.dx, leftEye.dy],
        'rightEye': [rightEye.dx, rightEye.dy],
      };

  factory FaceTraits.fromJson(Map<String, dynamic> json) {
    Offset off(Object? v, Offset fallback) {
      if (v is List && v.length == 2) {
        return Offset((v[0] as num).toDouble(), (v[1] as num).toDouble());
      }
      return fallback;
    }

    return FaceTraits(
      skinTone: Color(json['skinTone'] as int),
      hairColor: Color(json['hairColor'] as int),
      accentColor: Color(json['accentColor'] as int),
      brightness: (json['brightness'] as num).toDouble(),
      contrast: (json['contrast'] as num).toDouble(),
      faceAspect: (json['faceAspect'] as num).toDouble(),
      smiling: (json['smiling'] as num?)?.toDouble(),
      eyesOpen: (json['eyesOpen'] as num?)?.toDouble(),
      headTilt: (json['headTilt'] as num?)?.toDouble() ?? 0,
      faceDetected: json['faceDetected'] as bool? ?? false,
      seed: json['seed'] as int? ?? 0,
      leftEye: off(json['leftEye'], const Offset(0.36, 0.45)),
      rightEye: off(json['rightEye'], const Offset(0.64, 0.45)),
    );
  }
}

/// A villain generated from a real face photo.
class CustomVillain {
  final String id;
  final String name;
  final String title;
  final String biography;
  final String archetype;
  final String zoneId;
  final Uint8List portraitPng;
  final FaceTraits traits;
  final int baseHealth;
  final double moveSpeed;
  final int attackDamage;
  final double attackRange;
  final double attackCooldown;
  final int defense;
  final Map<String, List<String>> dialogue;
  final DateTime createdAt;

  const CustomVillain({
    required this.id,
    required this.name,
    required this.title,
    required this.biography,
    required this.archetype,
    required this.zoneId,
    required this.portraitPng,
    required this.traits,
    required this.baseHealth,
    required this.moveSpeed,
    required this.attackDamage,
    required this.attackRange,
    required this.attackCooldown,
    required this.defense,
    required this.dialogue,
    required this.createdAt,
  });

  static const Map<String, String> _abilityForArchetype = {
    'balanced': 'charged_strike',
    'tank': 'protective_shield',
    'speedster': 'rapid_dash',
    'heavy_hitter': 'ground_slam',
    'support': 'team_recovery',
    'trickster': 'evasive_burst',
  };

  String get specialAbility =>
      _abilityForArchetype[archetype] ?? 'charged_strike';

  /// Converts into the shared fighter model used by the game engine.
  FighterData toFighterData({double? spawnX, double? spawnY}) => FighterData(
        id: id,
        name: name,
        title: title,
        biography: biography,
        archetype: archetype,
        baseHealth: baseHealth,
        moveSpeed: moveSpeed,
        attackDamage: attackDamage,
        attackRange: attackRange,
        attackCooldown: attackCooldown,
        defense: defense,
        specialAbility: specialAbility,
        specialCooldown: 6.0,
        color: traits.accentColor,
        isVillain: true,
        zoneId: zoneId,
        difficultyTier: 2,
        spawnX: spawnX,
        spawnY: spawnY,
        patrolRadius: 110,
        discoveryType: 'area_enter',
        dialogueProfileId: id,
      );

  DialogueProfile toDialogueProfile() => DialogueProfile.fromJson(id, dialogue);

  CustomVillain copyWith({
    String? name,
    String? title,
    String? archetype,
    String? zoneId,
    Map<String, List<String>>? dialogue,
    String? biography,
    int? baseHealth,
    double? moveSpeed,
    int? attackDamage,
    double? attackRange,
    double? attackCooldown,
    int? defense,
  }) =>
      CustomVillain(
        id: id,
        name: name ?? this.name,
        title: title ?? this.title,
        biography: biography ?? this.biography,
        archetype: archetype ?? this.archetype,
        zoneId: zoneId ?? this.zoneId,
        portraitPng: portraitPng,
        traits: traits,
        baseHealth: baseHealth ?? this.baseHealth,
        moveSpeed: moveSpeed ?? this.moveSpeed,
        attackDamage: attackDamage ?? this.attackDamage,
        attackRange: attackRange ?? this.attackRange,
        attackCooldown: attackCooldown ?? this.attackCooldown,
        defense: defense ?? this.defense,
        dialogue: dialogue ?? this.dialogue,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'title': title,
        'biography': biography,
        'archetype': archetype,
        'zoneId': zoneId,
        'portraitPng': base64Encode(portraitPng),
        'traits': traits.toJson(),
        'baseHealth': baseHealth,
        'moveSpeed': moveSpeed,
        'attackDamage': attackDamage,
        'attackRange': attackRange,
        'attackCooldown': attackCooldown,
        'defense': defense,
        'dialogue': dialogue,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CustomVillain.fromJson(Map<String, dynamic> json) => CustomVillain(
        id: json['id'] as String,
        name: json['name'] as String,
        title: json['title'] as String,
        biography: json['biography'] as String? ?? '',
        archetype: json['archetype'] as String,
        zoneId: json['zoneId'] as String,
        portraitPng: base64Decode(json['portraitPng'] as String),
        traits: FaceTraits.fromJson(json['traits'] as Map<String, dynamic>),
        baseHealth: json['baseHealth'] as int,
        moveSpeed: (json['moveSpeed'] as num).toDouble(),
        attackDamage: json['attackDamage'] as int,
        attackRange: (json['attackRange'] as num).toDouble(),
        attackCooldown: (json['attackCooldown'] as num).toDouble(),
        defense: json['defense'] as int,
        dialogue: (json['dialogue'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, (v as List).cast<String>()),
        ),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
