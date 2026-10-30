package com.sudosoc.sudoquran

import android.content.Intent
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// AudioServiceActivity keeps the Flutter engine shared with the background
// audio service, so playback survives leaving the app.
class MainActivity : AudioServiceActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // If the previous run crashed, show its report first (separate process).
        try {
            CrashReports.pending(this)?.let { report ->
                startActivity(Intent(this, CrashActivity::class.java).putExtra("trace", report))
            }
        } catch (_: Throwable) {}
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sudoquran/widget")
            .setMethodCallHandler { call, result ->
                if (call.method == "update") {
                    try {
                        QuranWidgetProvider.save(
                            applicationContext,
                            call.argument<String>("title") ?: "",
                            call.argument<String>("subtitle") ?: "",
                            call.argument<Boolean>("playing") ?: false
                        )
                        result.success(true)
                    } catch (t: Throwable) {
                        result.error("widget", t.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
