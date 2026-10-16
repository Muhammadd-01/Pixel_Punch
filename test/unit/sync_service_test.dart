import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pixel_punch/game/models/game_enums.dart';
import 'package:pixel_punch/game/models/match_result.dart';
import 'package:pixel_punch/game/models/player_progress.dart';
import 'package:pixel_punch/services/local_storage_service.dart';
import 'package:pixel_punch/services/supabase_service.dart';
import 'package:pixel_punch/services/sync_service.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}
class MockSupabaseService extends Mock implements SupabaseService {}

void main() {
  group('SyncService Tests', () {
    late MockLocalStorageService mockLocalStorage;
    late MockSupabaseService mockSupabase;
    late SyncService syncService;

    setUp(() {
      mockLocalStorage = MockLocalStorageService();
      mockSupabase = MockSupabaseService();
      syncService = SyncService(
        localStorage: mockLocalStorage,
        supabaseService: mockSupabase,
      );
    });

    test('Queue match stores matches and prevents duplicates', () {
      final match1 = MatchResult(
        matchId: 'match_001',
        mode: GameMode.solo,
        zoneId: 'zone_office',
        playerCharacterIds: ['hero_striker'],
        enemyIds: ['villain_bug_phantom'],
        outcome: MatchOutcome.victory,
        durationSeconds: 30,
        damageDealt: 100,
        damageTaken: 20,
        xpEarned: 50,
        completedAt: DateTime.now(),
      );

      final match2 = MatchResult(
        matchId: 'match_002',
        mode: GameMode.duo,
        zoneId: 'zone_neon',
        playerCharacterIds: ['hero_striker', 'hero_bulwark'],
        enemyIds: ['villain_firewall_guardian', 'villain_lag_lord'],
        outcome: MatchOutcome.victory,
        durationSeconds: 45,
        damageDealt: 150,
        damageTaken: 40,
        xpEarned: 50,
        completedAt: DateTime.now(),
      );

      syncService.queueMatch(match1);
      expect(syncService.pendingQueueCount, equals(1));

      // Adding the same match ID again should not increase queue size
      syncService.queueMatch(match1);
      expect(syncService.pendingQueueCount, equals(1));

      // Adding a different match ID increases queue size
      syncService.queueMatch(match2);
      expect(syncService.pendingQueueCount, equals(2));
    });

    test('Sync data remains idle when not authenticated', () async {
      when(() => mockSupabase.isAuthenticated).thenReturn(false);

      final progress = PlayerProgress();
      await syncService.syncData(progress);

      expect(syncService.status, equals(SyncStatus.idle));
      verifyNever(() => mockSupabase.fetchCloudProgress());
    });
  });
}
