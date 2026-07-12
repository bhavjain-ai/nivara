package com.nivara.sync.ui.home

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.nivara.sync.data.local.PreferencesManager
import com.nivara.sync.data.local.SyncQueueManager
import com.nivara.sync.data.repository.HealthConnectRepository
import com.nivara.sync.data.repository.SyncRepository
import com.nivara.sync.data.repository.SyncResult
import com.nivara.sync.worker.BpSyncWorker
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

data class HomeUiState(
    val patientId: String = "",
    val isConnected: Boolean = false,
    val lastSyncTime: String = "Never synced",
    val lastBpReading: String = "—",
    val pendingQueueCount: Int = 0,
    val isSyncing: Boolean = false,
    val syncMessage: String? = null,
)

class HomeViewModel(application: Application) : AndroidViewModel(application) {
    private val prefs = PreferencesManager(application)
    private val hcRepo = HealthConnectRepository(application)
    private val queue = SyncQueueManager(application)
    private val syncRepo = SyncRepository(prefs, queue)
    private val fmt = DateTimeFormatter.ofPattern("dd MMM yyyy, hh:mm a").withZone(ZoneId.systemDefault())

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    init { loadState() }

    fun loadState() {
        viewModelScope.launch {
            val lastSync = prefs.lastSyncTimestamp?.let { runCatching { fmt.format(Instant.parse(it)) }.getOrNull() } ?: "Never synced"
            _uiState.value = HomeUiState(
                patientId = prefs.patientId ?: "—",
                isConnected = hcRepo.hasPermissions(),
                lastSyncTime = lastSync,
                lastBpReading = prefs.lastBpReading ?: "—",
                pendingQueueCount = queue.getAll().size,
            )
        }
    }

    fun syncNow() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isSyncing = true, syncMessage = null)
            try {
                val lastSync = prefs.lastSyncTimestamp?.let { Instant.parse(it) }
                val readings = hcRepo.readNewBpReadings(afterTimestamp = lastSync)
                val message = when (val result = syncRepo.syncReadings(readings)) {
                    is SyncResult.Success -> if (result.uploadedCount == 0) "Already up to date" else "✓ Uploaded ${result.uploadedCount} reading(s)"
                    is SyncResult.PartialSuccess -> "Uploaded ${result.uploadedCount}, ${result.failedCount} queued for retry"
                    is SyncResult.Failure -> "Sync failed: ${result.error}"
                }
                _uiState.value = _uiState.value.copy(syncMessage = message)
                loadState()
            } finally {
                _uiState.value = _uiState.value.copy(isSyncing = false)
            }
        }
    }
}
