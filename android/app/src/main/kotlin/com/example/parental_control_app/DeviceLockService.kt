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
			val interval = if (DeviceLockState.shouldLockDevice()) LOCKED_POLL_MS else POLL_INTERVAL_MS
			handler.postDelayed(this, interval)
		}
	}

	override fun onBind(intent: Intent?): IBinder? = null

	override fun onCreate() {
		super.onCreate()
		isRunning = true
		instance = this
		DeviceLockState.restore(applicationContext)
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
		if (!DeviceLockState.shouldLockDevice()) {
			DeviceLockEnforcer.release(applicationContext)
			return
		}

		DeviceLockEnforcer.enforce(applicationContext)

		val foreground = getForegroundPackageName()
		if (foreground != null && foreground != packageName) {
			DeviceLockEnforcer.enforce(applicationContext)
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
				(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
					event.eventType == UsageEvents.Event.ACTIVITY_RESUMED)
			) {
				lastPackage = event.packageName
			}
		}
		return lastPackage
	}

	private fun createNotificationChannel() {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
		val channel = NotificationChannel(
			CHANNEL_ID,
			"Screen time protection",
			NotificationManager.IMPORTANCE_LOW,
		).apply {
			description = "Keeps parental lock active in the background"
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
		val text = if (DeviceLockState.shouldLockDevice()) {
			"Device is locked — waiting for parent approval"
		} else {
			"Monitoring screen time limits"
		}
		return NotificationCompat.Builder(this, CHANNEL_ID)
			.setContentTitle("Parental control active")
			.setContentText(text)
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
		private const val LOCKED_POLL_MS = 1000L

		@Volatile
		var isRunning: Boolean = false
			private set

		@Volatile
		private var instance: DeviceLockService? = null

		fun shouldLockDevice(): Boolean = DeviceLockState.shouldLockDevice()

		fun updateState(
			context: Context,
			limitMs: Long,
			usedMs: Long,
			enabled: Boolean,
			unlockUntilMs: Long,
			forceLock: Boolean,
		) {
			DeviceLockState.update(limitMs, usedMs, enabled, unlockUntilMs, forceLock)
			DeviceLockState.persist(context.applicationContext)
			instance?.evaluateNow()
			if (DeviceLockState.shouldLockDevice()) {
				DeviceLockEnforcer.enforce(context.applicationContext)
			} else {
				DeviceLockEnforcer.release(context.applicationContext)
			}
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
			updateState(context, 0L, 0L, false, 0L, false)
			context.stopService(Intent(context, DeviceLockService::class.java))
		}
	}
}
