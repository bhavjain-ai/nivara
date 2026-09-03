-- Nivara Health — initial schema
--
-- How to run this:
--   Dashboard: Supabase project → SQL Editor → New query → paste this file → Run.
--   CLI:       supabase link --project-ref <your-ref> && supabase db push
--
-- Auth model: patients authenticate via Supabase Anonymous Auth (no email,
-- phone, or OTP — see ios/NivaraPatient/NivaraPatient/Services/SupabaseService.swift).
-- Each patient row is linked to exactly one auth.users row via auth_user_id,
-- set once at registration (right after onboarding's consent step). Row
-- Level Security below scopes every table to "rows belonging to the calling
-- patient," so the public anon key baked into the app can never read or
-- write another patient's data.
--
-- Known limitation (documented, not silently shipped): the patients_update_own
-- policy below lets a patient edit any column on their own row, including
-- clinical fields (physician name, BP/HbA1c targets) that should really be
-- staff-set only. That's a self-tampering risk, not a cross-patient leak,
-- and is an acceptable gap for a pilot — but before this goes further,
-- clinical fields should move to a separate staff-only-writable table (or a
-- security-definer function that restricts which columns a patient can
-- touch) rather than living on the same row the patient can freely UPDATE.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Patients
-- ---------------------------------------------------------------------------
create table patients (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete cascade,
  device_identifier text unique, -- DeviceIdentity.current from the iOS app —
                                  -- a secondary fingerprint for support-assisted
                                  -- recovery if the auth session is ever lost,
                                  -- not the primary auth mechanism.
  first_name text not null,
  last_name text not null,
  date_of_birth date,
  physician_name text,
  physician_phone text,
  conditions text[] not null default '{}', -- e.g. {Hypertension,Diabetes}
  bp_target_systolic int,
  bp_target_diastolic int,
  bp_target_label text,
  hba1c_tier int,
  hba1c_target_label text,
  hba1c_target_value numeric,
  coaching_tier text,
  coaching_calls_completed int not null default 0,
  coaching_calls_target int not null default 0,
  share_with_family_member boolean not null default false,
  family_member_name text,
  family_member_relationship text,
  family_member_phone text,
  accepted_informed_consent_at timestamptz,
  accepted_privacy_consent_at timestamptz,
  created_at timestamptz not null default now()
);

comment on table patients is 'One row per enrolled patient; linked 1:1 to a Supabase Auth (anonymous) user.';

-- ---------------------------------------------------------------------------
-- Vitals
-- ---------------------------------------------------------------------------
create table glucose_readings (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references patients(id) on delete cascade,
  mg_dl int not null,
  sample_type text not null check (sample_type in ('fasting', 'post-meal')),
  source text not null default 'ble_device' check (source in ('ble_device', 'manual', 'demo')),
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table bp_readings (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references patients(id) on delete cascade,
  systolic int not null,
  diastolic int not null,
  pulse int,
  source text not null default 'ble_device' check (source in ('ble_device', 'manual', 'demo')),
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table hba1c_readings (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references patients(id) on delete cascade,
  value numeric not null,
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Medications — staff-set, patient can read but not write (see policies below)
-- ---------------------------------------------------------------------------
create table medications (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references patients(id) on delete cascade,
  name text not null,
  drug_class text not null,
  dose text not null,
  frequency text not null,
  start_date date not null,
  created_at timestamptz not null default now()
);

create table medication_changes (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references patients(id) on delete cascade,
  description text not null,
  related_condition text not null check (related_condition in ('Hypertension', 'Diabetes')),
  changed_at date not null,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Care team — also staff-set, patient read-only
-- ---------------------------------------------------------------------------
create table outreach_calls (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references patients(id) on delete cascade,
  coordinator_name text not null,
  coordinator_role text not null check (coordinator_role in ('Physician', 'Dietician', 'Coach')),
  call_type text not null,
  duration_min int,
  topics text[] not null default '{}',
  summary text not null,
  occurred_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table smart_goals (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references patients(id) on delete cascade,
  category text not null,
  description text not null,
  set_date date not null,
  target_date date not null,
  status text not null check (status in ('On Track', 'At Risk', 'Met', 'Partially Met', 'Not Met')),
  progress_note text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- In-app messaging (Care Team chat)
-- ---------------------------------------------------------------------------
create table messages (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references patients(id) on delete cascade,
  coordinator_role text not null check (coordinator_role in ('Physician', 'Dietician', 'Coach')),
  sender_type text not null check (sender_type in ('patient', 'care_team', 'ai_agent')),
  sender_name text not null,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

comment on table messages is 'One row per chat message. Threads are scoped by (patient_id, coordinator_role) — matches the three Care Team avatar threads in the iOS app.';

create index messages_patient_role_idx on messages (patient_id, coordinator_role, created_at);

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table patients enable row level security;
alter table glucose_readings enable row level security;
alter table bp_readings enable row level security;
alter table hba1c_readings enable row level security;
alter table medications enable row level security;
alter table medication_changes enable row level security;
alter table outreach_calls enable row level security;
alter table smart_goals enable row level security;
alter table messages enable row level security;

-- Patients: a signed-in (anonymous) user can see/update only their own row,
-- and can create exactly one row for themselves (registration).
create policy "patients_select_own" on patients
  for select using (auth.uid() = auth_user_id);
create policy "patients_insert_own" on patients
  for insert with check (auth.uid() = auth_user_id);
create policy "patients_update_own" on patients
  for update using (auth.uid() = auth_user_id);

-- Vitals: fully owned by the patient (they're the ones taking readings).
create policy "glucose_readings_owner" on glucose_readings
  for all using (patient_id in (select id from patients where auth_user_id = auth.uid()))
  with check (patient_id in (select id from patients where auth_user_id = auth.uid()));

create policy "bp_readings_owner" on bp_readings
  for all using (patient_id in (select id from patients where auth_user_id = auth.uid()))
  with check (patient_id in (select id from patients where auth_user_id = auth.uid()));

create policy "hba1c_readings_owner" on hba1c_readings
  for all using (patient_id in (select id from patients where auth_user_id = auth.uid()))
  with check (patient_id in (select id from patients where auth_user_id = auth.uid()));

-- Medications, care team, and goals: physician/coordinator-set. Patients can
-- read their own; writes come from a trusted backend using the service role
-- key (bypasses RLS), not from the patient's anon session.
create policy "medications_owner_read" on medications
  for select using (patient_id in (select id from patients where auth_user_id = auth.uid()));

create policy "medication_changes_owner_read" on medication_changes
  for select using (patient_id in (select id from patients where auth_user_id = auth.uid()));

create policy "outreach_calls_owner_read" on outreach_calls
  for select using (patient_id in (select id from patients where auth_user_id = auth.uid()));

create policy "smart_goals_owner_read" on smart_goals
  for select using (patient_id in (select id from patients where auth_user_id = auth.uid()));

-- Messages: a patient can read their own threads and insert messages as
-- themselves (sender_type = 'patient'). Care-team/AI-authored messages are
-- written by a trusted backend process using the service role key, not by a
-- patient's anon session — there's deliberately no policy allowing a client
-- to insert with sender_type other than 'patient'.
create policy "messages_owner_read" on messages
  for select using (patient_id in (select id from patients where auth_user_id = auth.uid()));
create policy "messages_patient_insert" on messages
  for insert with check (
    sender_type = 'patient'
    and patient_id in (select id from patients where auth_user_id = auth.uid())
  );

-- ---------------------------------------------------------------------------
-- Realtime: let clients subscribe to new messages in their own threads
-- (RLS above still applies to what a subscription can actually see).
-- ---------------------------------------------------------------------------
alter publication supabase_realtime add table messages;
