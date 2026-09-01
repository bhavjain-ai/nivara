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

## Navigation

The app uses a persistent left-side icon rail (mirroring the physician web
dashboard's Sidebar) rather than a bottom tab bar:

- **Home** — time-of-day greeting, whether you've logged a reading today (with
  a prompt to take one if not), and a shortcut into My Health.
- **My Health** — your latest BP/glucose/HbA1c in large type, a trend chart
  under each, your 5 most recent readings with a "See More" for full history,
  and your medications.
- **Care Team** — coaching tier, outreach call log, SMART goals.
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
  ViewModels/                   VitalsStore (persisted history), PatientViewModel
  Views/                        RootView (left rail), Home, MyHealth, CareTeam,
                                 ContactUs, Devices, and history/detail screens
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
