-- Clinic join codes — gate iOS registration so only a patient who was
-- actually given their clinic's code (at the visit, on a printed card,
-- etc.) can create an account, rather than anyone who finds the app on the
-- App Store and signs up claiming to belong to a clinic they don't.
--
-- The code itself must never be readable through an ordinary SELECT —
-- unlike `clinics.name` (already openly readable to any authenticated
-- session, see 0003_clinics_and_staff.sql/0004_clinics_staff_grants.sql), a
-- join code IS the access control, so it has to stay invisible to a direct
-- table query even though the rest of `clinics` stays readable. RLS alone
-- can't do this — `clinics_select_all` is `using (true)` and RLS is
-- row-level, not column-level — so this uses column-level GRANTs instead:
-- `authenticated` (patients + staff sessions alike) can SELECT id/name/
-- created_at, but not join_code.
--
-- A patient resolves a typed code to a clinic via
-- resolve_clinic_by_join_code() below, a SECURITY DEFINER function that can
-- read join_code internally without ever returning the code itself. Staff
-- view/rotate their own clinic's code through a service-role-backed API
-- route (src/app/api/clinic/join-code), the same pattern every other
-- staff-write path in this app already uses (see verify-clinic-access.ts)
-- — there's deliberately no client-side UPDATE policy on `clinics` either.

alter table clinics add column join_code text unique;

comment on column clinics.join_code is 'Code a patient enters during iOS onboarding to resolve + join this clinic. Not selectable by anon/authenticated — see the column grant below and resolve_clinic_by_join_code().';

-- 0004_clinics_staff_grants.sql granted `select` on every column to
-- `authenticated`; narrow that to exclude join_code specifically.
revoke select on clinics from authenticated;
grant select (id, name, created_at) on clinics to authenticated;

-- SECURITY DEFINER so it can read join_code — which the caller's own
-- `authenticated` role can no longer do directly as of the revoke above —
-- while only ever returning id/name, never the code itself. Empty result
-- (not an error) if the code matches nothing, same as any other lookup
-- miss; the iOS app treats an empty result as "invalid code."
create or replace function resolve_clinic_by_join_code(code text)
returns table(id uuid, name text)
language sql
security definer
set search_path = public
as $$
  select clinics.id, clinics.name
  from clinics
  where clinics.join_code = code;
$$;

grant execute on function resolve_clinic_by_join_code(text) to authenticated;

-- Seed initial codes for the two existing clinics so the feature works
-- immediately after this migration runs. Staff can view/rotate these any
-- time from Settings — see src/app/api/clinic/join-code.
update clinics set join_code = 'HEART-4K7Q' where name = 'Dr. Heart' and join_code is null;
update clinics set join_code = 'BDC-9X2MP' where name = 'Bangalore Diabetes Center' and join_code is null;
