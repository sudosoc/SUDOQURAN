package com.sudosoc.sudoquran

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/** Schedules adhan / pre-alert alarms handed over from Dart (7 days ahead). */
object AdhanScheduler {
    private const val PREFS = "adhan_alarms"
    private const val BASE = 7000

    fun schedule(context: Context, items: JSONArray) {
        cancel(context)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("items", items.toString()).apply()
        arm(context, items)
    }

    fun reschedule(context: Context) {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("items", null) ?: return
        try { arm(context, JSONArray(raw)) } catch (_: Throwable) {}
    }

    fun cancel(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val n = try { JSONArray(p.getString("items", "[]")).length() } catch (_: Throwable) { 0 }
        for (i in 0 until maxOf(n, 80)) {
            val pi = PendingIntent.getBroadcast(
                context, BASE + i, Intent(context, AdhanAlarmReceiver::class.java),
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pi != null) am.cancel(pi)
        }
        p.edit().remove("items").apply()
    }

    private fun arm(context: Context, items: JSONArray) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val now = System.currentTimeMillis()
        var exact = true
        if (Build.VERSION.SDK_INT >= 31) exact = am.canScheduleExactAlarms()
        for (i in 0 until items.length()) {
            val o: JSONObject = items.getJSONObject(i)
            val at = o.getLong("at")
            if (at <= now) continue
            val intent = Intent(context, AdhanAlarmReceiver::class.java).apply {
                putExtra("title", o.optString("title"))
                putExtra("body", o.optString("body"))
                putExtra("sound", o.optString("sound"))
                putExtra("nid", BASE + i)
            }
            val pi = PendingIntent.getBroadcast(
                context, BASE + i, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            try {
                if (Build.VERSION.SDK_INT >= 23) {
                    if (exact) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                    else am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                } else {
                    am.set(AlarmManager.RTC_WAKEUP, at, pi)
                }
            } catch (_: Throwable) {
                am.set(AlarmManager.RTC_WAKEUP, at, pi)
            }
        }
    }

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(
            NotificationChannel("adhan_alerts", "تنبيهات الصلاة", NotificationManager.IMPORTANCE_HIGH)
        )
        nm.createNotificationChannel(
            NotificationChannel("adhan_play", "الأذان", NotificationManager.IMPORTANCE_LOW).apply { setSound(null, null) }
        )
    }

    @Suppress("DEPRECATION")
    fun builder(context: Context, channel: String): android.app.Notification.Builder =
        if (Build.VERSION.SDK_INT >= 26) android.app.Notification.Builder(context, channel)
        else android.app.Notification.Builder(context)

    fun openAppIntent(context: Context): PendingIntent = PendingIntent.getActivity(
        context, 0,
        Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
}

class AdhanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            AdhanScheduler.ensureChannels(context)
            val title = intent.getStringExtra("title") ?: "الأذان"
            val body = intent.getStringExtra("body") ?: ""
            val sound = intent.getStringExtra("sound") ?: ""
            val nid = intent.getIntExtra("nid", 7000)
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val willPlay = sound.isNotEmpty() && File(sound).exists()
            val stopPi = PendingIntent.getService(
                context, 2, Intent(context, AdhanService::class.java).setAction("STOP"),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val b = AdhanScheduler.builder(context, "adhan_alerts")
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle(title)
                .setContentText(body)
                .setAutoCancel(true)
                .setContentIntent(AdhanScheduler.openAppIntent(context))
            if (willPlay) {
                // swiping the notification away / pressing "إيقاف" silences the adhan
                b.setDeleteIntent(stopPi)
                @Suppress("DEPRECATION")
                b.addAction(android.R.drawable.ic_media_pause, "إيقاف الأذان", stopPi)
            }
            nm.notify(nid, b.build())
            if (sound.isNotEmpty() && File(sound).exists()) {
                val svc = Intent(context, AdhanService::class.java).putExtra("path", sound).putExtra("title", title)
                try {
                    if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(svc)
                    else context.startService(svc)
                } catch (_: Throwable) { /* background start not allowed: the notification still shows */ }
            }
        } catch (_: Throwable) {}
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try { AdhanScheduler.reschedule(context) } catch (_: Throwable) {}
        // Car started (full boot / quick boot / head-unit ACC-on): دعاء الركوب
        if (DuaService.enabled(context)) {
            val replaced = intent.action == Intent.ACTION_MY_PACKAGE_REPLACED
            DuaService.start(context, if (replaced) null else "PLAY_BOOT")
        }
    }
}

/** Plays the downloaded adhan file even when the app is closed. */
class AdhanService : Service() {
    private var player: MediaPlayer? = null

    override fun onBind(intent: Intent?): IBinder? = null

    private var focus: Any? = null
    private val focusListener = android.media.AudioManager.OnAudioFocusChangeListener { change ->
        // a phone call / navigation took the audio → stop right away
        if (change == android.media.AudioManager.AUDIOFOCUS_LOSS ||
            change == android.media.AudioManager.AUDIOFOCUS_LOSS_TRANSIENT) stopAll()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP") {
            if (Build.VERSION.SDK_INT >= 26) startForeground(9001, AdhanScheduler.builder(this, "adhan_play")
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm).setContentTitle("الأذان").build())
            stopAll()
            return START_NOT_STICKY
        }
        AdhanScheduler.ensureChannels(this)
        val title = intent?.getStringExtra("title") ?: "الأذان"
        val stop = PendingIntent.getService(
            this, 1, Intent(this, AdhanService::class.java).setAction("STOP"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val n = AdhanScheduler.builder(this, "adhan_play")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText("حيّ على الصلاة")
            .setContentIntent(AdhanScheduler.openAppIntent(this))
            .apply {
                @Suppress("DEPRECATION")
                addAction(android.R.drawable.ic_media_pause, "إيقاف", stop)
            }
            .build()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(9001, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(9001, n)
        }
        val path = intent?.getStringExtra("path")
        try {
            player?.release()
            player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                setDataSource(path ?: "")
                setOnCompletionListener { stopAll() }
                prepare()
                start()
            }
            requestFocus()
            StopBubble.show(this, "إيقاف الأذان", Intent(this, AdhanService::class.java).setAction("STOP"))
        } catch (_: Throwable) {
            stopAll()
        }
        return START_NOT_STICKY
    }

    private fun requestFocus() {
        val am = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
        if (Build.VERSION.SDK_INT >= 26) {
            val r = android.media.AudioFocusRequest.Builder(android.media.AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).build())
                .setOnAudioFocusChangeListener(focusListener)
                .build()
            focus = r
            am.requestAudioFocus(r)
        }
    }

    private fun stopAll() {
        StopBubble.hide(this)
        try { player?.release() } catch (_: Throwable) {}
        player = null
        if (Build.VERSION.SDK_INT >= 26) {
            val am = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
            (focus as? android.media.AudioFocusRequest)?.let { am.abandonAudioFocusRequest(it) }
        }
        stopFg()
        stopSelf()
    }

    @Suppress("DEPRECATION")
    private fun stopFg() {
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else stopForeground(true)
    }

    override fun onDestroy() {
        try { player?.release() } catch (_: Throwable) {}
        super.onDestroy()
    }
}
