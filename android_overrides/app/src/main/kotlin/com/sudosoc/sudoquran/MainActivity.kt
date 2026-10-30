package com.sudosoc.sudoquran

import android.content.Intent
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity keeps the Flutter engine shared with the background
// audio service, so playback survives leaving the app.
class MainActivity : AudioServiceActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // If the previous run crashed, show its report first (separate process,
        // so it stays up even if Flutter crashes again).
        try {
            CrashReports.pending(this)?.let { report ->
                startActivity(Intent(this, CrashActivity::class.java).putExtra("trace", report))
            }
        } catch (_: Throwable) {}
        super.onCreate(savedInstanceState)
    }
}
