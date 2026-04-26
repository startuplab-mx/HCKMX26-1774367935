package com.requiemz.overlay_pop_up

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle

/**
 * Transparent Activity used to start foreground service on Android 12+
 * when the main app is in background.
 *
 * This Activity is shown briefly to bring the app to foreground state,
 * allowing the service to start, then immediately finishes.
 */
class OverlayLauncherActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        println("[OverlayLauncherActivity] Starting overlay service from launcher activity")

        // Start the overlay service - we're now in foreground so it's allowed
        val serviceIntent = Intent(this, OverlayService::class.java)

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
            println("[OverlayLauncherActivity] Service started successfully")
        } catch (e: Exception) {
            println("[OverlayLauncherActivity] Error starting service: ${e.message}")
            e.printStackTrace()
        }

        // Close this activity immediately - the overlay will remain visible
        finish()
    }
}
