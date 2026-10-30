package com.sudosoc.sudoquran

import android.app.Application
import android.content.Intent
import android.os.Process
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import kotlin.system.exitProcess

/**
 * Catches any native (Java/Kotlin) crash, saves the stack trace and shows it on
 * a plain screen (CrashActivity, separate process) instead of "keeps stopping".
 */
class SudoApp : Application() {
    override fun onCreate() {
        super.onCreate()
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                val sw = StringWriter()
                error.printStackTrace(PrintWriter(sw))
                val trace = "Thread: ${thread.name}\n\n$sw"
                File(filesDir, "last_crash.txt").writeText(trace)
                val i = Intent(this, CrashActivity::class.java).apply {
                    putExtra("trace", trace)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                }
                startActivity(i)
                Process.killProcess(Process.myPid())
                exitProcess(10)
            } catch (t: Throwable) {
                previous?.uncaughtException(thread, error)
            }
        }
    }
}
