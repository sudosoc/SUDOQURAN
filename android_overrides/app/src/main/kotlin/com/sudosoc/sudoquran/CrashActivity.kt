package com.sudosoc.sudoquran

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Color
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import java.io.File

/** Shows the saved crash trace so it can be copied / screenshotted. */
class CrashActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val trace = intent.getStringExtra("trace")
            ?: File(filesDir, "last_crash.txt").takeIf { it.exists() }?.readText()
            ?: "no trace"
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#06141B"))
            setPadding(32, 32, 32, 32)
        }
        root.addView(TextView(this).apply {
            text = "SUDOQURAN — حصل crash. صوّر الشاشة دي أو انسخ التقرير وابعته."
            setTextColor(Color.parseColor("#E6C27A"))
            textSize = 20f
        })
        root.addView(Button(this).apply {
            text = "نسخ التقرير"
            setOnClickListener {
                val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                cm.setPrimaryClip(ClipData.newPlainText("crash", trace))
                Toast.makeText(this@CrashActivity, "اتنسخ ✓", Toast.LENGTH_SHORT).show()
            }
        })
        root.addView(ScrollView(this).apply {
            addView(TextView(this@CrashActivity).apply {
                text = trace
                setTextColor(Color.WHITE)
                textSize = 12f
                setTextIsSelectable(true)
            })
        })
        setContentView(root)
    }
}
