package com.nivara.sync.data.repository

import com.nivara.sync.data.local.PreferencesManager
import com.nivara.sync.data.local.SyncQueueManager
import com.nivara.sync.data.remote.RetrofitClient
import com.nivara.sync.data.remote.models.BpReadingRequest
import com.nivara.sync.domain.model.BpReading
import kotlinx.coroutines.delay

sealed class SyncResult {
    data class Success(val uploadedCount: Int) : SyncResult()
    data class PartialSuccess(val uploadedCount: Int, val failedCount: Int) : SyncResult()
    data class Failure(val error: String) : SyncResult()
}

class SyncRepository(
    private val prefs: PreferencesManager,
    private val queue: SyncQueueManager,
) {
    private val api = RetrofitClient.apiService

    suspend fun syncReadings(newReadings: List<BpReading>): SyncResult {
        val patientId = prefs.patientId ?: return SyncResult.Failure("No patient ID configured")
        val allReadings = (queue.getAll() + newReadings).distinctBy { it.timestamp }
        if (allReadings.isEmpty()) return SyncResult.Success(0)

        var uploaded = 0
        var failed = 0

        for (reading in allReadings) {
            if (uploadWithRetry(patientId, reading)) {
                uploaded++
                queue.remove(reading)
                if (prefs.lastSyncTimestamp == null || reading.timestamp > prefs.lastSyncTimestamp!!) {
                    prefs.lastSyncTimestamp = reading.timestamp
                }
                prefs.lastBpReading = "${reading.systolic}/${reading.diastolic} mmHg"
            } else {
                failed++
                queue.enqueue(reading)
            }
        }

        return when {
            failed == 0 -> SyncResult.Success(uploaded)
            uploaded == 0 -> SyncResult.Failure("All $failed readings failed to upload")
            else -> SyncResult.PartialSuccess(uploaded, failed)
        }
    }

    private suspend fun uploadWithRetry(patientId: String, reading: BpReading): Boolean {
        val request = BpReadingRequest(patientId, reading.systolic, reading.diastolic, reading.pulse, reading.timestamp)
        repeat(3) { attempt ->
            try {
                val response = api.uploadBpReading(request)
                if (response.isSuccessful && response.body()?.success == true) return true
            } catch (_: Exception) {}
            delay(500L * (attempt + 1))
        }
        return false
    }
}
