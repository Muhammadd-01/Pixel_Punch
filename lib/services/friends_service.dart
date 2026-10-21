import 'dart:math';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import '../core/config/supabase_config.dart';

/// Friendship status between two users.
enum FriendshipStatus {
  pending,
  accepted,
  blocked;

  static FriendshipStatus fromString(String s) => switch (s) {
    'accepted' => FriendshipStatus.accepted,
    'blocked' => FriendshipStatus.blocked,
    _ => FriendshipStatus.pending,
  };
}

/// Online presence status.
enum PresenceStatus {
  online,
  inGame,
  idle,
  offline;

  static PresenceStatus fromString(String s) => switch (s) {
    'online' => PresenceStatus.online,
    'in_game' => PresenceStatus.inGame,
    'idle' => PresenceStatus.idle,
    _ => PresenceStatus.offline,
  };

  String get displayName => switch (this) {
    PresenceStatus.online => 'Online',
    PresenceStatus.inGame => 'In Game',
    PresenceStatus.idle => 'Idle',
    PresenceStatus.offline => 'Offline',
  };

  String get dbValue => switch (this) {
    PresenceStatus.online => 'online',
    PresenceStatus.inGame => 'in_game',
    PresenceStatus.idle => 'idle',
    PresenceStatus.offline => 'offline',
  };
}

/// A friend record with display info and online status.
class FriendInfo {
  final String odentifer;
  final String userId;
  final String displayName;
  final String? friendCode;
  final PresenceStatus status;
  final int playerLevel;
  final int wins;
  final int losses;
  final DateTime? lastSeen;
  final FriendshipStatus friendshipStatus;

  const FriendInfo({
    required this.odentifer,
    required this.userId,
    required this.displayName,
    this.friendCode,
    this.status = PresenceStatus.offline,
    this.playerLevel = 1,
    this.wins = 0,
    this.losses = 0,
    this.lastSeen,
    this.friendshipStatus = FriendshipStatus.accepted,
  });
}

/// Service for managing friends, friend requests, and online presence.
class FriendsService extends ChangeNotifier {
  final SupabaseService _supabase;

  List<FriendInfo> _friends = [];
  List<FriendInfo> _pendingRequests = [];
  List<FriendInfo> _sentRequests = [];
  String? _myFriendCode;
  bool _isLoading = false;

  FriendsService({required SupabaseService supabaseService})
      : _supabase = supabaseService;

  List<FriendInfo> get friends => _friends;
  List<FriendInfo> get pendingRequests => _pendingRequests;
  List<FriendInfo> get sentRequests => _sentRequests;
  String? get myFriendCode => _myFriendCode;
  bool get isLoading => _isLoading;

  int get onlineFriendsCount =>
      _friends.where((f) => f.status != PresenceStatus.offline).length;

  List<FriendInfo> get onlineFriends =>
      _friends.where((f) => f.status != PresenceStatus.offline).toList();

  List<FriendInfo> get offlineFriends =>
      _friends.where((f) => f.status == PresenceStatus.offline).toList();

  /// Generate a unique friend code for the user if they don't have one.
  Future<String?> ensureFriendCode() async {
    if (!_supabase.isAuthenticated) return null;
    final client = _supabase.client;
    if (client == null) return null;

    try {
      // Check if user already has a friend code
      final profile = await client
          .from(SupabaseConfig.profilesTable)
          .select('friend_code')
          .eq('id', _supabase.currentUser!.id)
          .maybeSingle();

      if (profile != null && profile['friend_code'] != null) {
        _myFriendCode = profile['friend_code'] as String;
        return _myFriendCode;
      }

      // Generate a unique 8-character code
      final code = _generateFriendCode();
      await client
          .from(SupabaseConfig.profilesTable)
          .update({'friend_code': code})
          .eq('id', _supabase.currentUser!.id);
      _myFriendCode = code;
      notifyListeners();
      return code;
    } catch (e) {
      debugPrint('[FriendsService] ensureFriendCode error: $e');
      return null;
    }
  }

