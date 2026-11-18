package com.leywin.wakepoint

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import org.json.JSONObject

class GeofenceBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) return

        val pendingResult = goAsync()
        val prefs = context.getSharedPreferences(
            GeofenceBroadcastReceiver.PREFS_NAME,
            Context.MODE_PRIVATE,
        )
        val encodedSpec = prefs.getString(GeofenceBroadcastReceiver.ACTIVE_SPEC_KEY, null)
        if (encodedSpec == null ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) !=
            PackageManager.PERMISSION_GRANTED ||
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.ACCESS_BACKGROUND_LOCATION,
                ) != PackageManager.PERMISSION_GRANTED)
        ) {
            pendingResult.finish()
            return
        }

        try {
            val spec = JSONObject(encodedSpec)
            val latitude = spec.getDouble("latitude")
            val longitude = spec.getDouble("longitude")
            val arrivalRadius = spec.getDouble("arrivalRadius").toFloat()
            val approachRadius = spec.optDouble("approachRadius", 0.0)
            val geofences = mutableListOf(
                createGeofence(
                    GeofenceBroadcastReceiver.ARRIVAL_ID,
                    latitude,
                    longitude,
                    arrivalRadius,
                ),
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
            val flags = PendingIntentFlags.flags()
            val geofenceIntent = Intent(context, GeofenceBroadcastReceiver::class.java)
            val geofencePendingIntent = android.app.PendingIntent.getBroadcast(
                context,
                7001,
                geofenceIntent,
                flags,
            )
            LocationServices.getGeofencingClient(context)
                .addGeofences(request, geofencePendingIntent)
                .addOnCompleteListener { pendingResult.finish() }
        } catch (_: Exception) {
            pendingResult.finish()
        }
    }

    private fun createGeofence(
        id: String,
        latitude: Double,
        longitude: Double,
        radius: Float,
    ) = Geofence.Builder()
        .setRequestId(id)
        .setCircularRegion(latitude, longitude, radius)
        .setExpirationDuration(Geofence.NEVER_EXPIRE)
        .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT)
        .setNotificationResponsiveness(10_000)
        .build()
}

private object PendingIntentFlags {
    fun flags(): Int {
        var flags = android.app.PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags = flags or android.app.PendingIntent.FLAG_MUTABLE
        }
        return flags
    }
}
