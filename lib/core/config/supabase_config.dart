/// Supabase configuration constants for PixelPunch.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://lpkffpyxeyfdyzvqtqcc.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxwa2ZmcHl4ZXlmZHl6dnF0cWNjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIxNDQxMzcsImV4cCI6MjEwNzcyMDEzN30.IgO_nRVOXiu_l8hnbr_I1c-A48tns9_Y_Sm3WBgk1yM';

  // Table names
  static const String profilesTable = 'profiles';
  static const String playerProgressTable = 'player_progress';
  static const String playerCharactersTable = 'player_characters';
  static const String playerCosmeticsTable = 'player_cosmetics';
  static const String playerCustomizationTable = 'player_customization';
  static const String playerSettingsTable = 'player_settings';
  static const String playerZonesTable = 'player_zones';
  static const String villainProgressTable = 'villain_progress';
  static const String missionProgressTable = 'mission_progress';
  static const String matchHistoryTable = 'match_history';
  static const String achievementsTable = 'achievements';
  static const String playerAchievementsTable = 'player_achievements';
}
