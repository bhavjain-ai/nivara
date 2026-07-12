# Nivara Sync — Android App

Lightweight Android app that reads blood pressure from Android Health Connect and syncs to the Nivara physician dashboard.

## Architecture

```
OMRON BP Cuff → OMRON Connect App → Android Health Connect → Nivara Sync → Nivara Backend API
```

## Requirements
- Android Studio Hedgehog (2023.1.1) or newer  
- JDK 17  
- Physical Android device running Android 10+ (API 29+)  
- Android Health Connect installed on the device  
- OMRON Connect app installed and paired with OMRON cuff  

> **Health Connect does NOT work on emulators.** A physical device is required.

## Setup

### 1. Set your backend URL
Edit `app/src/main/java/com/nivara/sync/data/remote/RetrofitClient.kt`:
```kotlin
private const val BASE_URL = "https://YOUR_DEPLOYED_NIVARA_URL/"
```

### 2. Open in Android Studio
`File → Open` → select the `android/` folder (not the root `nivara/` folder).

### 3. Run on device
- Connect Android phone via USB  
- Enable Developer Options → USB Debugging  
- Select device in Android Studio toolbar → click Run ▶

### 4. Test the flow
1. Launch Nivara Sync  
2. Enter your Patient ID (e.g. `P001`)  
3. Tap **Connect Health Data** → grant permissions  
4. Tap **Sync Now** to upload immediately  
5. Background sync runs every 4 hours automatically  

## API Endpoint
`POST /api/bp-reading`
```json
{ "patient_id": "P001", "systolic": 128, "diastolic": 82, "pulse": 72, "timestamp": "2026-07-12T12:00:00Z" }
```

## Security
- Patient ID stored in EncryptedSharedPreferences (AES-256-GCM)  
- HTTPS only (cleartext blocked by `network_security_config.xml`)  
- No API keys embedded in the app  
- Failed uploads queue locally and retry — no data loss on poor connectivity  
