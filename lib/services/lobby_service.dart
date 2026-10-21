import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/config/supabase_config.dart';
import '../game/models/game_enums.dart';
import 'supabase_service.dart';

/// A player slot in a match lobby.
class LobbyPlayer {
  final String odentifer;
  final String userId;
  final String displayName;
  final String heroId;
  final bool isReady;
  final bool isHost;
  final int slot;

  const LobbyPlayer({
    required this.odentifer,
    required this.userId,
    required this.displayName,
    required this.heroId,
    this.isReady = false,
    this.isHost = false,
    this.slot = 0,
  });
}

/// Lobby status.
enum LobbyStatus {
  waiting,
  ready,
  inGame,
  finished;

  static LobbyStatus fromString(String s) => switch (s) {
    'ready' => LobbyStatus.ready,
    'in_game' => LobbyStatus.inGame,
    'finished' => LobbyStatus.finished,
    _ => LobbyStatus.waiting,
  };
}

/// Info about a match lobby.
class LobbyInfo {
  final String id;
  final String hostId;
  final GameMode mode;
  final String zoneId;
  final LobbyStatus status;
  final String? inviteCode;
  final List<LobbyPlayer> players;
  final int maxPlayers;

  const LobbyInfo({
    required this.id,
    required this.hostId,
    required this.mode,
    required this.zoneId,
    required this.status,
    this.inviteCode,
    this.players = const [],
    this.maxPlayers = 2,
  });

  bool get isFull => players.length >= maxPlayers;
  bool get allReady => players.every((p) => p.isReady);
  bool isHost(String userId) => hostId == userId;
}

/// Service for creating, joining, and managing multiplayer lobbies.
class LobbyService extends ChangeNotifier {
  final SupabaseService _supabase;
  LobbyInfo? _currentLobby;
  bool _isLoading = false;
  StreamSubscription? _lobbySubscription;
  StreamSubscription? _playersSubscription;

  LobbyService({required SupabaseService supabaseService})
      : _supabase = supabaseService;

  LobbyInfo? get currentLobby => _currentLobby;
  bool get isLoading => _isLoading;
  bool get isInLobby => _currentLobby != null;

  /// Create a new multiplayer lobby.
  Future<String?> createLobby({
    required GameMode mode,
    required String zoneId,
    required String heroId,
  }) async {
    if (!_supabase.isAuthenticated) return 'Must be logged in for multiplayer';
    final client = _supabase.client;
    if (client == null) return 'Not connected';

    _isLoading = true;
    notifyListeners();

    try {
      final userId = _supabase.currentUser!.id;

      // Generate a short invite code
      final code = _generateInviteCode();

      // Create lobby
      final lobbyData = await client
          .from(SupabaseConfig.matchLobbiesTable)
          .insert({
            'host_id': userId,
            'mode': mode.name,
            'zone_id': zoneId,
            'status': 'waiting',
            'max_players': mode.friendlyCount,
            'invite_code': code,
          })
          .select()
          .single();

      final lobbyId = lobbyData['id'] as String;

      // Add host as first player
      await client.from(SupabaseConfig.lobbyPlayersTable).insert({
        'lobby_id': lobbyId,
        'user_id': userId,
        'hero_id': heroId,
        'is_ready': true,
        'slot': 0,
      });

      // Subscribe to lobby updates
      _subscribeLobby(lobbyId);

      await _refreshLobby(lobbyId);
      _isLoading = false;
      notifyListeners();
      return null; // Success
    } catch (e) {
      debugPrint('[LobbyService] createLobby error: $e');
      _isLoading = false;
      notifyListeners();
      return 'Failed to create lobby';
    }
  }

  /// Join a lobby by invite code.
  Future<String?> joinLobby({
    required String inviteCode,
    required String heroId,
  }) async {
    if (!_supabase.isAuthenticated) return 'Must be logged in';
    final client = _supabase.client;
    if (client == null) return 'Not connected';

    _isLoading = true;
    notifyListeners();

    try {
      final userId = _supabase.currentUser!.id;

      // Find lobby by code
      final lobby = await client
          .from(SupabaseConfig.matchLobbiesTable)
          .select()
          .eq('invite_code', inviteCode.trim().toUpperCase())
          .eq('status', 'waiting')
          .maybeSingle();

      if (lobby == null) {
        _isLoading = false;
        notifyListeners();
        return 'Lobby not found or already started';
      }

      final lobbyId = lobby['id'] as String;
      final maxPlayers = lobby['max_players'] as int;

      // Check if lobby is full
      final existingPlayers = await client
          .from(SupabaseConfig.lobbyPlayersTable)
          .select()
          .eq('lobby_id', lobbyId);

      if (existingPlayers.length >= maxPlayers) {
        _isLoading = false;
        notifyListeners();
        return 'Lobby is full';
      }

      // Join lobby
      await client.from(SupabaseConfig.lobbyPlayersTable).insert({
        'lobby_id': lobbyId,
        'user_id': userId,
        'hero_id': heroId,
        'is_ready': false,
        'slot': existingPlayers.length,
      });

      _subscribeLobby(lobbyId);
      await _refreshLobby(lobbyId);

      _isLoading = false;
      notifyListeners();
      return null; // Success
    } catch (e) {
      debugPrint('[LobbyService] joinLobby error: $e');
      _isLoading = false;
      notifyListeners();
      return 'Failed to join lobby';
    }
  }

