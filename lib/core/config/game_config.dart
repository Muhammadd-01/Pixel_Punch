/// Central game configuration constants.
class GameConfig {
  GameConfig._();

  // App
  static const String appName = 'PixelPunch';
  static const String tagline = 'Your Zone. Your Rivals. Your Victory.';
  static const String version = '1.0.0';

  // Game dimensions
  static const double defaultZoneWidth = 1600.0;
  static const double defaultZoneHeight = 1200.0;

  // Player
  static const double playerSize = 40.0;
  static const double defaultMoveSpeed = 150.0;

  // Combat
  static const double defaultAttackRange = 45.0;
  static const double defaultAttackCooldown = 0.8;
  static const int defaultAttackDamage = 15;
  static const int defaultDefense = 10;
  static const int defaultHealth = 100;
  static const double knockbackForce = 80.0;
  static const double invulnerabilityDuration = 0.5;
  static const double hitFlashDuration = 0.15;

  // AI
  static const double aiDecisionInterval = 0.3;
  static const double aiApproachDistance = 200.0;
  static const double aiAttackDistance = 50.0;
  static const double aiRetreatHealthPercent = 0.2;

  // Dialogue
  static const double dialogueCooldown = 8.0;
  static const double typewriterSpeed = 0.03;

  // Camera
  static const double cameraLerpSpeed = 3.0;

  // Discovery
  static const double discoveryTriggerRadius = 80.0;

  // Match
  static const double matchTimerSeconds = 120.0;

  // XP
  static const int xpPerVillainDefeat = 50;
  static const int xpPerMissionComplete = 100;
  static const int xpPerLevelUp = 200;
}
