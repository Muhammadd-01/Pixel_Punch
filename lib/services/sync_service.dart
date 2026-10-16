import 'package:flutter/foundation.dart';
import '../game/models/match_result.dart';
import '../game/models/player_progress.dart';
import 'local_storage_service.dart';
import 'supabase_service.dart';

enum SyncStatus {
  idle,
  syncing,
  success,
  offline,
  error,
}

/// Offline-first synchronization coordinator between LocalStorage and Supabase.
class SyncService extends ChangeNotifier {
  final LocalStorageService localStorage;
  final SupabaseService supabaseService;

  SyncStatus _status = SyncStatus.idle;
  String? _lastError;
  final List<MatchResult> _pendingMatchesQueue = [];

  SyncStatus get status => _status;
  String? get lastError => _lastError;
  int get pendingQueueCount => _pendingMatchesQueue.length;

  SyncService({
    required this.localStorage,
    required this.supabaseService,
  });

  /// Queue a match for synchronization.
  void queueMatch(MatchResult match) {
    if (!_pendingMatchesQueue.any((m) => m.matchId == match.matchId)) {
      _pendingMatchesQueue.add(match);
      notifyListeners();
    }
  }

  /// Run sync reconciling local and remote data safely.
  Future<void> syncData(PlayerProgress localProgress) async {
    if (!supabaseService.isAuthenticated) {
      _status = SyncStatus.idle;
      notifyListeners();
      return;
    }

    _status = SyncStatus.syncing;
    notifyListeners();

    try {
      // 1. Fetch cloud progression
      final cloudData = await supabaseService.fetchCloudProgress();

      if (cloudData != null) {
        // Reconciliation: take higher level and XP, max wins/matches
        final cloudLevel = cloudData['player_level'] as int? ?? 1;
        final cloudXp = cloudData['total_xp'] as int? ?? 0;
        final cloudWins = cloudData['wins'] as int? ?? 0;
        final cloudLosses = cloudData['losses'] as int? ?? 0;
        final cloudMatches = cloudData['total_matches'] as int? ?? 0;

        if (cloudLevel > localProgress.playerLevel ||
            (cloudLevel == localProgress.playerLevel && cloudXp > localProgress.totalXp)) {
          localProgress.playerLevel = cloudLevel;
          localProgress.totalXp = cloudXp;
        }

        if (cloudWins > localProgress.wins) localProgress.wins = cloudWins;
        if (cloudLosses > localProgress.losses) localProgress.losses = cloudLosses;
        if (cloudMatches > localProgress.totalMatches) localProgress.totalMatches = cloudMatches;

        await localStorage.saveProgress(localProgress);
      }

      // 2. Upload latest local progress to cloud
      final progressOk = await supabaseService.syncPlayerProgress(localProgress);

      // 3. Flush pending match queue
      final remainingMatches = <MatchResult>[];
      for (final match in _pendingMatchesQueue) {
        final uploaded = await supabaseService.uploadMatchRecord(match);
        if (!uploaded) {
          remainingMatches.add(match);
        }
      }
      _pendingMatchesQueue
        ..clear()
        ..addAll(remainingMatches);

      if (progressOk && _pendingMatchesQueue.isEmpty) {
        _status = SyncStatus.success;
      } else {
        _status = SyncStatus.offline;
      }
    } catch (e) {
      debugPrint('[SyncService] Sync failure: $e');
      _status = SyncStatus.error;
      _lastError = e.toString();
    } finally {
      notifyListeners();
    }
  }
}