  /// Toggle ready status.
  Future<void> toggleReady() async {
    final lobby = _currentLobby;
    if (lobby == null || !_supabase.isAuthenticated) return;
    final client = _supabase.client;
    if (client == null) return;

    final userId = _supabase.currentUser!.id;
    final mySlot = lobby.players.where((p) => p.userId == userId).firstOrNull;
    if (mySlot == null) return;

    try {
      await client
          .from(SupabaseConfig.lobbyPlayersTable)
          .update({'is_ready': !mySlot.isReady})
          .eq('lobby_id', lobby.id)
          .eq('user_id', userId);

      await _refreshLobby(lobby.id);
    } catch (e) {
      debugPrint('[LobbyService] toggleReady error: $e');
    }
  }

  /// Change hero selection.
  Future<void> changeHero(String heroId) async {
    final lobby = _currentLobby;
    if (lobby == null || !_supabase.isAuthenticated) return;
    final client = _supabase.client;
    if (client == null) return;

    try {
      await client
          .from(SupabaseConfig.lobbyPlayersTable)
          .update({'hero_id': heroId})
          .eq('lobby_id', lobby.id)
          .eq('user_id', _supabase.currentUser!.id);

      await _refreshLobby(lobby.id);
    } catch (e) {
      debugPrint('[LobbyService] changeHero error: $e');
    }
  }

  /// Start the game (host only). Sets lobby status to in_game.
  Future<String?> startGame() async {
    final lobby = _currentLobby;
    if (lobby == null) return 'No lobby';
    if (!lobby.isHost(_supabase.currentUser?.id ?? '')) return 'Not the host';
    if (!lobby.allReady) return 'Not all players are ready';

    final client = _supabase.client;
    if (client == null) return 'Not connected';

    try {
      await client
          .from(SupabaseConfig.matchLobbiesTable)
          .update({'status': 'in_game'})
          .eq('id', lobby.id);

      await _refreshLobby(lobby.id);
      return null;
    } catch (e) {
      debugPrint('[LobbyService] startGame error: $e');
      return 'Failed to start game';
    }
  }

  /// Leave the current lobby.
  Future<void> leaveLobby() async {
    final lobby = _currentLobby;
    if (lobby == null) return;
    final client = _supabase.client;
    if (client == null) return;

    try {
      final userId = _supabase.currentUser?.id;

      // Remove player from lobby
      if (userId != null) {
        await client
            .from(SupabaseConfig.lobbyPlayersTable)
            .delete()
            .eq('lobby_id', lobby.id)
            .eq('user_id', userId);
      }

      // If host leaves, delete the entire lobby
      if (userId == lobby.hostId) {
        await client
            .from(SupabaseConfig.matchLobbiesTable)
            .delete()
            .eq('id', lobby.id);
      }
    } catch (e) {
      debugPrint('[LobbyService] leaveLobby error: $e');
    } finally {
      _lobbySubscription?.cancel();
      _playersSubscription?.cancel();
      _currentLobby = null;
      notifyListeners();
    }
  }

  /// Subscribe to realtime lobby updates.
  void _subscribeLobby(String lobbyId) {
    _lobbySubscription?.cancel();
    _playersSubscription?.cancel();

    final client = _supabase.client;
    if (client == null) return;

    // Listen for lobby status changes
    _lobbySubscription = client
        .from(SupabaseConfig.matchLobbiesTable)
        .stream(primaryKey: ['id'])
        .eq('id', lobbyId)
        .listen((_) => _refreshLobby(lobbyId));

    // Listen for player join/leave/ready changes
    _playersSubscription = client
        .from(SupabaseConfig.lobbyPlayersTable)
        .stream(primaryKey: ['lobby_id', 'user_id'])
        .eq('lobby_id', lobbyId)
        .listen((_) => _refreshLobby(lobbyId));
  }

  /// Refresh lobby data from the database.
  Future<void> _refreshLobby(String lobbyId) async {
    final client = _supabase.client;
    if (client == null) return;

    try {
      final lobbyData = await client
          .from(SupabaseConfig.matchLobbiesTable)
          .select()
          .eq('id', lobbyId)
          .maybeSingle();

      if (lobbyData == null) {
        _currentLobby = null;
        notifyListeners();
        return;
      }

      // Fetch players
      final playersData = await client
          .from(SupabaseConfig.lobbyPlayersTable)
          .select()
          .eq('lobby_id', lobbyId);

      final players = <LobbyPlayer>[];
      for (final p in playersData) {
        final profile = await client
            .from(SupabaseConfig.profilesTable)
            .select('display_name')
            .eq('id', p['user_id'] as String)
            .maybeSingle();

        players.add(LobbyPlayer(
          odentifer: '${p['lobby_id']}_${p['user_id']}',
          userId: p['user_id'] as String,
          displayName: profile?['display_name'] as String? ?? 'Fighter',
          heroId: p['hero_id'] as String,
          isReady: p['is_ready'] as bool? ?? false,
          isHost: p['user_id'] == lobbyData['host_id'],
          slot: p['slot'] as int? ?? 0,
        ));
      }

      _currentLobby = LobbyInfo(
        id: lobbyId,
        hostId: lobbyData['host_id'] as String,
        mode: GameMode.values.firstWhere(
          (m) => m.name == lobbyData['mode'],
          orElse: () => GameMode.duo,
        ),
        zoneId: lobbyData['zone_id'] as String,
        status: LobbyStatus.fromString(lobbyData['status'] as String),
        inviteCode: lobbyData['invite_code'] as String?,
        players: players,
        maxPlayers: lobbyData['max_players'] as int? ?? 2,
      );

      notifyListeners();
    } catch (e) {
      debugPrint('[LobbyService] refreshLobby error: $e');
    }
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = DateTime.now().millisecondsSinceEpoch;
    return List.generate(
      6,
      (i) => chars[(rng + i * 7) % chars.length],
    ).join();
  }

  @override
  void dispose() {
    _lobbySubscription?.cancel();
    _playersSubscription?.cancel();
    super.dispose();
  }
}
