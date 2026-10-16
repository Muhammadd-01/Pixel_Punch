-- =============================================================================
-- PIXELPUNCH: INITIAL SUPABASE DATABASE SCHEMA
-- =============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. PROFILES
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE,
    display_name TEXT NOT NULL,
    avatar_path TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public profiles are viewable by everyone."
    ON public.profiles FOR SELECT
    USING (true);

CREATE POLICY "Users can insert their own profile."
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile."
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);

-- 2. PLAYER PROGRESS
CREATE TABLE IF NOT EXISTS public.player_progress (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    player_level INT NOT NULL DEFAULT 1 CHECK (player_level >= 1),
    total_xp INT NOT NULL DEFAULT 0 CHECK (total_xp >= 0),
    total_matches INT NOT NULL DEFAULT 0 CHECK (total_matches >= 0),
    wins INT NOT NULL DEFAULT 0 CHECK (wins >= 0),
    losses INT NOT NULL DEFAULT 0 CHECK (losses >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.player_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own progress"
    ON public.player_progress FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own progress"
    ON public.player_progress FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own progress"
    ON public.player_progress FOR UPDATE
    USING (auth.uid() = user_id);

-- 3. PLAYER CHARACTERS
CREATE TABLE IF NOT EXISTS public.player_characters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    character_id TEXT NOT NULL,
    unlocked_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE(user_id, character_id)
);

ALTER TABLE public.player_characters ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own unlocked characters"
    ON public.player_characters FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own unlocked characters"
    ON public.player_characters FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 4. PLAYER COSMETICS
CREATE TABLE IF NOT EXISTS public.player_cosmetics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    cosmetic_id TEXT NOT NULL,
    unlocked_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE(user_id, cosmetic_id)
);

ALTER TABLE public.player_cosmetics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own unlocked cosmetics"
    ON public.player_cosmetics FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own unlocked cosmetics"
    ON public.player_cosmetics FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 5. PLAYER CUSTOMIZATION
CREATE TABLE IF NOT EXISTS public.player_customization (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    character_id TEXT NOT NULL,
    settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (user_id, character_id)
);

ALTER TABLE public.player_customization ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their character customizations"
    ON public.player_customization FOR ALL
    USING (auth.uid() = user_id);

-- 6. PLAYER SETTINGS
CREATE TABLE IF NOT EXISTS public.player_settings (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    settings JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.player_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their settings"
    ON public.player_settings FOR ALL
    USING (auth.uid() = user_id);

-- 7. PLAYER ZONES
CREATE TABLE IF NOT EXISTS public.player_zones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    zone_id TEXT NOT NULL,
    is_unlocked BOOLEAN NOT NULL DEFAULT false,
    completion_state TEXT NOT NULL DEFAULT 'not_started',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE(user_id, zone_id)
);

ALTER TABLE public.player_zones ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view and update their zone progress"
    ON public.player_zones FOR ALL
    USING (auth.uid() = user_id);

-- 8. VILLAIN PROGRESS
CREATE TABLE IF NOT EXISTS public.villain_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    villain_id TEXT NOT NULL,
    zone_id TEXT NOT NULL,
    discovery_status TEXT NOT NULL DEFAULT 'unknown',
    defeat_status BOOLEAN NOT NULL DEFAULT false,
    encounter_completed BOOLEAN NOT NULL DEFAULT false,
    reward_claimed BOOLEAN NOT NULL DEFAULT false,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE(user_id, villain_id)
);

ALTER TABLE public.villain_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their villain encounters"
    ON public.villain_progress FOR ALL
    USING (auth.uid() = user_id);

-- 9. MISSION PROGRESS
CREATE TABLE IF NOT EXISTS public.mission_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    mission_id TEXT NOT NULL,
    completion_state TEXT NOT NULL DEFAULT 'pending',
    completion_timestamp TIMESTAMPTZ,
    claimed_reward_status BOOLEAN NOT NULL DEFAULT false,
    UNIQUE(user_id, mission_id)
);

ALTER TABLE public.mission_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their mission records"
    ON public.mission_progress FOR ALL
    USING (auth.uid() = user_id);

-- 10. MATCH HISTORY
CREATE TABLE IF NOT EXISTS public.match_history (
    match_id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    mode TEXT NOT NULL,
    zone_id TEXT NOT NULL,
    selected_characters TEXT[] NOT NULL DEFAULT '{}',
    outcome TEXT NOT NULL,
    duration_seconds INT NOT NULL DEFAULT 0,
    damage_dealt INT NOT NULL DEFAULT 0,
    damage_taken INT NOT NULL DEFAULT 0,
    xp_earned INT NOT NULL DEFAULT 0,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.match_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their match history"
    ON public.match_history FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can record their match history"
    ON public.match_history FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 11. ACHIEVEMENTS & PLAYER ACHIEVEMENTS
CREATE TABLE IF NOT EXISTS public.achievements (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    badge_icon TEXT,
    xp_reward INT NOT NULL DEFAULT 50
);

ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Achievements are publicly readable"
    ON public.achievements FOR SELECT
    USING (true);

CREATE TABLE IF NOT EXISTS public.player_achievements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    achievement_id TEXT NOT NULL REFERENCES public.achievements(id),
    unlocked_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE(user_id, achievement_id)
);

ALTER TABLE public.player_achievements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view and claim their own achievements"
    ON public.player_achievements FOR ALL
    USING (auth.uid() = user_id);

-- INDEXES FOR PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_match_history_user_id ON public.match_history(user_id);
CREATE INDEX IF NOT EXISTS idx_villain_progress_user_id ON public.villain_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_player_zones_user_id ON public.player_zones(user_id);
