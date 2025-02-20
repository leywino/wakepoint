package com.leywin.wakepoint

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.WindowManager

class AlarmActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Turn on the screen and allow the activity to be shown over the lock screen
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )

        // Start the Flutter app when the alarm is triggered
        val intent = Intent(this, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)

        finish() // Close the native alarm activity after launching Flutter
    }
}