  String _generateFriendCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return 'PP-${List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join()}';
  }

  /// Load all friends, pending requests, and sent requests.
  Future<void> loadFriends() async {
    if (!_supabase.isAuthenticated) return;
    final client = _supabase.client;
    if (client == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final userId = _supabase.currentUser!.id;

      // Fetch friendships where this user is involved
      final friendships = await client
          .from(SupabaseConfig.friendshipsTable)
          .select()
          .or('user_id.eq.$userId,friend_id.eq.$userId');

      _friends = [];
      _pendingRequests = [];
      _sentRequests = [];

      for (final f in friendships) {
        final status = FriendshipStatus.fromString(f['status'] as String);
        final isRequester = f['user_id'] == userId;
        final otherUserId = isRequester
            ? f['friend_id'] as String
            : f['user_id'] as String;

        // Fetch other user's profile
        final profile = await client
            .from(SupabaseConfig.profilesTable)
            .select()
            .eq('id', otherUserId)
            .maybeSingle();

        // Fetch presence
        final presence = await client
            .from(SupabaseConfig.userPresenceTable)
            .select()
            .eq('user_id', otherUserId)
            .maybeSingle();

        // Fetch progress
        final progress = await client
            .from(SupabaseConfig.playerProgressTable)
            .select()
            .eq('user_id', otherUserId)
            .maybeSingle();

        final friendInfo = FriendInfo(
          odentifer: f['id'] as String,
          userId: otherUserId,
          displayName: profile?['display_name'] as String? ?? 'Fighter',
          friendCode: profile?['friend_code'] as String?,
          status: presence != null
              ? PresenceStatus.fromString(presence['status'] as String)
              : PresenceStatus.offline,
          playerLevel: progress?['player_level'] as int? ?? 1,
          wins: progress?['wins'] as int? ?? 0,
          losses: progress?['losses'] as int? ?? 0,
          lastSeen: presence?['last_seen'] != null
              ? DateTime.tryParse(presence!['last_seen'] as String)
              : null,
          friendshipStatus: status,
        );

        if (status == FriendshipStatus.accepted) {
          _friends.add(friendInfo);
        } else if (status == FriendshipStatus.pending) {
          if (isRequester) {
            _sentRequests.add(friendInfo);
          } else {
            _pendingRequests.add(friendInfo);
          }
        }
      }

      // Sort: online first, then by name
      _friends.sort((a, b) {
        if (a.status != PresenceStatus.offline &&
            b.status == PresenceStatus.offline) {
          return -1;
        }
        if (a.status == PresenceStatus.offline &&
            b.status != PresenceStatus.offline) {
          return 1;
        }
        return a.displayName.compareTo(b.displayName);
      });
    } catch (e) {
      debugPrint('[FriendsService] loadFriends error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send a friend request by friend code.
  Future<String?> sendFriendRequest(String friendCode) async {
    if (!_supabase.isAuthenticated) return 'You must be logged in';
    final client = _supabase.client;
    if (client == null) return 'Not connected';

    try {
      final code = friendCode.trim().toUpperCase();
      final userId = _supabase.currentUser!.id;

      // Find user by friend code
      final target = await client
          .from(SupabaseConfig.profilesTable)
          .select('id')
          .eq('friend_code', code)
          .maybeSingle();

      if (target == null) return 'No player found with that code';

      final friendId = target['id'] as String;
      if (friendId == userId) return "You can't add yourself!";

      // Check existing friendship
      final existing = await client
          .from(SupabaseConfig.friendshipsTable)
          .select()
          .or('and(user_id.eq.$userId,friend_id.eq.$friendId),and(user_id.eq.$friendId,friend_id.eq.$userId)')
          .maybeSingle();

      if (existing != null) {
        final status = existing['status'] as String;
        if (status == 'accepted') return 'Already friends!';
        if (status == 'pending') return 'Request already pending';
        if (status == 'blocked') return 'Unable to send request';
      }

      // Create friendship request
      await client.from(SupabaseConfig.friendshipsTable).insert({
        'user_id': userId,
        'friend_id': friendId,
        'status': 'pending',
      });

      await loadFriends();
      return null; // Success
    } catch (e) {
      debugPrint('[FriendsService] sendFriendRequest error: $e');
      return 'Failed to send request. Try again.';
    }
  }

  /// Accept a pending friend request.
  Future<bool> acceptRequest(String friendshipId) async {
    final client = _supabase.client;
    if (client == null) return false;

    try {
      await client
          .from(SupabaseConfig.friendshipsTable)
          .update({'status': 'accepted'})
          .eq('id', friendshipId);
      await loadFriends();
      return true;
    } catch (e) {
      debugPrint('[FriendsService] acceptRequest error: $e');
      return false;
    }
  }

  /// Reject/remove a friend request or friendship.
  Future<bool> removeFriendship(String friendshipId) async {
    final client = _supabase.client;
    if (client == null) return false;

    try {
      await client
          .from(SupabaseConfig.friendshipsTable)
          .delete()
          .eq('id', friendshipId);
      await loadFriends();
      return true;
    } catch (e) {
      debugPrint('[FriendsService] removeFriendship error: $e');
      return false;
    }
  }

  /// Update current user's presence status.
  Future<void> updatePresence(PresenceStatus status) async {
    if (!_supabase.isAuthenticated) return;
    final client = _supabase.client;
    if (client == null) return;

    try {
      await client.from(SupabaseConfig.userPresenceTable).upsert({
        'user_id': _supabase.currentUser!.id,
        'status': status.dbValue,
        'last_seen': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[FriendsService] updatePresence error: $e');
    }
  }

  /// Search for users by display name (partial match).
  Future<List<FriendInfo>> searchUsers(String query) async {
    final client = _supabase.client;
    if (client == null || query.trim().length < 2) return [];

    try {
      final results = await client
          .from(SupabaseConfig.profilesTable)
          .select()
          .ilike('display_name', '%${query.trim()}%')
          .neq('id', _supabase.currentUser?.id ?? '')
          .limit(20);

      return results.map<FriendInfo>((r) => FriendInfo(
        odentifer: '',
        userId: r['id'] as String,
        displayName: r['display_name'] as String? ?? 'Fighter',
        friendCode: r['friend_code'] as String?,
      )).toList();
    } catch (e) {
      debugPrint('[FriendsService] searchUsers error: $e');
      return [];
    }
  }
}
