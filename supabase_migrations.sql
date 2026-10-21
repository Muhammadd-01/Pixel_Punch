-- ============================================================================
-- Pixel Punch: Supabase SQL Migrations (Safe Re-run Version)
-- Run this in your Supabase SQL Editor (Dashboard > SQL Editor)
-- ============================================================================

-- ========================
-- CLEANUP: Drop old tables/policies if they exist from a partial run
-- ========================

-- Drop policies first (they depend on tables)
DROP POLICY IF EXISTS "Users can view their own friendships" ON friendships;
DROP POLICY IF EXISTS "Users can send friend requests" ON friendships;
DROP POLICY IF EXISTS "Users can update friendships they're part of" ON friendships;
DROP POLICY IF EXISTS "Users can delete their own friendships" ON friendships;

DROP POLICY IF EXISTS "Users can view all presence" ON user_presence;
DROP POLICY IF EXISTS "Users can update their own presence" ON user_presence;
DROP POLICY IF EXISTS "Users can upsert their own presence" ON user_presence;

DROP POLICY IF EXISTS "Anyone can view open lobbies" ON match_lobbies;
DROP POLICY IF EXISTS "Authenticated users can create lobbies" ON match_lobbies;
DROP POLICY IF EXISTS "Host can update their lobby" ON match_lobbies;
DROP POLICY IF EXISTS "Host can delete their lobby" ON match_lobbies;

DROP POLICY IF EXISTS "Anyone can view lobby players" ON lobby_players;
DROP POLICY IF EXISTS "Users can join lobbies" ON lobby_players;
DROP POLICY IF EXISTS "Users can update their own lobby entry" ON lobby_players;
DROP POLICY IF EXISTS "Users can leave lobbies" ON lobby_players;

-- Drop tables (order matters due to foreign keys)
DROP TABLE IF EXISTS lobby_players CASCADE;
DROP TABLE IF EXISTS match_lobbies CASCADE;
DROP TABLE IF EXISTS user_presence CASCADE;
DROP TABLE IF EXISTS friendships CASCADE;

-- Drop old trigger/function if they exist
DROP TRIGGER IF EXISTS set_friend_code ON profiles;
DROP FUNCTION IF EXISTS generate_friend_code();

-- ========================
-- 1. Add friend_code column to profiles
-- ========================
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS friend_code TEXT UNIQUE;

UPDATE profiles
SET friend_code = UPPER(SUBSTR(MD5(RANDOM()::TEXT), 1, 8))
WHERE friend_code IS NULL;

-- ========================
-- 2. Friendships table
-- ========================
CREATE TABLE friendships (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  requester_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  addressee_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'rejected', 'blocked')),
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(requester_id, addressee_id)
);

CREATE INDEX idx_friendships_requester ON friendships(requester_id);
CREATE INDEX idx_friendships_addressee ON friendships(addressee_id);
CREATE INDEX idx_friendships_status    ON friendships(status);

ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own friendships"
  ON friendships FOR SELECT
  USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

CREATE POLICY "Users can send friend requests"
  ON friendships FOR INSERT
  WITH CHECK (auth.uid() = requester_id);

CREATE POLICY "Users can update friendships they're part of"
  ON friendships FOR UPDATE
  USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

CREATE POLICY "Users can delete their own friendships"
  ON friendships FOR DELETE
  USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

-- ========================
-- 3. User presence table
-- ========================
CREATE TABLE user_presence (
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  status TEXT NOT NULL DEFAULT 'offline'
    CHECK (status IN ('online', 'in_game', 'in_lobby', 'offline')),
  last_seen TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  current_lobby_id UUID,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

ALTER TABLE user_presence ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all presence"
  ON user_presence FOR SELECT
  USING (true);

CREATE POLICY "Users can update their own presence"
  ON user_presence FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can upsert their own presence"
  ON user_presence FOR UPDATE
  USING (auth.uid() = user_id);

-- ========================
-- 4. Match lobbies table
-- ========================
CREATE TABLE match_lobbies (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  host_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  invite_code TEXT UNIQUE NOT NULL,
  mode TEXT NOT NULL CHECK (mode IN ('solo', 'duo', 'squad')),
  zone_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'waiting'
    CHECK (status IN ('waiting', 'starting', 'in_game', 'finished')),
  max_players INT NOT NULL DEFAULT 2,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_lobbies_invite ON match_lobbies(invite_code);
CREATE INDEX idx_lobbies_host   ON match_lobbies(host_id);
CREATE INDEX idx_lobbies_status ON match_lobbies(status);

ALTER TABLE match_lobbies ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view open lobbies"
  ON match_lobbies FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can create lobbies"
  ON match_lobbies FOR INSERT
  WITH CHECK (auth.uid() = host_id);

CREATE POLICY "Host can update their lobby"
  ON match_lobbies FOR UPDATE
  USING (auth.uid() = host_id);

CREATE POLICY "Host can delete their lobby"
  ON match_lobbies FOR DELETE
  USING (auth.uid() = host_id);

-- ========================
-- 5. Lobby players table
-- ========================
CREATE TABLE lobby_players (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  lobby_id UUID REFERENCES match_lobbies(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  hero_id TEXT NOT NULL,
  is_ready BOOLEAN DEFAULT FALSE NOT NULL,
  joined_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE(lobby_id, user_id)
);

CREATE INDEX idx_lobby_players_lobby ON lobby_players(lobby_id);
CREATE INDEX idx_lobby_players_user  ON lobby_players(user_id);

ALTER TABLE lobby_players ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view lobby players"
  ON lobby_players FOR SELECT
  USING (true);

CREATE POLICY "Users can join lobbies"
  ON lobby_players FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own lobby entry"
  ON lobby_players FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can leave lobbies"
  ON lobby_players FOR DELETE
  USING (auth.uid() = user_id);

-- ========================
-- 6. Enable Realtime
-- ========================
ALTER PUBLICATION supabase_realtime ADD TABLE match_lobbies;
ALTER PUBLICATION supabase_realtime ADD TABLE lobby_players;
ALTER PUBLICATION supabase_realtime ADD TABLE user_presence;

-- ========================
-- 7. Auto-generate friend codes for new profiles
-- ========================
CREATE OR REPLACE FUNCTION generate_friend_code()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.friend_code IS NULL THEN
    NEW.friend_code := UPPER(SUBSTR(MD5(RANDOM()::TEXT), 1, 8));
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_friend_code
  BEFORE INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION generate_friend_code();
