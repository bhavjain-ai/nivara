package com.nivara.sync.data.remote.models

import com.google.gson.annotations.SerializedName

data class BpReadingRequest(
    @SerializedName("patient_id") val patientId: String,
    @SerializedName("systolic") val systolic: Int,
    @SerializedName("diastolic") val diastolic: Int,
    @SerializedName("pulse") val pulse: Int?,
    @SerializedName("timestamp") val timestamp: String,
)

data class BpReadingResponse(
    @SerializedName("success") val success: Boolean,
    @SerializedName("reading_id") val readingId: String?,
    @SerializedName("received_at") val receivedAt: String?,
    @SerializedName("total_readings") val totalReadings: Int?,
    @SerializedName("message") val message: String?,
    @SerializedName("error") val error: String?,
)
