# PixelPunch — Supabase Cloud Setup

## 1. Credentials Configuration
The app is configured to connect to Supabase:
- **Project URL**: `https://lpkffpyxeyfdyzvqtqcc.supabase.co`
- **Publishable Anon Key**: Configured in `lib/core/config/supabase_config.dart`.

---

## 2. Setting Up Database Schema & Migrations

To apply the schema to your Supabase project:

1. Open your Supabase Dashboard: [https://supabase.com/dashboard/project/lpkffpyxeyfdyzvqtqcc](https://supabase.com/dashboard/project/lpkffpyxeyfdyzvqtqcc).
2. Go to the **SQL Editor** tab on the left sidebar.
3. Open `supabase/migrations/20261016_initial_schema.sql` from this codebase.
4. Paste the SQL statements into the SQL Editor and click **Run**.
5. Open `supabase/seed.sql` and run it to populate standard achievements.

---

## 3. Configuring Authentication

1. In the Supabase Dashboard, navigate to **Authentication** -> **Providers**.
2. Ensure **Email** is enabled.
3. Optional: In **URL Configuration**, set the Site URL or deep-link redirect:
   - For Android: `pixelpunch://auth-callback`
   - For local development: `http://localhost:3000`

---

## 4. Row-Level Security (RLS) Verification
All tables storing player progress, match history, and customizations have RLS enabled:
- Users can only read and write their own records (`auth.uid() = user_id`).
- Achievements and public profiles are publicly readable.
- Service-role secrets are never embedded in the client application.
