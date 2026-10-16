import 'dart:ui';

/// Represents the static data definition of a fighter (hero or villain).
class FighterData {
  final String id;
  final String name;
  final String title;
  final String biography;
  final String archetype;
  final int baseHealth;
  final double moveSpeed;
  final int attackDamage;
  final double attackRange;
  final double attackCooldown;
  final int defense;
  final String specialAbility;
  final double specialCooldown;
  final Color color;
  final bool isVillain;

  // Villain-specific
  final String? zoneId;
  final int? difficultyTier;
  final double? spawnX;
  final double? spawnY;
  final double? patrolRadius;
  final String? discoveryType;
  final String? dialogueProfileId;

  // Hero-specific
  final bool unlocked;
  final String? unlockRequirement;

  const FighterData({
    required this.id,
    required this.name,
    required this.title,
    required this.biography,
    required this.archetype,
    required this.baseHealth,
    required this.moveSpeed,
    required this.attackDamage,
    required this.attackRange,
    required this.attackCooldown,
    required this.defense,
    required this.specialAbility,
    required this.specialCooldown,
    required this.color,
    this.isVillain = false,
    this.zoneId,
    this.difficultyTier,
    this.spawnX,
    this.spawnY,
    this.patrolRadius,
    this.discoveryType,
    this.dialogueProfileId,
    this.unlocked = true,
    this.unlockRequirement,
  });

  factory FighterData.fromJson(Map<String, dynamic> json, {bool isVillain = false}) {
    return FighterData(
      id: json['id'] as String,
      name: json['name'] as String,
      title: json['title'] as String,
      biography: json['biography'] as String,
      archetype: json['archetype'] as String,
      baseHealth: json['baseHealth'] as int,
      moveSpeed: (json['moveSpeed'] as num).toDouble(),
      attackDamage: json['attackDamage'] as int,
      attackRange: (json['attackRange'] as num).toDouble(),
      attackCooldown: (json['attackCooldown'] as num).toDouble(),
      defense: json['defense'] as int,
      specialAbility: json['specialAbility'] as String,
      specialCooldown: (json['specialCooldown'] as num).toDouble(),
      color: Color(int.parse(json['color'] as String)),
      isVillain: isVillain,
      zoneId: json['zoneId'] as String?,
      difficultyTier: json['difficultyTier'] as int?,
      spawnX: (json['spawnX'] as num?)?.toDouble(),
      spawnY: (json['spawnY'] as num?)?.toDouble(),
      patrolRadius: (json['patrolRadius'] as num?)?.toDouble(),
      discoveryType: json['discoveryType'] as String?,
      dialogueProfileId: json['dialogueProfileId'] as String?,
      unlocked: json['unlocked'] as bool? ?? true,
      unlockRequirement: json['unlockRequirement'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'title': title,
    'biography': biography,
    'archetype': archetype,
    'baseHealth': baseHealth,
    'moveSpeed': moveSpeed,
    'attackDamage': attackDamage,
    'attackRange': attackRange,
    'attackCooldown': attackCooldown,
    'defense': defense,
    'specialAbility': specialAbility,
    'specialCooldown': specialCooldown,
    'color': '0x${color.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0')}',
    if (isVillain) ...{
      'zoneId': zoneId,
      'difficultyTier': difficultyTier,
      'spawnX': spawnX,
      'spawnY': spawnY,
      'patrolRadius': patrolRadius,
      'discoveryType': discoveryType,
      'dialogueProfileId': dialogueProfileId,
    },
    if (!isVillain) ...{
      'unlocked': unlocked,
      'unlockRequirement': unlockRequirement,
    },
  };
}
