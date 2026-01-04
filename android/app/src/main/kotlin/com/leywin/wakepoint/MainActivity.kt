package com.leywin.wakepoint

import android.app.KeyguardManager
import android.app.NotificationManager // Added
import android.content.Context
import android.content.Intent
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings // Added
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var ringtone: Ringtone? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Ensure flags are set immediately on creation
        setShowWhenLockedCompat()
        turnScreenOnCompat()
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        // CRITICAL: This ensures the window is configured to show over lockscreen
        // the moment it attaches to the view hierarchy.
        setShowWhenLockedCompat()
        turnScreenOnCompat()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Ensure flags are reapplied if app is brought to front from background
        setShowWhenLockedCompat()
        turnScreenOnCompat()
    }

    override fun onResume() {
        super.onResume()
        // Try to unlock the phone (dismiss the swipe/pin screen) ONLY when we are visible
        requestDismissKeyguard()
    }

    private fun setShowWhenLockedCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
        }
    }

    private fun turnScreenOnCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }

        // Keep screen on while alarm is ringing
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun requestDismissKeyguard() {
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            keyguardManager.requestDismissKeyguard(this, null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // --- 1. EXISTING ALARM CHANNEL ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARMCHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                if (call.method == "startAlarm") {
                    setShowWhenLockedCompat()
                    turnScreenOnCompat()

                    val intent = Intent(this, MainActivity::class.java)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    startActivity(intent)

                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }

        // --- 2. EXISTING RINGTONE CHANNEL ---
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

        // --- 3. NEW PERMISSION CHANNEL (For Android 14+) ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSIONCHANNEL)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "checkFSI" -> {
                        // Check if we have the permission (Only needed on API 34+)
                        if (Build.VERSION.SDK_INT >= 34) { // Build.VERSION_CODES.UPSIDE_DOWN_CAKE
                            val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                            result.success(nm.canUseFullScreenIntent())
                        } else {
                            // On Android 13 and below, we always have it
                            result.success(true)
                        }
                    }
                    "requestFSI" -> {
                        // Open Settings page for user to grant it
                        if (Build.VERSION.SDK_INT >= 34) {
                            try {
                                val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT)
                                intent.data = Uri.parse("package:$packageName")
                                startActivity(intent)
                                result.success(true)
                            } catch (e: Exception) {
                                // Fallback if specific settings page fails
                                val intent = Intent(Settings.ACTION_SETTINGS)
                                startActivity(intent)
                                result.success(false)
                            }
                        } else {
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun playTone(type: String, result: MethodChannel.Result) {
        try {
            val soundType = when (type) {
                "alarm" -> RingtoneManager.TYPE_ALARM
                else -> RingtoneManager.TYPE_RINGTONE
            }
            val uri: Uri = RingtoneManager.getDefaultUri(soundType)
            ringtone = RingtoneManager.getRingtone(applicationContext, uri)
            ringtone?.play()
            result.success(null)
        } catch (e: Exception) {
            e.printStackTrace()
            result.error("AUDIO_ERROR", "Could not play tone", null)
        }
    }

    private fun stopTone(result: MethodChannel.Result) {
        ringtone?.stop()
        result.success(null)
    }

    companion object {
        private const val ALARMCHANNEL = "com.leywin.wakepoint/alarm"
        private const val RINGTONECHANNEL = "com.leywin.wakepoint/tone"
        private const val PERMISSIONCHANNEL = "com.leywin.wakepoint/permission" // Added
    }
}