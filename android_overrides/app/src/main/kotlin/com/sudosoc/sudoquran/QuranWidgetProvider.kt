package com.sudosoc.sudoquran

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.KeyEvent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** Home-screen widget: now playing + previous / play-pause / next. */
class QuranWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val title = widgetData.getString("title", "القرآن الكريم") ?: "القرآن الكريم"
        val subtitle = widgetData.getString("subtitle", "اضغط للتشغيل") ?: ""
        val playing = widgetData.getBoolean("playing", false)

        for (id in appWidgetIds) {
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
            appWidgetManager.updateAppWidget(id, views)
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
