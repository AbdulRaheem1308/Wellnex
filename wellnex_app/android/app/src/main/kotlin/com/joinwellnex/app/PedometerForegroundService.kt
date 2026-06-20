package com.joinwellnex.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.content.SharedPreferences
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class PedometerForegroundService : Service(), SensorEventListener {
    companion object {
        const val CHANNEL_ID = "PedometerServiceChannel"
        const val NOTIFICATION_ID = 1
        const val PREFS_NAME = "pedometer_prefs"
        const val KEY_BASELINE = "pedometer_baseline_steps"
        const val KEY_LAST_DATE = "pedometer_last_sync_date"
        const val KEY_TODAY_STEPS = "pedometer_today_steps"

        fun getTodaySteps(context: Context): Int {
            val sp = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return sp.getInt(KEY_TODAY_STEPS, 0)
        }
    }

    private lateinit var sensorManager: SensorManager
    private var stepSensor: Sensor? = null
    private var baseline: Int = -1
    private var lastSyncDate: String = ""
    private val prefs: SharedPreferences by lazy {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        stepSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        stepSensor?.let { sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) }
        // Load persisted baseline/date
        baseline = prefs.getInt(KEY_BASELINE, -1)
        lastSyncDate = prefs.getString(KEY_LAST_DATE, "") ?: ""
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Wellnex Pedometer Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(serviceChannel)
        }
    }

    private fun buildNotification(): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Wellnex is tracking your steps")
            .setContentText("Your activity is being recorded in the background.")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        sensorManager.unregisterListener(this)
    }

    // SensorEventListener implementation
    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type != Sensor.TYPE_STEP_COUNTER) return
        val sensorSteps = event.values[0].toInt()
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        // Reset baseline if new day or not set
        if (lastSyncDate != todayStr || baseline == -1) {
            baseline = sensorSteps
            lastSyncDate = todayStr
            prefs.edit().putInt(KEY_BASELINE, baseline).putString(KEY_LAST_DATE, lastSyncDate).apply()
            Log.d("PedometerService", "Baseline reset for $todayStr to $baseline")
        }
        var stepsToday = sensorSteps - baseline
        if (stepsToday < 0) {
            // Device reboot scenario – reset baseline
            baseline = sensorSteps
            prefs.edit().putInt(KEY_BASELINE, baseline).apply()
            stepsToday = 0
        }
        // Persist today steps
        prefs.edit().putInt(KEY_TODAY_STEPS, stepsToday).apply()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // No‑op
    }

    // Static helper to retrieve current steps from SharedPreferences

}
