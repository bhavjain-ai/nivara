package com.nivara.sync.data.remote

import com.nivara.sync.data.remote.models.BpReadingRequest
import com.nivara.sync.data.remote.models.BpReadingResponse
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.POST

interface NivaraApiService {

    @POST("api/bp-reading")
    suspend fun uploadBpReading(
        @Body request: BpReadingRequest,
    ): Response<BpReadingResponse>
}
