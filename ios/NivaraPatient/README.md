# Nivara — Patient iOS App

A patient-facing companion to the Nivara physician dashboard: shows a patient
their own blood pressure, glucose, HbA1c, medications, and care-team outreach,
and streams **live BP/glucose readings directly from BLE devices** — e.g. an
Accu-Chek Instant meter or a Bluetooth-enabled home BP cuff — over
CoreBluetooth. No manufacturer app or HealthKit involved.

> **This is a self-contained demo build.** Medications, targets, coaching
> outreach, and SMART goals are bundled locally in `Models/DemoPatientData.swift`
> (the same approach the web dashboard's `mock-data.ts` uses) rather than
> fetched from the Nivara backend. Only the BP/glucose vitals are "real" —
> they come from whatever BLE device you pair.

## Why this works without Accu-Chek's own app

Accu-Chek Instant meters implement the **Bluetooth SIG's standard Glucose
Profile** (Glucose Service, UUID `0x1808`) — the same publicly documented GATT
spec that apps like Glooko, mySugr, and Tidepool use to read glucose meters
directly. It's not a private or reverse-engineered protocol; any BLE central
(this app included) can discover the service, subscribe to the Glucose
Measurement characteristic (`0x2A18`), and get every reading the meter takes.
This app adds the analogous standard **Blood Pressure Profile** (`0x1810`) so
BLE-enabled home BP cuffs work the same way.

Devices that only support Bluetooth Classic (not BLE), or that use a fully
proprietary BLE protocol instead of these two standard profiles, won't be
discovered by this app — that's a limitation of the device, not something a
generic app can work around.

## Requirements

- A Mac with **Xcode 15+**
- iOS **16+** deployment target (uses Swift Charts, which needs iOS 16)
- A **physical iPhone** — Bluetooth doesn't work in the iOS Simulator, so you
  can't test live readings without real hardware
- A real BLE glucose meter (Accu-Chek Instant / Instant S) or BLE blood
  pressure cuff to test against, or use the app on its own with the bundled
  demo history

This repo does not include a `.xcodeproj` (hand-written Xcode project files
are brittle and easy to corrupt). Generate one with **XcodeGen**:

```bash
brew install xcodegen
cd ios/NivaraPatient
xcodegen generate
open NivaraPatient.xcodeproj
```

Then in Xcode: select your iPhone as the run destination and hit Run. On
first launch, iOS will prompt for Bluetooth permission (the usage strings are
already configured in `project.yml`).

### Manual setup (no XcodeGen)

1. In Xcode: **File → New → Project → iOS → App**, SwiftUI interface, name it
   `NivaraPatient`.
2. Delete the generated `ContentView.swift` and the default `...App.swift`.
3. Drag the `NivaraPatient/NivaraPatient` source folder (this repo) into the
   project navigator — check "Copy items if needed" and "Create groups".
4. In the target's **Info** tab, add two keys:
   - `Privacy - Bluetooth Always Usage Description`
   - `Privacy - Bluetooth Peripheral Usage Description`
   Both: *"Nivara uses Bluetooth to read live readings from your connected
   blood pressure cuff and glucose meter."*
5. Set the deployment target to iOS 16.0.

## First-run onboarding

On a fresh install (or after clearing app data), the app opens into a
5-phase guided setup instead of the main tabs — gated by
`OnboardingStore.isComplete` (UserDefaults) in `NivaraPatientApp.swift`:

1. **Welcome** — branded intro screen.
2. **Basic info** — first name, last name, date of birth.
3. **Consent** — both consent documents (Informed Consent & Service
   Disclosure, and Data Use & Privacy Consent) as summary cards with a
   "Read full consent" link to the complete text, each requiring its own
   acceptance; plus the optional family-sharing opt-in (name, relationship,
   and phone number — required once the opt-in is on, so the care team has
   an actual way to reach that person). Each document's "I agree" toggle
   stays disabled until the patient has scrolled to the bottom of that
   document's full text in its sheet, checked fresh every time this screen
   is (re)entered. Full text lives in `Models/ConsentDocuments.swift`.
4. **Device setup** — a 5-step walkthrough (gather supplies → turn on
   Bluetooth → connect the meter → confirm connection → take a first
   reading) that drives the *same* `BLEManager`/`PatientViewModel` the rest
   of the app uses, so a device paired here is already connected once you
   reach Home. Each hardware-dependent step has a "Skip for now" escape
   hatch. This is real BLE, not a scripted demo.
5. **Complete** — if a reading came in during step 4, a dynamic
   confirmation ("Your blood glucose is 90 mg/dL, which is within range.
   Great job!"); otherwise a generic welcome.

The name collected in step 2 becomes the Home screen's greeting name
(falling back to the bundled demo patient's name if onboarding was
skipped). This does not replace the bundled clinical profile (targets,
medications, care team) — that's still physician-set demo data from
`DemoPatientData.swift`, matching this build's self-contained-demo scope
described below.

To see onboarding again on a device that's already completed it, delete
and reinstall the app (there's no in-app reset switch).

## Device identity (no SMS/OTP)

`Services/DeviceIdentity.swift` mints a random UUID on first launch and
stores it in the iOS Keychain — unlike UserDefaults or the Documents
directory, Keychain data survives the app being deleted and reinstalled.
This is the client-side building block for linking an account to "this
device" the way WhatsApp links to a phone number, without standing up an
SMS/OTP provider: a backend registration endpoint would receive this value
once at enrollment and recognize the device on later launches. There's no
backend in this repo yet, so nothing currently sends it anywhere — it's
surfaced read-only on the Contact Us page (`deviceInfoCard`) for now. See
the doc comment on `DeviceIdentity` for what this is (and isn't) — notably,
it's not `identifierForVendor` (which resets on reinstall, defeating the
point) and it's not a fraud-proof hardware attestation (pair it with
Apple's DeviceCheck/App Attest server-side if that's needed later).

## Navigation

The app uses a persistent left-side icon rail (mirroring the physician web
dashboard's Sidebar) rather than a bottom tab bar:

- **Home** — time-of-day greeting, whether you've logged a reading today (with
  a prompt to take one if not), a warm status-aware message right after a
  fresh reading comes in, and a shortcut into My Health.
- **My Health** — scoped to the initial (Type 2 diabetes) patient population:
  HbA1c and fasting blood glucose only. Each shows the latest result in large
  type, a trend chart, your 5 most recent readings, and a "See More" for full
  history. Blood pressure support still exists end-to-end (BLE parsing,
  guidelines, history views) for when the hypertension population launches —
  it's just not surfaced on this page yet.
- **Medications** — your current Type 2 diabetes regimen in large type, with
  a "Recent Changes" history underneath so it's obvious what's different.
- **Care Team** — your physician, dietician, and coach as tappable avatar
  cards; each opens a chat-thread-style read of every logged contact with
  that person. A "Got a Question? Contact Us" button and your SMART goals
  sit below.
- **Contact Us** — physician, care coordinator, and Nivara support, each with
  a tap-to-call/email button.

Device pairing (Devices screen) is reached from Home's "Take a Measurement"
prompt or the antenna icon on My Health, rather than being its own rail tab.

## Project layout

```
NivaraPatient/
  NivaraPatientApp.swift        App entry
  Models/                       Vital + patient data models, bundled demo patient
  Guidelines/                   Swift port of the web dashboard's clinical logic
                                 (individualized BP/glucose/HbA1c targets)
  Bluetooth/
    GATTConstants.swift         Standard service/characteristic UUIDs
    IEEE11073.swift             SFLOAT decoder (the numeric format GATT health
                                 profiles use for concentration/pressure/pulse)
    GATTDataHelpers.swift       Little-endian + Bluetooth "Date Time" parsing
    GlucoseMeasurementParser.swift
    BloodPressureMeasurementParser.swift
    BLEManager.swift            CoreBluetooth scan/connect/subscribe + parsing
  ViewModels/                   VitalsStore (persisted history), PatientViewModel,
                                 OnboardingStore (first-run flow state)
  Views/                        RootView (left rail), Home, MyHealth, CareTeam,
                                 ContactUs, Devices, and history/detail screens
  Views/Onboarding/              Welcome, basic info, consent, guided device
                                 setup, and completion screens
  Theme/                        Cream + forest green palette matching the
                                 Nivara brand (pitch deck / promotional materials)
```

## Testing with a real device

1. Turn on your Accu-Chek Instant (or BLE BP cuff) and make sure it's not
   already connected to its own app / phone.
2. In Nivara, go to **Devices → Scan for Devices**.
3. Tap your device in the list, then wait for "Connected to …".
4. On connect, the app requests the meter's **last stored record** (Record
   Access Control Point, "last record" operator) so you see a reading right
   away.
5. Take a fresh test strip reading (or a fresh cuff reading) while still
   connected — the meter pushes it live, and it should appear on the Home tab
   within a second or two, with the "New reading synced" banner.

### Fasting vs. post-meal is a best-effort guess

The Glucose Measurement characteristic doesn't carry an explicit "fasting"
flag. The app infers post-meal only when the meter also sends a Glucose
Measurement Context record with a "Meal" field populated; otherwise it
defaults to fasting. If a meter doesn't send context records at all (many
don't), every reading will show as fasting — retag the latest one from the
Blood Glucose section of My Health if that's wrong. This mirrors how most
consumer diabetes apps handle it.

## What's not wired up yet

- No login / multi-patient support — this build is one bundled demo patient.
- No sync back to the Nivara backend — readings are stored locally
  (`Documents/bp_readings.json`, `glucose_readings.json`) via `VitalsStore`.
  Wiring that up would mean POSTing to something like `/api/bp-reading` (which
  already exists in the web app) plus a glucose equivalent, and adding a way
  to identify which patient this device belongs to.
- Physician-facing titration/escalation logic (from the web dashboard's
  `htn-titration.ts` / `diabetes-titration.ts`) intentionally isn't exposed
  here — recommending medication changes to a patient directly isn't
  appropriate; this app shows targets and status, not treatment
  recommendations.
