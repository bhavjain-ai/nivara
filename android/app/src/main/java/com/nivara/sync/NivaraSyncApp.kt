package com.nivara.sync

import android.app.Application
import com.nivara.sync.worker.BpSyncWorker

class NivaraSyncApp : Application() {
    override fun onCreate() {
        super.onCreate()
        BpSyncWorker.schedule(this)
    }
}
