package com.nivara.sync.worker

import android.content.Context
import androidx.work.*
import com.nivara.sync.data.local.PreferencesManager
import com.nivara.sync.data.local.SyncQueueManager
import com.nivara.sync.data.repository.HealthConnectRepository
import com.nivara.sync.data.repository.SyncRepository
import com.nivara.sync.data.repository.SyncResult
import java.time.Instant
import java.util.concurrent.TimeUnit

class BpSyncWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val ctx = applicationContext
        val prefs = PreferencesManager(ctx)
        val hcRepo = HealthConnectRepository(ctx)
        val syncRepo = SyncRepository(prefs, SyncQueueManager(ctx))

        if (prefs.patientId == null) return Result.success()
        if (!hcRepo.isHealthConnectAvailable()) return Result.retry()
        if (!hcRepo.hasPermissions()) return Result.retry()

        val lastSync = prefs.lastSyncTimestamp?.let { Instant.parse(it) }
        val readings = hcRepo.readNewBpReadings(afterTimestamp = lastSync)
        val result = syncRepo.syncReadings(readings)

        return if (result is SyncResult.Failure) Result.retry() else Result.success()
    }

    companion object {
        private const val WORK_NAME = "nivara_bp_sync"

        fun schedule(context: Context) {
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                PeriodicWorkRequestBuilder<BpSyncWorker>(4, TimeUnit.HOURS).build(),
            )
        }

        fun scheduleNow(context: Context) {
            WorkManager.getInstance(context).enqueue(
                OneTimeWorkRequestBuilder<BpSyncWorker>().build()
            )
        }
    }
}
