import 'dart:ui';

/// Represents a named location within a zone.
class ZoneLocation {
  final String name;
  final double x;
  final double y;
  final double width;
  final double height;

  const ZoneLocation({
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory ZoneLocation.fromJson(Map<String, dynamic> json) {
    return ZoneLocation(
      name: json['name'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }
}

/// Represents an obstacle in a zone.
class ZoneObstacle {
  final String type;
  final double x;
  final double y;
  final double width;
  final double height;

  const ZoneObstacle({
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory ZoneObstacle.fromJson(Map<String, dynamic> json) {
    return ZoneObstacle(
      type: json['type'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }
}

/// Represents a game zone.
class ZoneData {
  final String id;
  final String name;
  final String description;
  final String theme;
  final bool unlocked;
  final String? unlockRequirement;
  final String recommendedDifficulty;
  final double width;
  final double height;
  final Color backgroundColor;
  final List<String> villainIds;
  final List<ZoneLocation> locations;
  final List<ZoneObstacle> obstacles;
  final double playerSpawnX;
  final double playerSpawnY;

  const ZoneData({
    required this.id,
    required this.name,
    required this.description,
    required this.theme,
    required this.unlocked,
    this.unlockRequirement,
    required this.recommendedDifficulty,
    required this.width,
    required this.height,
    required this.backgroundColor,
    required this.villainIds,
    required this.locations,
    required this.obstacles,
    required this.playerSpawnX,
    required this.playerSpawnY,
  });

  factory ZoneData.fromJson(Map<String, dynamic> json) {
    final spawn = json['playerSpawn'] as Map<String, dynamic>;
    return ZoneData(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      theme: json['theme'] as String,
      unlocked: json['unlocked'] as bool,
      unlockRequirement: json['unlockRequirement'] as String?,
      recommendedDifficulty: json['recommendedDifficulty'] as String,
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      backgroundColor: Color(int.parse(json['backgroundColor'] as String)),
      villainIds: (json['villainIds'] as List).cast<String>(),
      locations: (json['locations'] as List)
          .map((l) => ZoneLocation.fromJson(l as Map<String, dynamic>))
          .toList(),
      obstacles: (json['obstacles'] as List)
          .map((o) => ZoneObstacle.fromJson(o as Map<String, dynamic>))
          .toList(),
      playerSpawnX: (spawn['x'] as num).toDouble(),
      playerSpawnY: (spawn['y'] as num).toDouble(),
    );
  }
}
