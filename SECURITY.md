# PixelPunch — Security Guidelines & Architecture

## 1. Zero Secrets in Client Code
- **No Service-Role Keys**: The application only uses the public anonymous publishable key (`anonKey`). The service-role secret is never committed, stored, or bundled in the mobile binary.
- **No Embedded Passwords**: Passwords are sent directly to Supabase Auth over TLS and never stored locally or in plaintext.

---

## 2. Row-Level Security (RLS)
Every table containing player data has PostgreSQL Row-Level Security activated.
Example policy enforcement:
```sql
CREATE POLICY "Users can manage their villain encounters"
    ON public.villain_progress FOR ALL
    USING (auth.uid() = user_id);
```
Even if an attacker intercepts client requests or modifies local storage, they cannot read, overwrite, or delete another player's progress or match records on the server.

---

## 3. Offline Safety & Data Isolation
- Local storage distinguishes between guest player progress and authenticated player accounts.
- Local data validation prevents arbitrary XP injection or unauthorized character unlocks.
- All game simulation logic (combat, damage, health, collision) executes locally on-device without trusting arbitrary external parameters.
