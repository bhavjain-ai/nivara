package com.nivara.sync.data.local

import android.content.Context
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.nivara.sync.domain.model.BpReading

private const val QUEUE_PREFS = "nivara_queue_prefs"
private const val KEY_QUEUE = "pending_readings"

/**
 * Simple JSON-backed queue stored in plain SharedPreferences (non-sensitive payload).
 * Readings that fail to upload are stored here for retry on next sync.
 */
class SyncQueueManager(context: Context) {

    private val prefs = context.getSharedPreferences(QUEUE_PREFS, Context.MODE_PRIVATE)
    private val gson = Gson()

    fun enqueue(reading: BpReading) {
        val queue = getAll().toMutableList()
        queue.add(reading)
        save(queue)
    }

    fun getAll(): List<BpReading> {
        val json = prefs.getString(KEY_QUEUE, "[]") ?: "[]"
        val type = object : TypeToken<List<BpReading>>() {}.type
        return gson.fromJson(json, type) ?: emptyList()
    }

    fun remove(reading: BpReading) {
        val queue = getAll().toMutableList()
        queue.removeAll { it.timestamp == reading.timestamp }
        save(queue)
    }

    fun clear() {
        prefs.edit().remove(KEY_QUEUE).apply()
    }

    private fun save(queue: List<BpReading>) {
        prefs.edit().putString(KEY_QUEUE, gson.toJson(queue)).apply()
    }
}
