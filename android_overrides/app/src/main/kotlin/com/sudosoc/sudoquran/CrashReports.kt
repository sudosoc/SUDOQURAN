package com.sudosoc.sudoquran

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Finds the report of the previous crash (Java or native) to show on next launch. */
object CrashReports {
    fun pending(context: Context): String? {
        // 1) Java/Kotlin crash saved by SudoApp's handler
        val f = File(context.filesDir, "last_crash.txt")
        if (f.exists()) {
            val t = f.readText()
            f.renameTo(File(context.filesDir, "last_crash_shown.txt"))
            return header(context) + "\n[JAVA CRASH]\n" + t
        }
        // 2) Anything the OS recorded (native crash, ANR, ...) — Android 11+
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        return try {
            val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val prefs = context.getSharedPreferences("crash_reports", Context.MODE_PRIVATE)
            val lastShown = prefs.getLong("lastExit", 0L)
            val info = am.getHistoricalProcessExitReasons(context.packageName, 0, 5)
                .firstOrNull { it.processName == context.packageName } ?: return null
            if (info.timestamp <= lastShown) return null
            val bad = info.reason == ApplicationExitInfo.REASON_CRASH ||
                info.reason == ApplicationExitInfo.REASON_CRASH_NATIVE ||
                info.reason == ApplicationExitInfo.REASON_ANR ||
                info.reason == ApplicationExitInfo.REASON_INITIALIZATION_FAILURE
            prefs.edit().putLong("lastExit", info.timestamp).apply()
            if (!bad) return null
            val sb = StringBuilder(header(context))
            sb.append("\n[OS EXIT INFO]\nreason=").append(reasonName(info.reason))
                .append("\nstatus=").append(info.status)
                .append("\ntime=").append(SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date(info.timestamp)))
                .append("\ndescription=").append(info.description).append("\n\n")
            info.traceInputStream?.use { input ->
                val bytes = input.readBytes()
                // native tombstones are protobuf: pull out the readable lines
                val text = String(bytes, Charsets.ISO_8859_1)
                Regex("[\\x20-\\x7E\\t]{6,}").findAll(text).take(260).forEach { sb.append(it.value).append('\n') }
            }
            sb.toString()
        } catch (t: Throwable) {
            null
        }
    }

    private fun header(context: Context): String {
        val v = try {
            context.packageManager.getPackageInfo(context.packageName, 0).versionName
        } catch (_: Throwable) { "?" }
        return "app=$v device=${Build.MANUFACTURER} ${Build.MODEL} android=${Build.VERSION.RELEASE} (sdk ${Build.VERSION.SDK_INT}) abi=${Build.SUPPORTED_ABIS.joinToString()}"
    }

    private fun reasonName(r: Int) = when (r) {
        ApplicationExitInfo.REASON_CRASH -> "CRASH (java)"
        ApplicationExitInfo.REASON_CRASH_NATIVE -> "CRASH_NATIVE"
        ApplicationExitInfo.REASON_ANR -> "ANR"
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "INITIALIZATION_FAILURE"
        else -> "reason $r"
    }
}
