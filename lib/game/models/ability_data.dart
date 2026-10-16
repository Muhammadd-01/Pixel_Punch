/// Types of special abilities.
enum AbilityType {
  damage,
  shield,
  dash,
  areaDamage,
  heal,
  evasion;

  factory AbilityType.fromString(String value) {
    return switch (value) {
      'damage' => AbilityType.damage,
      'shield' => AbilityType.shield,
      'dash' => AbilityType.dash,
      'area_damage' => AbilityType.areaDamage,
      'heal' => AbilityType.heal,
      'evasion' => AbilityType.evasion,
      _ => AbilityType.damage,
    };
  }
}

/// Represents a special ability definition.
class AbilityData {
  final String id;
  final String name;
  final String description;
  final String archetype;
  final double damageMultiplier;
  final double range;
  final double duration;
  final double cooldown;
  final int healAmount;
  final AbilityType type;

  const AbilityData({
    required this.id,
    required this.name,
    required this.description,
    required this.archetype,
    required this.damageMultiplier,
    required this.range,
    required this.duration,
    required this.cooldown,
    required this.healAmount,
    required this.type,
  });

  factory AbilityData.fromJson(Map<String, dynamic> json) {
    return AbilityData(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      archetype: json['archetype'] as String,
      damageMultiplier: (json['damageMultiplier'] as num).toDouble(),
      range: (json['range'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
      cooldown: (json['cooldown'] as num).toDouble(),
      healAmount: json['healAmount'] as int,
      type: AbilityType.fromString(json['type'] as String),
    );
  }
}
