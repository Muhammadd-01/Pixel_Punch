import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';
import '../game/models/match_result.dart';
import '../game/models/player_progress.dart';

/// Service managing Supabase authentication, cloud profile, and persistence.
class SupabaseService {
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  SupabaseClient? get client {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  User? get currentUser => client?.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  /// Safe initialization that does not crash if network is unavailable.
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        // ignore: deprecated_member_use
        anonKey: SupabaseConfig.anonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      _isInitialized = true;
      debugPrint('[SupabaseService] Initialized successfully');
    } catch (e) {
      debugPrint('[SupabaseService] Offline or initialization error: $e');
      _isInitialized = false;
    }
  }

  /// Sign up with email, password, and display name.
  Future<AuthResponse?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (!_isInitialized || client == null) {
      await initialize();
    }
    if (!_isInitialized || client == null) {
      throw Exception('Unable to reach the server. Please check your internet connection and try again.');
    }
    try {
      final response = await client!.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );

      // Create initial profile record if user created
      if (response.user != null) {
        try {
          await client!.from(SupabaseConfig.profilesTable).upsert({
            'id': response.user!.id,
            'display_name': displayName,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (profileErr) {
          debugPrint('[SupabaseService] Profile creation skipped: $profileErr');
        }
      }
      return response;
    } catch (e) {
      debugPrint('[SupabaseService] Sign up error: $e');
      rethrow;
    }
  }

  /// Sign in with email and password.
  Future<AuthResponse?> signIn({
    required String email,
    required String password,
  }) async {
    if (!_isInitialized || client == null) {
      await initialize();
    }
    if (!_isInitialized || client == null) {
      throw Exception('Unable to reach the server. Please check your internet connection and try again.');
    }
    try {
      final response = await client!.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      debugPrint('[SupabaseService] Sign in error: $e');
      rethrow;
    }
  }

  /// Send password reset email.
  Future<void> resetPassword(String email) async {
    if (!_isInitialized || client == null) {
      await initialize();
    }
    if (!_isInitialized || client == null) {
      throw Exception('Unable to reach the server. Please check your internet connection and try again.');
    }
    try {
      await client!.auth.resetPasswordForEmail(email);
    } catch (e) {
      debugPrint('[SupabaseService] Reset password error: $e');
      rethrow;
    }
  }

  /// Sign out current user.
  Future<void> signOut() async {
    if (!_isInitialized || client == null) return;
    try {
      await client!.auth.signOut();
    } catch (e) {
      debugPrint('[SupabaseService] Sign out error: $e');
    }
  }

  /// Fetch cloud progression for current authenticated user.
  Future<Map<String, dynamic>?> fetchCloudProgress() async {
    if (!isAuthenticated || client == null) return null;
    try {
      final data = await client!
          .from(SupabaseConfig.playerProgressTable)
          .select()
          .eq('user_id', currentUser!.id)
          .maybeSingle();
      return data;
    } catch (e) {
      debugPrint('[SupabaseService] Fetch progress error: $e');
      return null;
    }
  }

  /// Upsert player progress to Supabase.
  Future<bool> syncPlayerProgress(PlayerProgress progress) async {
    if (!isAuthenticated || client == null) return false;
    try {
      await client!.from(SupabaseConfig.playerProgressTable).upsert({
        'user_id': currentUser!.id,
        'player_level': progress.playerLevel,
        'total_xp': progress.totalXp,
        'total_matches': progress.totalMatches,
        'wins': progress.wins,
        'losses': progress.losses,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] Sync progress error: $e');
      return false;
    }
  }

  /// Save match record to cloud history.
  Future<bool> uploadMatchRecord(MatchResult match) async {
    if (!isAuthenticated || client == null) return false;
    try {
      await client!.from(SupabaseConfig.matchHistoryTable).insert({
        'match_id': match.matchId,
        'user_id': currentUser!.id,
        'mode': match.mode.name,
        'zone_id': match.zoneId,
        'selected_characters': match.playerCharacterIds,
        'outcome': match.outcome.name,
        'duration_seconds': match.durationSeconds,
        'damage_dealt': match.damageDealt,
        'damage_taken': match.damageTaken,
        'xp_earned': match.xpEarned,
        'completed_at': match.completedAt.toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] Upload match error: $e');
      return false;
    }
  }
}
