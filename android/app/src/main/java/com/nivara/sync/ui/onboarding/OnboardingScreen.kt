package com.nivara.sync.ui.onboarding

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.health.connect.client.PermissionController
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.viewmodel.compose.viewModel
import com.nivara.sync.ui.theme.*

@Composable
fun OnboardingScreen(
    onOnboardingComplete: () -> Unit,
    viewModel: OnboardingViewModel = viewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()
    val keyboard = LocalSoftwareKeyboardController.current
    val lifecycleOwner = LocalLifecycleOwner.current

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) viewModel.refreshAvailability()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = PermissionController.createRequestPermissionResultContract(),
    ) {
        viewModel.onPermissionsResult()
    }

    LaunchedEffect(uiState.hasPermissions) {
        if (uiState.hasPermissions) onOnboardingComplete()
    }

    Column(
        modifier = Modifier.fillMaxSize().background(SurfaceGray).padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(
            modifier = Modifier.size(80.dp).clip(RoundedCornerShape(20.dp)).background(NivaraBlue),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Default.Favorite, contentDescription = null, tint = Color.White, modifier = Modifier.size(44.dp))
        }

        Spacer(Modifier.height(24.dp))
        Text("Nivara Health Sync", style = MaterialTheme.typography.headlineMedium, color = NivaraBlue)
        Text("Blood Pressure Monitoring", style = MaterialTheme.typography.bodyMedium, color = Color.Gray, modifier = Modifier.padding(top = 4.dp))
        Spacer(Modifier.height(40.dp))

        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = Color.White),
            elevation = CardDefaults.cardElevation(2.dp),
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                Text("Step 1 — Enter your enrollment code", style = MaterialTheme.typography.titleMedium, color = NivaraBlue)
                Spacer(Modifier.height(12.dp))
                OutlinedTextField(
                    value = uiState.patientIdInput,
                    onValueChange = viewModel::onPatientIdChanged,
                    label = { Text("Patient Enrollment Code") },
                    placeholder = { Text("e.g. P001") },
                    isError = uiState.errorMessage != null,
                    supportingText = uiState.errorMessage?.let { { Text(it, color = MaterialTheme.colorScheme.error) } },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters, imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { keyboard?.hide() }),
                    shape = RoundedCornerShape(12.dp),
                )
            }
        }

        Spacer(Modifier.height(16.dp))

        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = Color.White),
            elevation = CardDefaults.cardElevation(2.dp),
        ) {
            Column(modifier = Modifier.padding(20.dp)) {
                Text("Step 2 — Connect Health Data", style = MaterialTheme.typography.titleMedium, color = NivaraBlue)
                Spacer(Modifier.height(8.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Lock, contentDescription = null, tint = Color.Gray, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.width(6.dp))
                    Text(
                        "Only blood pressure data is accessed. Nothing else is read or stored without your consent.",
                        style = MaterialTheme.typography.bodyMedium, color = Color.Gray,
                    )
                }
                if (!uiState.isHealthConnectAvailable) {
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "⚠ Health Connect is not installed. Please install it from the Play Store.",
                        style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.error,
                    )
                }
            }
        }

        Spacer(Modifier.height(32.dp))

        Button(
            onClick = {
                keyboard?.hide()
                if (viewModel.savePatientId()) {
                    permissionLauncher.launch(viewModel.permissionsRequired)
                }
            },
            enabled = uiState.isHealthConnectAvailable && uiState.patientIdInput.isNotBlank(),
            modifier = Modifier.fillMaxWidth().height(52.dp),
            shape = RoundedCornerShape(12.dp),
            colors = ButtonDefaults.buttonColors(containerColor = NivaraBlue),
        ) {
            Text("Connect Health Data", style = MaterialTheme.typography.titleMedium, color = Color.White)
        }

        Spacer(Modifier.height(16.dp))
        Text(
            "Your data is encrypted and only shared with your physician.",
            style = MaterialTheme.typography.labelSmall, color = Color.Gray, textAlign = TextAlign.Center,
        )
    }
}
