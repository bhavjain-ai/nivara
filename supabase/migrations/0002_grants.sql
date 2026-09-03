-- Explicit Data API grants
--
-- Needed because this project has "Automatically expose new tables" turned
-- OFF (Project Settings → API → Data API) — the safer, explicit option
-- Supabase itself recommends, and the one that matches the least-privilege
-- approach the RLS policies in 0001_init.sql already take. With that
-- setting off, Postgres denies access at the GRANT level before RLS is
-- ever evaluated, so every table needs an explicit grant here or none of
-- those policies are reachable at all — RLS narrows down WHICH rows a
-- role can touch, it doesn't grant access to the table in the first place.
--
-- If your project instead has "Automatically expose new tables" ON, this
-- migration is redundant but harmless — re-granting the same privileges
-- doesn't change anything.
--
-- Role notes:
--   - `authenticated` is the Postgres role for BOTH email/password users
--     and Supabase Anonymous Auth sessions (anonymous sign-in still issues
--     a real JWT) — every patient-facing grant below targets this role.
--     auth.uid() inside the RLS policies works identically for both.
--   - `anon` (a request carrying no session at all) gets nothing on any of
--     these tables — there's no legitimate unauthenticated access to
--     patient data in this schema.
--   - `service_role` bypasses RLS entirely and is used only by trusted
--     server-side code (the Next.js app's src/lib/supabase-admin.ts) — for
--     example, inserting a care-team-authored chat reply, which RLS
--     otherwise blocks from a patient's own session. Granted full table
--     privileges here so that path keeps working.

grant usage on schema public to authenticated, service_role;

grant select, insert, update on patients to authenticated;
grant all on patients to service_role;

grant select, insert, update, delete on glucose_readings to authenticated;
grant all on glucose_readings to service_role;

grant select, insert, update, delete on bp_readings to authenticated;
grant all on bp_readings to service_role;

grant select, insert, update, delete on hba1c_readings to authenticated;
grant all on hba1c_readings to service_role;

grant select on medications to authenticated;
grant all on medications to service_role;

grant select on medication_changes to authenticated;
grant all on medication_changes to service_role;

grant select on outreach_calls to authenticated;
grant all on outreach_calls to service_role;

grant select on smart_goals to authenticated;
grant all on smart_goals to service_role;

grant select, insert on messages to authenticated;
grant all on messages to service_role;
