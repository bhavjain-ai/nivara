-- Multi-clinic staff accounts and clinic-scoped patient visibility
--
-- Context: the physician dashboard originally had no login at all — every
-- page read through the service-role key, which bypasses RLS and sees every
-- patient regardless of clinic. Two real clinics (Dr. Heart, Bangalore
-- Diabetes Center) now use this pilot and must not see each other's
-- patients, so this migration adds:
--   - `clinics`: one row per clinic.
--   - `staff`: one row per dashboard login, linked 1:1 to a real (non-
--     anonymous) Supabase Auth user. `clinic_id = null` means super-admin
--     (sees every clinic) — there is no separate "admin" table/flag; a null
--     clinic IS the admin case, checked everywhere below.
--   - `patients.clinic_id`: which clinic a real (iOS-registered) patient
--     belongs to. Nullable because existing patients registered before this
--     column existed don't have one yet — assign it manually via SQL (see
--     SUPABASE_SETUP.md) until the iOS clinic picker ships.
--
-- Staff accounts are NOT self-service. There is deliberately no signup flow
-- or INSERT policy on `staff` for the `authenticated` role — accounts are
-- created by hand (Supabase Dashboard → Authentication → Add user, then a
-- SQL insert into `staff`), documented in SUPABASE_SETUP.md. A public
-- signup form for a clinical dashboard would let anyone mint themselves
-- access to patient data.
--
-- How clinic isolation actually works: every clinical table already has an
-- RLS policy letting a patient's own anon session see their own rows
-- (0001_init.sql). This migration adds a SECOND, independent SELECT policy
-- to each of those tables for staff — Postgres OR's multiple permissive
-- policies together, so a row is visible if EITHER policy matches. A
-- patient still only ever sees their own data; staff see every patient
-- whose clinic_id matches their own staff row's clinic_id (or everything,
-- if their clinic_id is null).

create table clinics (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

comment on table clinics is 'One row per clinic using the pilot. Readable by any authenticated session (patients + staff) — just names, not sensitive.';

insert into clinics (name) values
  ('Dr. Heart'),
  ('Bangalore Diabetes Center')
on conflict (name) do nothing;

create table staff (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique not null references auth.users(id) on delete cascade,
  clinic_id uuid references clinics(id) on delete restrict, -- null = super-admin, sees every clinic
  name text not null,
  role text not null default 'Physician',
  created_at timestamptz not null default now()
);

comment on table staff is 'One row per dashboard login. clinic_id = null means super-admin (sees all clinics). Rows are created by hand, not via self-service signup — see SUPABASE_SETUP.md.';

alter table patients add column clinic_id uuid references clinics(id) on delete set null;

comment on column patients.clinic_id is 'Which clinic this real (iOS-registered) patient belongs to. Null for patients registered before this column existed — backfill manually until the iOS clinic picker ships.';

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table clinics enable row level security;
alter table staff enable row level security;

create policy "clinics_select_all" on clinics
  for select using (true);

create policy "staff_select_own" on staff
  for select using (auth_user_id = auth.uid());

-- Staff visibility into patients + every clinical table, clinic-scoped.
-- These are ADDITIONAL permissive SELECT policies alongside each table's
-- existing patient-owner policy from 0001_init.sql — a row is visible if
-- either policy matches.

create policy "patients_staff_select" on patients
  for select using (
    exists (
      select 1 from staff s
      where s.auth_user_id = auth.uid()
        and (s.clinic_id is null or s.clinic_id = patients.clinic_id)
    )
  );

create policy "glucose_readings_staff_select" on glucose_readings
  for select using (
    exists (
      select 1 from staff s
      join patients p on p.id = glucose_readings.patient_id
      where s.auth_user_id = auth.uid()
        and (s.clinic_id is null or s.clinic_id = p.clinic_id)
    )
  );

create policy "bp_readings_staff_select" on bp_readings
  for select using (
    exists (
      select 1 from staff s
      join patients p on p.id = bp_readings.patient_id
      where s.auth_user_id = auth.uid()
        and (s.clinic_id is null or s.clinic_id = p.clinic_id)
    )
  );

create policy "hba1c_readings_staff_select" on hba1c_readings
  for select using (
    exists (
      select 1 from staff s
      join patients p on p.id = hba1c_readings.patient_id
      where s.auth_user_id = auth.uid()
        and (s.clinic_id is null or s.clinic_id = p.clinic_id)
    )
  );

create policy "medications_staff_select" on medications
  for select using (
    exists (
      select 1 from staff s
      join patients p on p.id = medications.patient_id
      where s.auth_user_id = auth.uid()
        and (s.clinic_id is null or s.clinic_id = p.clinic_id)
    )
  );

create policy "medication_changes_staff_select" on medication_changes
  for select using (
    exists (
      select 1 from staff s
      join patients p on p.id = medication_changes.patient_id
      where s.auth_user_id = auth.uid()
        and (s.clinic_id is null or s.clinic_id = p.clinic_id)
    )
  );

create policy "outreach_calls_staff_select" on outreach_calls
  for select using (
    exists (
      select 1 from staff s
      join patients p on p.id = outreach_calls.patient_id
      where s.auth_user_id = auth.uid()
        and (s.clinic_id is null or s.clinic_id = p.clinic_id)
    )
  );

create policy "smart_goals_staff_select" on smart_goals
  for select using (
    exists (
      select 1 from staff s
      join patients p on p.id = smart_goals.patient_id
      where s.auth_user_id = auth.uid()
        and (s.clinic_id is null or s.clinic_id = p.clinic_id)
    )
  );

create policy "messages_staff_select" on messages
  for select using (
    exists (
      select 1 from staff s
      join patients p on p.id = messages.patient_id
      where s.auth_user_id = auth.uid()
        and (s.clinic_id is null or s.clinic_id = p.clinic_id)
    )
  );
