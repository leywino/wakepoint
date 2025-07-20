package com.leywin.wakepoint

import android.content.Intent
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var ringtone: Ringtone? = null

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
    }
}