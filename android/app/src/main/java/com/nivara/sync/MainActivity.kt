package com.nivara.sync

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.nivara.sync.data.local.PreferencesManager
import com.nivara.sync.ui.home.HomeScreen
import com.nivara.sync.ui.onboarding.OnboardingScreen
import com.nivara.sync.ui.theme.NivaraSyncTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val prefs = PreferencesManager(this)

        setContent {
            NivaraSyncTheme {
                Surface(modifier = Modifier.fillMaxSize().safeDrawingPadding()) {
                    if (prefs.onboardingComplete) {
                        HomeScreen()
                    } else {
                        OnboardingScreen(onOnboardingComplete = { recreate() })
                    }
                }
            }
        }
    }
}
