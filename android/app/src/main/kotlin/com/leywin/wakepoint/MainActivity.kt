package com.leywin.wakepoint

import android.content.Intent
import android.content.pm.PackageManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.core.app.NotificationManagerCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var ringtone: Ringtone? = null
    private var geofenceChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showAlarmOverLockScreen(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARMCHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                if (call.method == "startAlarm") {
                    val intent = Intent(this, AlarmActivity::class.java)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RINGTONECHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "playTone" -> {
                        val type = call.argument<String>("type") ?: "ringtone"
                        playTone(type, result)
                    }
                    "stopTone" -> stopTone(result)
                    else -> result.notImplemented()
                }
            }

        geofenceChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GEOFENCE_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "register" -> registerGeofences(call, result)
                    "remove" -> removeGeofences(result)
                    "consumePendingEvent" -> consumePendingEvent(result)
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        showAlarmOverLockScreen(intent)
        val eventType = intent.getStringExtra(GeofenceBroadcastReceiver.EXTRA_EVENT_TYPE)
        if (eventType != null) {
            geofenceChannel?.invokeMethod(
                "geofenceEvent",
                mapOf(
                    "type" to eventType,
                    "name" to intent.getStringExtra(GeofenceBroadcastReceiver.EXTRA_LOCATION_NAME),
                    "tripId" to intent.getStringExtra(GeofenceBroadcastReceiver.EXTRA_TRIP_ID),
                ),
            )
        }
    }

    private fun showAlarmOverLockScreen(intent: Intent?) {
        if (intent?.getStringExtra(GeofenceBroadcastReceiver.EXTRA_EVENT_TYPE) != "arrival") return
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
        )
    }

    private fun registerGeofences(call: MethodCall, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            checkSelfPermission(android.Manifest.permission.ACCESS_BACKGROUND_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error("BACKGROUND_LOCATION_REQUIRED", "Allow background location to monitor your destination.", null)
            return
        }
        if (checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error("LOCATION_REQUIRED", "Allow precise location to monitor your destination.", null)
            return
        }

        val name = call.argument<String>("name") ?: "your destination"
        val tripId = call.argument<String>("tripId") ?: ""
        val latitude = call.argument<Double>("latitude") ?: run {
            result.error("INVALID_LOCATION", "A destination latitude is required.", null)
            return
        }
        val longitude = call.argument<Double>("longitude") ?: run {
            result.error("INVALID_LOCATION", "A destination longitude is required.", null)
            return
        }
        val arrivalRadius = (call.argument<Double>("arrivalRadius") ?: 150.0)
            .coerceAtLeast(100.0)
        val approachRadius = call.argument<Double>("approachRadius") ?: 0.0

        val geofences = mutableListOf(
            createGeofence(GeofenceBroadcastReceiver.ARRIVAL_ID, latitude, longitude, arrivalRadius.toFloat()),
        )
        if (approachRadius > arrivalRadius) {
            geofences.add(
                createGeofence(
                    GeofenceBroadcastReceiver.APPROACH_ID,
                    latitude,
                    longitude,
                    approachRadius.toFloat(),
                ),
            )
        }

        val request = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofences(geofences)
            .build()
        val prefs = getSharedPreferences(GeofenceBroadcastReceiver.PREFS_NAME, MODE_PRIVATE)
        NotificationManagerCompat.from(this)
            .cancel(GeofenceBroadcastReceiver.APPROACH_NOTIFICATION_ID)
        val spec = JSONObject()
            .put("name", name)
            .put("tripId", tripId)
            .put("latitude", latitude)
            .put("longitude", longitude)
            .put("arrivalRadius", arrivalRadius)
            .put("approachRadius", approachRadius)

        LocationServices.getGeofencingClient(this)
            .removeGeofences(listOf(GeofenceBroadcastReceiver.ARRIVAL_ID, GeofenceBroadcastReceiver.APPROACH_ID))
            .addOnCompleteListener {
                LocationServices.getGeofencingClient(this)
                    .addGeofences(request, geofencePendingIntent())
                    .addOnSuccessListener {
                        prefs.edit()
                            .putString(GeofenceBroadcastReceiver.ACTIVE_NAME_KEY, name)
                            .putString(GeofenceBroadcastReceiver.ACTIVE_ID_KEY, tripId)
                            .putString(GeofenceBroadcastReceiver.ACTIVE_SPEC_KEY, spec.toString())
                            .remove(GeofenceBroadcastReceiver.PENDING_EVENT_KEY)
                            .apply()
                        result.success(null)
                    }
                    .addOnFailureListener { error ->
                        result.error("GEOFENCE_REGISTER_FAILED", error.localizedMessage, null)
                    }
            }
    }

    private fun createGeofence(id: String, latitude: Double, longitude: Double, radius: Float) =
        Geofence.Builder()
            .setRequestId(id)
            .setCircularRegion(latitude, longitude, radius)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT)
            .setNotificationResponsiveness(10_000)
            .build()

    private fun geofencePendingIntent(): android.app.PendingIntent {
        val intent = Intent(this, GeofenceBroadcastReceiver::class.java)
        var flags = android.app.PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags = flags or android.app.PendingIntent.FLAG_MUTABLE
        }
        return android.app.PendingIntent.getBroadcast(this, 7001, intent, flags)
    }

    private fun removeGeofences(result: MethodChannel.Result) {
        val prefs = getSharedPreferences(GeofenceBroadcastReceiver.PREFS_NAME, MODE_PRIVATE)
        prefs.edit()
            .remove(GeofenceBroadcastReceiver.ACTIVE_NAME_KEY)
            .remove(GeofenceBroadcastReceiver.ACTIVE_ID_KEY)
            .remove(GeofenceBroadcastReceiver.ACTIVE_SPEC_KEY)
            .remove(GeofenceBroadcastReceiver.PENDING_EVENT_KEY)
            .apply()
        NotificationManagerCompat.from(this)
            .cancel(GeofenceBroadcastReceiver.APPROACH_NOTIFICATION_ID)
        NotificationManagerCompat.from(this)
            .cancel(GeofenceBroadcastReceiver.ALARM_NOTIFICATION_ID)
        LocationServices.getGeofencingClient(this)
            .removeGeofences(listOf(GeofenceBroadcastReceiver.ARRIVAL_ID, GeofenceBroadcastReceiver.APPROACH_ID))
            .addOnCompleteListener {
                result.success(null)
            }
    }

    private fun consumePendingEvent(result: MethodChannel.Result) {
        val prefs = getSharedPreferences(GeofenceBroadcastReceiver.PREFS_NAME, MODE_PRIVATE)
        val pending = prefs.getString(GeofenceBroadcastReceiver.PENDING_EVENT_KEY, null)
        prefs.edit().remove(GeofenceBroadcastReceiver.PENDING_EVENT_KEY).apply()
        if (pending == null) {
            result.success(null)
            return
        }
        val json = JSONObject(pending)
        result.success(
            mapOf(
                "type" to json.optString("type"),
                "name" to json.optString("name"),
                "tripId" to json.optString("tripId"),
                "timestamp" to json.optLong("timestamp"),
            ),
        )
    }

    private fun playTone(type: String, result: MethodChannel.Result) {
        val soundType = when (type) {
            "alarm" -> RingtoneManager.TYPE_ALARM
            else -> RingtoneManager.TYPE_RINGTONE
        }

        val uri: Uri = RingtoneManager.getDefaultUri(soundType)
        ringtone = RingtoneManager.getRingtone(applicationContext, uri)
        ringtone?.play()
        result.success(null)
    }

    private fun stopTone(result: MethodChannel.Result) {
        ringtone?.stop()
        result.success(null)
    }

    companion object {
        private const val ALARMCHANNEL = "com.leywin.wakepoint/alarm"
        private const val RINGTONECHANNEL = "com.leywin.wakepoint/tone"
        private const val GEOFENCE_CHANNEL = "com.leywin.wakepoint/geofencing"
    }
}
