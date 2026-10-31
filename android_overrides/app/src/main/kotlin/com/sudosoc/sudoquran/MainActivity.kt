package com.sudosoc.sudoquran

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

// AudioServiceActivity keeps the Flutter engine shared with the background
// audio service, so playback survives leaving the app.
class MainActivity : AudioServiceActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private var pendingSave: String? = null

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
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "sudoquran/widget").setMethodCallHandler { call, result ->
            if (call.method == "update") {
                try {
                    QuranWidgetProvider.save(
                        applicationContext,
                        call.argument<String>("title") ?: "",
                        call.argument<String>("subtitle") ?: "",
                        call.argument<Boolean>("playing") ?: false,
                        call.argument<String>("style") ?: "glass"
                    )
                    result.success(true)
                } catch (t: Throwable) {
                    result.error("widget", t.message, null)
                }
            } else result.notImplemented()
        }

        MethodChannel(messenger, "sudoquran/alarms").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "schedule" -> {
                        val items = call.argument<List<Map<String, Any>>>("items") ?: emptyList()
                        val arr = JSONArray()
                        for (m in items) arr.put(org.json.JSONObject(m))
                        AdhanScheduler.schedule(applicationContext, arr)
                        result.success(arr.length())
                    }
                    "cancel" -> {
                        AdhanScheduler.cancel(applicationContext)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (t: Throwable) {
                result.error("alarms", t.message, null)
            }
        }

        MethodChannel(messenger, "sudoquran/backup").setMethodCallHandler { call, result ->
            when (call.method) {
                "save" -> {
                    pendingResult = result
                    pendingSave = call.argument<String>("json")
                    val i = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/json"
                        putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "sudoquran-backup.json")
                    }
                    startActivityForResult(i, 4101)
                }
                "load" -> {
                    pendingResult = result
                    val i = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                    }
                    startActivityForResult(i, 4102)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 4101 && requestCode != 4102) return
        val res = pendingResult ?: return
        pendingResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            res.success(null)
            return
        }
        try {
            if (requestCode == 4101) {
                contentResolver.openOutputStream(uri, "wt")?.use { it.write((pendingSave ?: "").toByteArray()) }
                res.success("ok")
            } else {
                val text = contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }
                res.success(text)
            }
        } catch (t: Throwable) {
            res.error("backup", t.message, null)
        }
    }
}
