package com.example.parental_control_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

class DeviceLockService : Service() {
	private val handler = Handler(Looper.getMainLooper())
	private val pollRunnable = object : Runnable {
		override fun run() {
			evaluateLockState()
			handler.postDelayed(this, POLL_INTERVAL_MS)
		}
	}

	override fun onBind(intent: Intent?): IBinder? = null

	override fun onCreate() {
		super.onCreate()
		isRunning = true
		instance = this
		createNotificationChannel()
		startForeground(NOTIFICATION_ID, buildNotification())
		handler.post(pollRunnable)
	}

	override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
		evaluateLockState()
		return START_STICKY
	}

	override fun onDestroy() {
		handler.removeCallbacks(pollRunnable)
		LockActivity.finishIfShowing()
		isRunning = false
		if (instance == this) {
			instance = null
		}
		super.onDestroy()
	}

	fun evaluateNow() {
		evaluateLockState()
	}

	private fun evaluateLockState() {
		if (!shouldLockDevice()) {
			LockActivity.finishIfShowing()
			return
		}

		val foreground = getForegroundPackageName()
		if (foreground != null && foreground != packageName) {
			launchLockActivity()
		}
	}

	private fun getForegroundPackageName(): String? {
		val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
		val end = System.currentTimeMillis()
		val begin = end - 10_000
		val events = usageStatsManager.queryEvents(begin, end)
		val event = UsageEvents.Event()
		var lastPackage: String? = null
		while (events.hasNextEvent()) {
			events.getNextEvent(event)
			if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
				event.eventType == UsageEvents.Event.ACTIVITY_RESUMED
			) {
				lastPackage = event.packageName
			}
		}
		return lastPackage
	}

	private fun launchLockActivity() {
		if (LockActivity.isShowing) return
		val intent = Intent(this, LockActivity::class.java).apply {
			addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
		}
		startActivity(intent)
	}

	private fun createNotificationChannel() {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
		val channel = NotificationChannel(
			CHANNEL_ID,
			"Screen time protection",
			NotificationManager.IMPORTANCE_LOW,
		).apply {
			description = "Monitors screen time and locks the device when the daily limit is reached"
		}
		val manager = getSystemService(NotificationManager::class.java)
		manager.createNotificationChannel(channel)
	}

	private fun buildNotification(): Notification {
		val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
		val pendingIntent = PendingIntent.getActivity(
			this,
			0,
			launchIntent,
			PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
		)
		return NotificationCompat.Builder(this, CHANNEL_ID)
			.setContentTitle("Screen time protection active")
			.setContentText("Device will lock when the daily limit is reached")
			.setSmallIcon(android.R.drawable.ic_lock_idle_lock)
			.setContentIntent(pendingIntent)
			.setOngoing(true)
			.setSilent(true)
			.build()
	}

	companion object {
		private const val CHANNEL_ID = "device_lock_monitor"
		private const val NOTIFICATION_ID = 1001
		private const val POLL_INTERVAL_MS = 3000L

		@Volatile
		var dailyLimitMs: Long = 0L
			private set

		@Volatile
		var totalUsedMs: Long = 0L
			private set

		@Volatile
		var lockEnabled: Boolean = true
			private set

		@Volatile
		var isRunning: Boolean = false
			private set

		@Volatile
		private var instance: DeviceLockService? = null

		fun shouldLockDevice(): Boolean =
			lockEnabled && dailyLimitMs > 0L && totalUsedMs >= dailyLimitMs

		fun updateState(limitMs: Long, usedMs: Long, enabled: Boolean) {
			dailyLimitMs = limitMs.coerceAtLeast(0L)
			totalUsedMs = usedMs.coerceAtLeast(0L)
			lockEnabled = enabled
			instance?.evaluateNow()
		}

		fun start(context: Context) {
			val intent = Intent(context, DeviceLockService::class.java)
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
				context.startForegroundService(intent)
			} else {
				context.startService(intent)
			}
		}

		fun stop(context: Context) {
			updateState(0L, 0L, false)
			LockActivity.finishIfShowing()
			context.stopService(Intent(context, DeviceLockService::class.java))
		}
	}
}
