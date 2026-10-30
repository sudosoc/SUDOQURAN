package com.sudosoc.sudoquran

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.KeyEvent
import android.widget.RemoteViews

/** Home-screen widget: now playing + previous / play-pause / next. Plain Android, no libraries. */
class QuranWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        render(context, manager, ids)
    }

    companion object {
        private const val PREFS = "quran_widget"

        fun save(context: Context, title: String, subtitle: String, playing: Boolean) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString("title", title)
                .putString("subtitle", subtitle)
                .putBoolean("playing", playing)
                .apply()
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, QuranWidgetProvider::class.java))
            if (ids.isNotEmpty()) render(context, manager, ids)
        }

        private fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val title = p.getString("title", "القرآن الكريم") ?: "القرآن الكريم"
            val subtitle = p.getString("subtitle", "اضغط للتشغيل") ?: ""
            val playing = p.getBoolean("playing", false)
            for (id in ids) {
                val views = RemoteViews(context.packageName, R.layout.quran_widget).apply {
                    setTextViewText(R.id.widget_title, title)
                    setTextViewText(R.id.widget_subtitle, subtitle)
                    setImageViewResource(
                        R.id.widget_play,
                        if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
                    )
                    setOnClickPendingIntent(R.id.widget_root, openApp(context))
                    setOnClickPendingIntent(R.id.widget_play, media(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
                    setOnClickPendingIntent(R.id.widget_next, media(context, KeyEvent.KEYCODE_MEDIA_NEXT))
                    setOnClickPendingIntent(R.id.widget_prev, media(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS))
                }
                manager.updateAppWidget(id, views)
            }
        }

        private fun openApp(context: Context): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            return PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        private fun media(context: Context, keyCode: Int): PendingIntent {
            val intent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                component = ComponentName(context, "com.ryanheise.audioservice.MediaButtonReceiver")
                putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
            }
            return PendingIntent.getBroadcast(
                context, keyCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
    }
}
