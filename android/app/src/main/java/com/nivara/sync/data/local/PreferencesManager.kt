package com.nivara.sync.data.local

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

private const val PREFS_FILE = "nivara_secure_prefs"
private const val KEY_PATIENT_ID = "patient_id"
private const val KEY_LAST_SYNC_TIMESTAMP = "last_sync_timestamp"
private const val KEY_LAST_BP_READING = "last_bp_reading"
private const val KEY_ONBOARDING_COMPLETE = "onboarding_complete"

class PreferencesManager(context: Context) {

    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    private val prefs: SharedPreferences = EncryptedSharedPreferences.create(
        context,
        PREFS_FILE,
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
    )

    var patientId: String?
        get() = prefs.getString(KEY_PATIENT_ID, null)
        set(value) = prefs.edit().putString(KEY_PATIENT_ID, value).apply()

    var lastSyncTimestamp: String?
        get() = prefs.getString(KEY_LAST_SYNC_TIMESTAMP, null)
        set(value) = prefs.edit().putString(KEY_LAST_SYNC_TIMESTAMP, value).apply()

    var lastBpReading: String?
        get() = prefs.getString(KEY_LAST_BP_READING, null)
        set(value) = prefs.edit().putString(KEY_LAST_BP_READING, value).apply()

    var onboardingComplete: Boolean
        get() = prefs.getBoolean(KEY_ONBOARDING_COMPLETE, false)
        set(value) = prefs.edit().putBoolean(KEY_ONBOARDING_COMPLETE, value).apply()
}
