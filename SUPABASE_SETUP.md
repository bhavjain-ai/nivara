# Supabase setup

This is the shared backend for the Nivara Health patient app (`ios/`) and,
eventually, the physician web dashboard (`src/`) — a real Postgres database
with Row Level Security, used for device-linked patient registration
(replacing an SMS/OTP flow) and the in-app Care Team chat feature. Neither
app hard-requires this to be set up — both keep working on local/demo data
if you skip this entirely.

## 1. Create the project

1. Go to [supabase.com](https://supabase.com) and create a free account if
   you don't have one.
2. Create a new project. Pick a region — for patient health data, prefer a
   region consistent with your data-residency requirements (this pilot's
   consent documents reference India's IT Rules 2011 and the DPDP Act; check
   which regions are available on the tier you're on before committing).
3. Wait for provisioning to finish (a couple of minutes).

## 2. Data API settings

**Project Settings → API → Data API**, three toggles:

- **Enable Data API** — must be **ON**. Everything below depends on it.
- **Automatically expose new tables** — recommend **OFF**. This is
  Supabase's own recommendation, and it matches the least-privilege
  approach the RLS policies below already take: with it off, a table has
  no API access at all until explicitly granted, rather than being wide
  open (narrowed only by RLS) the moment it's created. **If you turn this
  off, you must run migration 0002 below — it's the explicit grants this
  setting would otherwise have handled automatically, and without it every
  RLS policy is unreachable (denied at the grant level, before RLS is even
  evaluated).** If you leave it ON instead, 0002 is redundant but harmless
  to run anyway.
- **Enable automatic RLS** — recommend **ON**. A safety net that
  auto-enables Row Level Security on any table you add later that forgets
  to do it explicitly. Doesn't affect the tables below — 0001 already
  enables RLS on each one itself.

## 3. Run the schema

Open **SQL Editor** in the Supabase dashboard → **New query**, run these in
order:

1. [`supabase/migrations/0001_init.sql`](supabase/migrations/0001_init.sql) —
   all tables (patients, readings, medications, care team, messages) and
   their Row Level Security policies.
2. [`supabase/migrations/0002_grants.sql`](supabase/migrations/0002_grants.sql) —
   explicit Data API grants, required if you turned off "Automatically
   expose new tables" above (see that section for why).
3. [`supabase/migrations/0003_clinics_and_staff.sql`](supabase/migrations/0003_clinics_and_staff.sql) —
   `clinics` + `staff` tables, `patients.clinic_id`, and the RLS policies
   that let staff see only their own clinic's patients (or every clinic,
   for a super-admin). Seeds the two clinics (Dr. Heart, Bangalore Diabetes
   Center) as rows.
4. [`supabase/migrations/0004_clinics_staff_grants.sql`](supabase/migrations/0004_clinics_staff_grants.sql) —
   same "Automatically expose new tables" caveat as 0002, for the two new
   tables.

(If you use the Supabase CLI instead: `supabase link --project-ref <ref>`
then `supabase db push` runs every migration in order.)

Enable **Anonymous sign-ins**: **Authentication → Providers → Anonymous** →
turn it on. This is the patient app's entire auth mechanism — no email,
phone number, or OTP required.

## 4. Get your keys

**Project Settings → API**, you need three values:

| Value | Used by | Safe to expose? |
|---|---|---|
| Project URL | both apps | Yes |
| `anon` / publishable key | both apps | Yes — protected by RLS, not secrecy |
| `service_role` key | web app only, server-side | **No — never ship this in a client** |

## 5. Configure the web app (`src/`)

```bash
cp .env.local.example .env.local
```

Fill in `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, and
`SUPABASE_SERVICE_ROLE_KEY`. `.env.local` is already gitignored.

## 6. Configure the iOS app

`ios/NivaraPatient/NivaraPatient/Services/SupabaseConfig.swift` already
exists and is committed — but only with placeholder values, deliberately,
so a fresh checkout (or Xcode Cloud) has something real to compile against
without anyone's actual keys in git. Fill in your real `urlString` and
`anonKey`, then immediately tell git to stop tracking further edits to
this file so your keys can't get committed by accident:

```bash
# after editing urlString/anonKey in SupabaseConfig.swift:
git update-index --skip-worktree ios/NivaraPatient/NivaraPatient/Services/SupabaseConfig.swift
```

(`git update-index --no-skip-worktree` on the same path undoes this, if
you ever need to intentionally change the committed placeholder itself.)

If `project.yml` changed since you last opened the project, regenerate:

```bash
cd ios/NivaraPatient
xcodegen generate
open NivaraPatient.xcodeproj
```

Build and run. On first launch, complete onboarding through to "Go to
Nivara" — that's what triggers registration (anonymous sign-in + creating
your `patients` row, linked to `DeviceIdentity.current`). You can confirm it
worked by checking the `patients` table in the Supabase dashboard's Table
Editor.

## 7. Create staff logins (dashboard access, clinic isolation)

The physician dashboard now requires a real login — see
[`supabase/migrations/0003_clinics_and_staff.sql`](supabase/migrations/0003_clinics_and_staff.sql).
There's deliberately **no self-service signup**: a public signup form on a
clinical dashboard would let anyone mint themselves access to patient data.
Accounts are created by hand, by you, as follows.

**For each person who needs dashboard access** (one per clinic staff
member, plus yourself as super-admin):

1. **Supabase Dashboard → Authentication → Users → Add user.** Set their
   email and a password, and toggle **Auto Confirm User** — there's no
   email-sending configured, so without this they'd never be able to
   confirm their account.
2. Copy the new user's **UID** (shown in the Users table, or click into the
   user).
3. **SQL Editor → New query**, run (swap in the real UID, name, and which
   clinic):

   ```sql
   -- Clinic-scoped staff member:
   insert into staff (auth_user_id, clinic_id, name, role)
   values (
     '00000000-0000-0000-0000-000000000000', -- paste the UID from step 2
     (select id from clinics where name = 'Dr. Heart'), -- or 'Bangalore Diabetes Center'
     'Dr. Jane Doe',
     'Physician'
   );

   -- Super-admin (sees every clinic) — clinic_id stays null:
   insert into staff (auth_user_id, clinic_id, name, role)
   values (
     '00000000-0000-0000-0000-000000000000',
     null,
     'Bhav Jain',
     'Admin'
   );
   ```

4. They can now sign in at `/login` with the email/password from step 1.

**Assigning real patients to a clinic:** the iOS app's onboarding now has a
clinic picker (fetches from the `clinics` table), so new registrations set
`clinic_id` themselves. Any patient registered *before* this shipped — like
the first real pilot patient — has `clinic_id = null`, which only a
super-admin can see. Backfill those manually:

```sql
update patients
set clinic_id = (select id from clinics where name = 'Dr. Heart')
where id = '00000000-0000-0000-0000-000000000000'; -- the patient's id
```

## What's wired up vs. not

**Working end-to-end once configured:**
- Device-linked registration (no OTP), with a clinic picker — `ios/.../Services/SupabaseService.swift`
- In-app Care Team chat, patient side — `ios/.../ViewModels/ChatViewModel.swift`,
  wired into `CareTeamConversationView`
- Real BP/glucose readings syncing from the iOS app to Supabase and showing
  up live on the dashboard — `ios/.../Services/SupabaseService.swift`
  (`pushBPReading`/`pushGlucoseReading`), `src/lib/supabase-live.ts`,
  `/api/patients/live`
- Staff login (`/login`) with clinic-scoped data access, enforced by Row
  Level Security — `src/middleware.ts`, `src/lib/current-staff.ts`,
  `supabase/migrations/0003_clinics_and_staff.sql`. A super-admin (staff
  row with `clinic_id = null`) sees every clinic; everyone else sees only
  their own.
- Sending a care-team-authored reply — `POST /api/messages` (requires a
  staff session; verifies the target patient is in that staff member's
  clinic before using the service-role client to insert)

**Not built yet:**
- The physician web dashboard's **10 demo patients** are still hardcoded
  mock data (`src/lib/mock-data.ts`), split 5/5 across the two clinics for
  a realistic-looking demo — they aren't real Supabase rows and don't go
  through RLS, just a client-side `clinicName` filter.
- Column-level restrictions on the `patients` table: a patient can currently
  edit any column on their own row via a direct API call, including
  clinical fields (physician name, BP/HbA1c targets) that should really be
  staff-set only. Bounded to self-tampering (not a cross-patient leak), but
  worth fixing — split clinical fields into a staff-only-writable table, or
  add a security-definer function restricting which columns a patient can
  touch — before this goes further than a pilot.
- Glucose/BP/HbA1c readings, medications, and care-team history are all
  still local-only on the iOS side (VitalsStore, DemoPatientData) — the
  schema supports syncing them, but that sync isn't built yet.
