package com.leywin.wakepoint

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import org.json.JSONObject

class GeofenceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) return

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (prefs.getString(ACTIVE_SPEC_KEY, null) == null) return

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannels(manager)

        val ids = event.triggeringGeofences.orEmpty().map { it.requestId }.toSet()
        if (event.geofenceTransition == Geofence.GEOFENCE_TRANSITION_ENTER && ARRIVAL_ID in ids) {
            notifyArrival(context, manager)
        } else if (event.geofenceTransition == Geofence.GEOFENCE_TRANSITION_ENTER && APPROACH_ID in ids) {
            notifyApproach(context, manager)
        } else if (event.geofenceTransition == Geofence.GEOFENCE_TRANSITION_EXIT && APPROACH_ID in ids) {
            manager.cancel(APPROACH_NOTIFICATION_ID)
        }
    }

    private fun notifyApproach(context: Context, manager: NotificationManager) {
        val name = activeName(context)
        val openApp = PendingIntent.getActivity(
            context,
            APPROACH_NOTIFICATION_ID,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, APPROACH_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setContentTitle("Approaching $name")
            .setContentText("WakePoint will alert you when you reach your destination.")
            .setContentIntent(openApp)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        manager.notify(APPROACH_NOTIFICATION_ID, notification)
    }

    private fun notifyArrival(context: Context, manager: NotificationManager) {
        val name = activeName(context)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val event = JSONObject()
            .put("type", "arrival")
            .put("name", name)
            .put("tripId", prefs.getString(ACTIVE_ID_KEY, ""))
            .put("timestamp", System.currentTimeMillis())
        prefs.edit().putString(PENDING_EVENT_KEY, event.toString()).apply()

        val alarmIntent = Intent(context, AlarmActivity::class.java).apply {
            putExtra(EXTRA_EVENT_TYPE, "arrival")
            putExtra(EXTRA_LOCATION_NAME, name)
            putExtra(EXTRA_TRIP_ID, prefs.getString(ACTIVE_ID_KEY, ""))
        }
        val alarmPendingIntent = PendingIntent.getActivity(
            context,
            ALARM_NOTIFICATION_ID,
            alarmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, ALARM_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setContentTitle("WakePoint: destination reached")
            .setContentText("You have arrived at $name.")
            .setContentIntent(alarmPendingIntent)
            .setFullScreenIntent(alarmPendingIntent, true)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setAutoCancel(true)
            .setOngoing(false)
            .build()
        manager.notify(ALARM_NOTIFICATION_ID, notification)
    }

    private fun activeName(context: Context): String =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(ACTIVE_NAME_KEY, "your destination") ?: "your destination"

    private fun ensureChannels(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        manager.createNotificationChannel(
            NotificationChannel(
                APPROACH_CHANNEL,
                "Approaching destination",
                NotificationManager.IMPORTANCE_DEFAULT,
            ),
        )
        manager.createNotificationChannel(
            NotificationChannel(
                ALARM_CHANNEL,
                "Destination alarm",
                NotificationManager.IMPORTANCE_HIGH,
            ),
        )
    }

    companion object {
        const val PREFS_NAME = "wakepoint_geofencing"
        const val PENDING_EVENT_KEY = "pending_event"
        const val ACTIVE_NAME_KEY = "active_name"
        const val ACTIVE_ID_KEY = "active_id"
        const val ACTIVE_SPEC_KEY = "active_spec"
        const val ARRIVAL_ID = "wakepoint_arrival"
        const val APPROACH_ID = "wakepoint_approach"
        const val EXTRA_EVENT_TYPE = "wakepoint_event_type"
        const val EXTRA_LOCATION_NAME = "wakepoint_location_name"
        const val EXTRA_TRIP_ID = "wakepoint_trip_id"
        const val APPROACH_CHANNEL = "wakepoint_geofence_approach"
        const val ALARM_CHANNEL = "wakepoint_geofence_alarm"
        const val APPROACH_NOTIFICATION_ID = 1002
        const val ALARM_NOTIFICATION_ID = 1000
    }
}
