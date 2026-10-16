# PixelPunch — Database Schema

The database schema is defined in `supabase/migrations/20261016_initial_schema.sql`.

## Tables Overview

### 1. `profiles`
- `id` (UUID, Primary Key, references `auth.users`)
- `username` (TEXT, unique, optional)
- `display_name` (TEXT, required)
- `avatar_path` (TEXT, optional)
- `created_at` (TIMESTAMPTZ)
- `updated_at` (TIMESTAMPTZ)
- **RLS**: Public read, owner insert & update.

### 2. `player_progress`
- `user_id` (UUID, Primary Key, references `auth.users`)
- `player_level` (INT, default 1)
- `total_xp` (INT, default 0)
- `total_matches` (INT, default 0)
- `wins` (INT, default 0)
- `losses` (INT, default 0)
- `updated_at` (TIMESTAMPTZ)
- **RLS**: Owner select, insert, and update.

### 3. `player_characters`
- `id` (UUID, Primary Key)
- `user_id` (UUID, references `auth.users`)
- `character_id` (TEXT)
- `unlocked_at` (TIMESTAMPTZ)
- **Unique**: `(user_id, character_id)`
- **RLS**: Owner select and insert.

### 4. `player_cosmetics`
- `id` (UUID, Primary Key)
- `user_id` (UUID, references `auth.users`)
- `cosmetic_id` (TEXT)
- `unlocked_at` (TIMESTAMPTZ)
- **Unique**: `(user_id, cosmetic_id)`
- **RLS**: Owner access.

### 5. `player_customization`
- `user_id` (UUID)
- `character_id` (TEXT)
- `settings` (JSONB)
- `updated_at` (TIMESTAMPTZ)
- **Primary Key**: `(user_id, character_id)`
- **RLS**: Owner access.

### 6. `player_settings`
- `user_id` (UUID, Primary Key)
- `settings` (JSONB)
- `updated_at` (TIMESTAMPTZ)
- **RLS**: Owner access.

### 7. `player_zones`
- `id` (UUID, Primary Key)
- `user_id` (UUID, references `auth.users`)
- `zone_id` (TEXT)
- `is_unlocked` (BOOLEAN)
- `completion_state` (TEXT)
- `updated_at` (TIMESTAMPTZ)
- **Unique**: `(user_id, zone_id)`
- **RLS**: Owner access.

### 8. `villain_progress`
- `id` (UUID, Primary Key)
- `user_id` (UUID, references `auth.users`)
- `villain_id` (TEXT)
- `zone_id` (TEXT)
- `discovery_status` (TEXT)
- `defeat_status` (BOOLEAN)
- `encounter_completed` (BOOLEAN)
- `reward_claimed` (BOOLEAN)
- `updated_at` (TIMESTAMPTZ)
- **Unique**: `(user_id, villain_id)`
- **RLS**: Owner access.

### 9. `mission_progress`
- `id` (UUID, Primary Key)
- `user_id` (UUID, references `auth.users`)
- `mission_id` (TEXT)
- `completion_state` (TEXT)
- `completion_timestamp` (TIMESTAMPTZ)
- `claimed_reward_status` (BOOLEAN)
- **Unique**: `(user_id, mission_id)`
- **RLS**: Owner access.

### 10. `match_history`
- `match_id` (TEXT, Primary Key)
- `user_id` (UUID, references `auth.users`)
- `mode` (TEXT)
- `zone_id` (TEXT)
- `selected_characters` (TEXT[])
- `outcome` (TEXT)
- `duration_seconds` (INT)
- `damage_dealt` (INT)
- `damage_taken` (INT)
- `xp_earned` (INT)
- `completed_at` (TIMESTAMPTZ)
- **RLS**: Owner select and insert.

### 11. `achievements` & `player_achievements`
- Master list of achievements and player unlock tracking with public read permissions.
