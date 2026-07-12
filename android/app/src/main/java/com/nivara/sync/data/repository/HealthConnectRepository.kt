package com.nivara.sync.data.repository

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.BloodPressureRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import com.nivara.sync.domain.model.BpReading
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

class HealthConnectRepository(private val context: Context) {

    val requiredPermissions = setOf(
        HealthPermission.getReadPermission(BloodPressureRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
    )

    fun isHealthConnectAvailable(): Boolean =
        HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE

    private fun getClient(): HealthConnectClient = HealthConnectClient.getOrCreate(context)

    suspend fun hasPermissions(): Boolean = withContext(Dispatchers.IO) {
        if (!isHealthConnectAvailable()) return@withContext false
        getClient().permissionController.getGrantedPermissions().containsAll(requiredPermissions)
    }

    suspend fun readNewBpReadings(afterTimestamp: Instant?): List<BpReading> = withContext(Dispatchers.IO) {
        if (!isHealthConnectAvailable()) return@withContext emptyList()
        val client = getClient()
        val startTime = afterTimestamp ?: Instant.now().minusSeconds(30L * 24 * 3600)
        val endTime = Instant.now()

        val bpRecords = client.readRecords(
            ReadRecordsRequest(BloodPressureRecord::class, TimeRangeFilter.between(startTime, endTime))
        ).records

        val hrRecords = client.readRecords(
            ReadRecordsRequest(HeartRateRecord::class, TimeRangeFilter.between(startTime, endTime))
        ).records

        val hrByMinute = hrRecords
            .flatMap { it.samples }
            .groupBy { it.time.epochSecond / 60 }
            .mapValues { (_, s) -> s.map { it.beatsPerMinute }.average().toInt() }

        bpRecords.map { r ->
            BpReading(
                systolic = r.systolic.inMillimetersOfMercury.toInt(),
                diastolic = r.diastolic.inMillimetersOfMercury.toInt(),
                pulse = hrByMinute[r.time.epochSecond / 60],
                timestamp = DateTimeFormatter.ISO_INSTANT.format(r.time.atZone(ZoneOffset.UTC)),
            )
        }.sortedBy { it.timestamp }
    }
}
