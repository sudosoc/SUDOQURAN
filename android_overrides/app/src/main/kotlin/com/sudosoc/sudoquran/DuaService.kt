package com.sudosoc.sudoquran

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import org.json.JSONArray
import java.io.File

/**
 * Lives in the background and plays دعاء الركوب every time the car starts:
 *  - after a real boot (BootReceiver), or
 *  - when the screen wakes up after being off for a while (head units that
 *    sleep on ACC-off and wake on ACC-on instead of rebooting).
 */
class DuaService : Service() {
    companion object {
        const val PREFS = "dua_service"
        private const val MIN_OFF_MS = 30_000L

        fun configure(context: Context, enabled: Boolean, paths: List<String>) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putBoolean("enabled", enabled)
                .putString("paths", JSONArray(paths).toString())
                .apply()
            if (enabled) start(context, null) else context.stopService(Intent(context, DuaService::class.java))
        }

        fun enabled(context: Context) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("enabled", false)

        fun lastPlayed(context: Context) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong("last", 0L)

        fun start(context: Context, action: String?) {
            val i = Intent(context, DuaService::class.java).setAction(action)
            try {
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(i) else context.startService(i)
            } catch (_: Throwable) {}
        }
    }

    private var player: MediaPlayer? = null
    private var offAt = 0L
    private val handler = Handler(Looper.getMainLooper())

    private val screen = object : BroadcastReceiver() {
        override fun onReceive(c: Context, i: Intent) {
            when (i.action) {
                Intent.ACTION_SCREEN_OFF -> offAt = System.currentTimeMillis()
                Intent.ACTION_SCREEN_ON -> {
                    val off = offAt
                    offAt = 0L
                    if (off > 0 && System.currentTimeMillis() - off >= MIN_OFF_MS) {
                        handler.postDelayed({ play() }, 2500)
                    }
                }
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        goForeground()
        val f = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(screen, f, Context.RECEIVER_NOT_EXPORTED)
        else registerReceiver(screen, f)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        goForeground()
        if (!enabled(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        when (intent?.action) {
            "PLAY_BOOT" -> handler.postDelayed({ play() }, 7000) // let the head unit's audio come up
            "PLAY" -> play()
            "STOP" -> stopPlayback()
        }
        return START_STICKY
    }

    private fun goForeground() {
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(
                NotificationChannel("dua_service", "دعاء الركوب", NotificationManager.IMPORTANCE_MIN).apply {
                    setSound(null, null)
                    setShowBadge(false)
                }
            )
        }
        val n = AdhanScheduler.builder(this, "dua_service")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("دعاء الركوب")
            .setContentText("هيشتغل تلقائي أول ما العربية تدور")
            .setContentIntent(AdhanScheduler.openAppIntent(this))
            .setOngoing(true)
            .apply {
                val stop = android.app.PendingIntent.getService(
                    this@DuaService, 3, Intent(this@DuaService, DuaService::class.java).setAction("STOP"),
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                @Suppress("DEPRECATION")
                addAction(android.R.drawable.ic_media_pause, "إيقاف الدعاء", stop)
            }
            .build()
        try {
            if (Build.VERSION.SDK_INT >= 29) startForeground(9101, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            else startForeground(9101, n)
        } catch (_: Throwable) {}
    }

    private fun play() {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean("enabled", false)) return
        if (System.currentTimeMillis() - prefs.getLong("last", 0L) < 60_000L) return // no double play
        val files = try {
            val a = JSONArray(prefs.getString("paths", "[]"))
            (0 until a.length()).map { a.getString(it) }.filter { File(it).exists() }
        } catch (_: Throwable) { emptyList() }
        if (files.isEmpty()) return
        prefs.edit().putLong("last", System.currentTimeMillis()).apply()
        requestFocus()
        StopBubble.show(this, "إيقاف الدعاء", Intent(this, DuaService::class.java).setAction("STOP"))
        playAt(files, 0)
    }

    private fun playAt(files: List<String>, i: Int) {
        try { player?.release() } catch (_: Throwable) {}
        player = null
        if (i >= files.size) {
            StopBubble.hide(this)
            abandonFocus()
            return
        }
        try {
            player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                setDataSource(files[i])
                setOnCompletionListener { playAt(files, i + 1) }
                prepare()
                start()
            }
        } catch (_: Throwable) {
            playAt(files, i + 1)
        }
    }

    private var focus: Any? = null
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change == AudioManager.AUDIOFOCUS_LOSS || change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT) stopPlayback()
    }

    private fun stopPlayback() {
        StopBubble.hide(this)
        try { player?.release() } catch (_: Throwable) {}
        player = null
        abandonFocus()
    }

    private fun requestFocus() {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= 26) {
            val r = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).build())
                .setOnAudioFocusChangeListener(focusListener)
                .build()
            focus = r
            am.requestAudioFocus(r)
        }
    }

    private fun abandonFocus() {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= 26) (focus as? AudioFocusRequest)?.let { am.abandonAudioFocusRequest(it) }
    }

    override fun onDestroy() {
        StopBubble.hide(this)
        try { unregisterReceiver(screen) } catch (_: Throwable) {}
        try { player?.release() } catch (_: Throwable) {}
        super.onDestroy()
    }
}
