package com.nivara.sync.ui.onboarding

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.nivara.sync.data.local.PreferencesManager
import com.nivara.sync.data.repository.HealthConnectRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class OnboardingUiState(
    val patientIdInput: String = "",
    val isHealthConnectAvailable: Boolean = false,
    val hasPermissions: Boolean = false,
    val errorMessage: String? = null,
)

class OnboardingViewModel(application: Application) : AndroidViewModel(application) {
    private val prefs = PreferencesManager(application)
    private val hcRepo = HealthConnectRepository(application)

    private val _uiState = MutableStateFlow(OnboardingUiState(
        isHealthConnectAvailable = hcRepo.isHealthConnectAvailable()
    ))
    val uiState: StateFlow<OnboardingUiState> = _uiState.asStateFlow()

    val permissionsRequired get() = hcRepo.requiredPermissions

    fun onPatientIdChanged(value: String) {
        _uiState.value = _uiState.value.copy(patientIdInput = value.trim().uppercase(), errorMessage = null)
    }

    fun savePatientId(): Boolean {
        val id = _uiState.value.patientIdInput
        if (id.length < 2) {
            _uiState.value = _uiState.value.copy(errorMessage = "Enter a valid enrollment code (e.g. P001)")
            return false
        }
        prefs.patientId = id
        return true
    }

    fun onPermissionsResult() {
        viewModelScope.launch {
            val granted = hcRepo.hasPermissions()
            if (granted) prefs.onboardingComplete = true
            _uiState.value = _uiState.value.copy(hasPermissions = granted)
        }
    }
}
