-- Explicit Data API grants for clinics/staff (see 0002_grants.sql for why
-- these are needed — "Automatically expose new tables" is OFF on this
-- project, so GRANTs are required before RLS is ever evaluated).

grant select on clinics to authenticated;
grant all on clinics to service_role;

grant select on staff to authenticated;
grant all on staff to service_role;

-- The staff-visibility RLS policies added in 0003 require staff to be able
-- to read patients.clinic_id and every clinical table's rows for patients
-- outside their own anon session — the base grants from 0002_grants.sql
-- already cover `select` on all of these for `authenticated`, so nothing
-- else changes here.
