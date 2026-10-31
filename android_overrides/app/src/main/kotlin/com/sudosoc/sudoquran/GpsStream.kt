package com.sudosoc.sudoquran

import android.annotation.SuppressLint
import android.content.Context
import android.location.GnssStatus
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/** Streams raw GPS fixes (speed, bearing, altitude, satellites) to Dart. No Play Services. */
@SuppressLint("MissingPermission")
class GpsStream(private val context: Context) : EventChannel.StreamHandler {
    private var sink: EventChannel.EventSink? = null
    private var satellites = 0
    private var usedSats = 0
    private val lm get() = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager

    private val listener = object : LocationListener {
        override fun onLocationChanged(l: Location) {
            val m = HashMap<String, Any>()
            m["lat"] = l.latitude
            m["lng"] = l.longitude
            m["speed"] = if (l.hasSpeed()) l.speed.toDouble() else -1.0
            m["bearing"] = if (l.hasBearing()) l.bearing.toDouble() else -1.0
            m["alt"] = if (l.hasAltitude()) l.altitude else 0.0
            m["acc"] = if (l.hasAccuracy()) l.accuracy.toDouble() else -1.0
            m["time"] = l.time
            m["sats"] = satellites
            m["used"] = usedSats
            m["provider"] = l.provider ?: ""
            sink?.success(m)
        }

        @Deprecated("Deprecated in Java")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        override fun onProviderEnabled(provider: String) {}
        override fun onProviderDisabled(provider: String) {
            sink?.error("disabled", "GPS مقفول", null)
        }
    }

    private var gnss: Any? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        try {
            lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 500L, 0f, listener, Looper.getMainLooper())
            try {
                lm.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 2000L, 0f, listener, Looper.getMainLooper())
            } catch (_: Throwable) {}
            if (Build.VERSION.SDK_INT >= 24) {
                val cb = object : GnssStatus.Callback() {
                    override fun onSatelliteStatusChanged(status: GnssStatus) {
                        satellites = status.satelliteCount
                        var used = 0
                        for (i in 0 until status.satelliteCount) if (status.usedInFix(i)) used++
                        usedSats = used
                    }
                }
                gnss = cb
                lm.registerGnssStatusCallback(cb, Handler(Looper.getMainLooper()))
            }
            lm.getLastKnownLocation(LocationManager.GPS_PROVIDER)?.let { listener.onLocationChanged(it) }
        } catch (e: SecurityException) {
            events.error("permission", "محتاج إذن الموقع", null)
        } catch (t: Throwable) {
            events.error("gps", t.message, null)
        }
    }

    override fun onCancel(arguments: Any?) {
        try { lm.removeUpdates(listener) } catch (_: Throwable) {}
        if (Build.VERSION.SDK_INT >= 24) {
            (gnss as? GnssStatus.Callback)?.let { try { lm.unregisterGnssStatusCallback(it) } catch (_: Throwable) {} }
        }
        gnss = null
        sink = null
    }
}
