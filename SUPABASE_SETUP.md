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

## 2. Run the schema

Open **SQL Editor** in the Supabase dashboard → **New query**, paste the
entire contents of [`supabase/migrations/0001_init.sql`](supabase/migrations/0001_init.sql),
and run it. This creates all the tables (patients, readings, medications,
care team, messages) and their Row Level Security policies in one shot.

(If you use the Supabase CLI instead: `supabase link --project-ref <ref>`
then `supabase db push`.)

Enable **Anonymous sign-ins**: **Authentication → Providers → Anonymous** →
turn it on. This is the patient app's entire auth mechanism — no email,
phone number, or OTP required.

## 3. Get your keys

**Project Settings → API**, you need three values:

| Value | Used by | Safe to expose? |
|---|---|---|
| Project URL | both apps | Yes |
| `anon` / publishable key | both apps | Yes — protected by RLS, not secrecy |
| `service_role` key | web app only, server-side | **No — never ship this in a client** |

## 4. Configure the web app (`src/`)

```bash
cp .env.local.example .env.local
```

Fill in `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, and
`SUPABASE_SERVICE_ROLE_KEY`. `.env.local` is already gitignored.

## 5. Configure the iOS app

```bash
cp ios/NivaraPatient/NivaraPatient/Services/SupabaseConfig.swift.example \
   ios/NivaraPatient/NivaraPatient/Services/SupabaseConfig.swift
```

Edit the new `SupabaseConfig.swift` (already gitignored — never commit real
keys) and fill in `urlString` and `anonKey`. Then regenerate the Xcode
project so it picks up the new Supabase Swift package dependency added to
`project.yml`:

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

## What's wired up vs. not

**Working end-to-end once configured:**
- Device-linked registration (no OTP) — `ios/.../Services/SupabaseService.swift`
- In-app Care Team chat, patient side — `ios/.../ViewModels/ChatViewModel.swift`,
  wired into `CareTeamConversationView`
- Sending a care-team-authored reply — `POST /api/messages` (web app, service-role)

**Not built yet:**
- The physician web dashboard still runs entirely on hardcoded mock data
  (`src/lib/mock-data.ts`) and a flat JSON file for live BP readings
  (`src/lib/reading-store.ts`) — neither reads from or writes to Supabase
  yet. Migrating the dashboard to real data is a separate, larger piece of
  work.
- `/api/messages` has **no authentication** — anyone who can reach it can
  post a message impersonating any patient's care team. It must be gated
  behind real staff login before it's exposed beyond your own machine. See
  the warning comment at the top of `src/app/api/messages/route.ts`.
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
