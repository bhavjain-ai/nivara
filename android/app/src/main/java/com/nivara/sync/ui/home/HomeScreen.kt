package com.nivara.sync.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.nivara.sync.ui.theme.*

@Composable
fun HomeScreen(viewModel: HomeViewModel = viewModel()) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(Unit) { viewModel.loadState() }

    Column(
        modifier = Modifier.fillMaxSize().background(SurfaceGray).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier.size(48.dp).clip(RoundedCornerShape(12.dp)).background(NivaraBlue),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Default.Favorite, contentDescription = null, tint = Color.White, modifier = Modifier.size(28.dp))
            }
            Spacer(Modifier.width(12.dp))
            Column {
                Text("Nivara Health Sync", style = MaterialTheme.typography.titleLarge, color = NivaraBlue)
                Text("Blood Pressure Monitoring", style = MaterialTheme.typography.bodyMedium, color = Color.Gray)
            }
        }

        // Patient ID + connection status
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = Color.White),
            elevation = CardDefaults.cardElevation(2.dp),
        ) {
            Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("Patient ID", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                    Text(uiState.patientId, style = MaterialTheme.typography.titleMedium, color = NivaraBlue, fontWeight = FontWeight.Bold)
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text("Health Connect", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(modifier = Modifier.size(8.dp).clip(RoundedCornerShape(4.dp))
                            .background(if (uiState.isConnected) SuccessGreen else ErrorRed))
                        Spacer(Modifier.width(6.dp))
                        Text(
                            if (uiState.isConnected) "Connected" else "Not Connected",
                            style = MaterialTheme.typography.bodyMedium,
                            color = if (uiState.isConnected) SuccessGreen else ErrorRed,
                            fontWeight = FontWeight.Medium,
                        )
                    }
                }
            }
        }

        InfoCard(Icons.Default.MonitorHeart, "Last BP Reading", uiState.lastBpReading,
            if (uiState.pendingQueueCount > 0) "${uiState.pendingQueueCount} reading(s) pending upload" else null)
        InfoCard(Icons.Default.CloudDone, "Last Synced", uiState.lastSyncTime, null)

        uiState.syncMessage?.let { msg ->
            val isError = msg.startsWith("Sync failed")
            Card(
                modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(containerColor = if (isError) ErrorRed.copy(alpha = 0.1f) else SuccessGreen.copy(alpha = 0.1f)),
            ) {
                Text(msg, modifier = Modifier.padding(12.dp), color = if (isError) ErrorRed else SuccessGreen, style = MaterialTheme.typography.bodyMedium)
            }
        }

        Spacer(Modifier.weight(1f))

        Button(
            onClick = { viewModel.syncNow() },
            enabled = uiState.isConnected && !uiState.isSyncing,
            modifier = Modifier.fillMaxWidth().height(52.dp),
            shape = RoundedCornerShape(12.dp),
            colors = ButtonDefaults.buttonColors(containerColor = NivaraBlue),
        ) {
            if (uiState.isSyncing) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), color = Color.White, strokeWidth = 2.dp)
                Spacer(Modifier.width(10.dp))
                Text("Syncing…", color = Color.White, fontWeight = FontWeight.Medium)
            } else {
                Icon(Icons.Default.Sync, contentDescription = null, tint = Color.White)
                Spacer(Modifier.width(8.dp))
                Text("Sync Now", color = Color.White, fontWeight = FontWeight.Medium)
            }
        }

        Text("Background sync runs every 4 hours automatically.", style = MaterialTheme.typography.labelSmall,
            color = Color.Gray, modifier = Modifier.align(Alignment.CenterHorizontally))

        OutlinedButton(
            onClick = { viewModel.sendTestReading() },
            enabled = !uiState.isSyncing,
            modifier = Modifier.fillMaxWidth().height(48.dp),
            shape = RoundedCornerShape(12.dp),
        ) {
            Icon(Icons.Default.BugReport, contentDescription = null, tint = NivaraBlue)
            Spacer(Modifier.width(8.dp))
            Text("Send Test Reading (125/82)", color = NivaraBlue, fontWeight = FontWeight.Medium)
        }
    }
}

@Composable
private fun InfoCard(icon: ImageVector, title: String, value: String, subtitle: String?) {
    Card(
        modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(2.dp),
    ) {
        Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier.size(44.dp).clip(RoundedCornerShape(10.dp)).background(NivaraBlue.copy(alpha = 0.08f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(icon, contentDescription = null, tint = NivaraBlue, modifier = Modifier.size(24.dp))
            }
            Spacer(Modifier.width(14.dp))
            Column {
                Text(title, style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                Text(value, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                if (subtitle != null) Text(subtitle, style = MaterialTheme.typography.labelSmall, color = WarningAmber)
            }
        }
    }
}
