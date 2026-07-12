package com.nivara.sync.domain.model

data class BpReading(
    val systolic: Int,
    val diastolic: Int,
    val pulse: Int?,
    val timestamp: String,   // ISO-8601 UTC
    val sourceApp: String = "HealthConnect",
)
