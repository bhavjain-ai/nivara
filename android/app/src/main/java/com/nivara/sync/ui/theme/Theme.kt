package com.nivara.sync.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(
    primary = NivaraBlue,
    onPrimary = Color.White,
    primaryContainer = NivaraAccent,
    secondary = NivaraBlueLight,
    background = SurfaceGray,
    surface = Color.White,
    onBackground = Color(0xFF1A202C),
    onSurface = Color(0xFF1A202C),
)

@Composable
fun NivaraSyncTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = LightColors, typography = NivaraTypography, content = content)
}
