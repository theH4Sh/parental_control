package com.example.parental_control_app

import android.content.Context
import android.content.SharedPreferences

object DeviceLockState {
	private const val PREFS = "device_lock_state"
	private const val KEY_LIMIT = "dailyLimitMs"
	private const val KEY_USED = "totalUsedMs"
	private const val KEY_ENABLED = "lockEnabled"
	private const val KEY_UNLOCK_UNTIL = "unlockUntilMs"
	private const val KEY_FORCE = "forceDeviceLock"

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
	var unlockUntilMs: Long = 0L
		private set

	@Volatile
	var forceDeviceLock: Boolean = false
		private set

	fun shouldLockDevice(): Boolean {
		if (unlockUntilMs > 0L && System.currentTimeMillis() < unlockUntilMs) {
			return false
		}
		if (forceDeviceLock) {
			return true
		}
		return lockEnabled && dailyLimitMs > 0L && totalUsedMs >= dailyLimitMs
	}

	fun shouldMonitor(): Boolean =
		lockEnabled && (dailyLimitMs > 0L || forceDeviceLock)

	fun update(
		limitMs: Long,
		usedMs: Long,
		enabled: Boolean,
		unlockUntil: Long,
		forceLock: Boolean,
	) {
		dailyLimitMs = limitMs.coerceAtLeast(0L)
		totalUsedMs = usedMs.coerceAtLeast(0L)
		lockEnabled = enabled
		unlockUntilMs = unlockUntil.coerceAtLeast(0L)
		forceDeviceLock = forceLock
	}

	fun persist(context: Context) {
		prefs(context).edit()
			.putLong(KEY_LIMIT, dailyLimitMs)
			.putLong(KEY_USED, totalUsedMs)
			.putBoolean(KEY_ENABLED, lockEnabled)
			.putLong(KEY_UNLOCK_UNTIL, unlockUntilMs)
			.putBoolean(KEY_FORCE, forceDeviceLock)
			.apply()
	}

	fun restore(context: Context) {
		val p = prefs(context)
		update(
			limitMs = p.getLong(KEY_LIMIT, 0L),
			usedMs = p.getLong(KEY_USED, 0L),
			enabled = p.getBoolean(KEY_ENABLED, true),
			unlockUntil = p.getLong(KEY_UNLOCK_UNTIL, 0L),
			forceLock = p.getBoolean(KEY_FORCE, false),
		)
	}

	private fun prefs(context: Context): SharedPreferences =
		context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
