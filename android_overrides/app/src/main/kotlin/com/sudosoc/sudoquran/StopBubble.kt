package com.sudosoc.sudoquran

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Floating "إيقاف" button drawn over every app while the adhan or
 * دعاء الركوب is playing in the background. Needs "display over other apps".
 */
object StopBubble {
    private var view: View? = null

    fun canDraw(context: Context): Boolean =
        Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(context)

    fun show(context: Context, label: String, stop: Intent) {
        if (!canDraw(context)) return
        hide(context)
        try {
            val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val d = context.resources.displayMetrics.density
            val bg = GradientDrawable().apply {
                cornerRadius = 40 * d
                colors = intArrayOf(Color.parseColor("#F3DDA6"), Color.parseColor("#C9973F"))
                orientation = GradientDrawable.Orientation.TL_BR
                setStroke((2 * d).toInt(), Color.parseColor("#55000000"))
            }
            val box = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                background = bg
                setPadding((22 * d).toInt(), (14 * d).toInt(), (22 * d).toInt(), (14 * d).toInt())
                elevation = 12 * d
            }
            box.addView(TextView(context).apply {
                text = "■"
                setTextColor(Color.parseColor("#1A1206"))
                textSize = 26f
                setPadding(0, 0, (12 * d).toInt(), 0)
            })
            box.addView(TextView(context).apply {
                text = label
                setTextColor(Color.parseColor("#1A1206"))
                textSize = 22f
                paint.isFakeBoldText = true
            })
            val type = overlayType()
            val lp = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                type,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                y = (40 * d).toInt()
            }
            // tap = stop, drag = move
            var downY = 0f
            var startY = 0
            var moved = false
            box.setOnTouchListener { _, e ->
                when (e.action) {
                    MotionEvent.ACTION_DOWN -> { downY = e.rawY; startY = lp.y; moved = false; true }
                    MotionEvent.ACTION_MOVE -> {
                        val dy = (e.rawY - downY).toInt()
                        if (Math.abs(dy) > 12 * d) moved = true
                        lp.y = (startY + dy).coerceAtLeast(0)
                        try { wm.updateViewLayout(box, lp) } catch (_: Throwable) {}
                        true
                    }
                    MotionEvent.ACTION_UP -> {
                        if (!moved) {
                            try { context.startService(stop) } catch (_: Throwable) {}
                            hide(context)
                        }
                        true
                    }
                    else -> false
                }
            }
            wm.addView(box, lp)
            view = box
        } catch (_: Throwable) {
            view = null
        }
    }

    @Suppress("DEPRECATION")
    private fun overlayType(): Int =
        if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else WindowManager.LayoutParams.TYPE_PHONE

    fun hide(context: Context) {
        val v = view ?: return
        view = null
        try {
            (context.getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(v)
        } catch (_: Throwable) {}
    }
}
