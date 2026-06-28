package com.example.parental_control_app

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent

class AppLockAccessibilityService : AccessibilityService() {
	private val handler = Handler(Looper.getMainLooper())
	private var lastBlockedPackage: String? = null
	private var lastBlockAt = 0L

	override fun onAccessibilityEvent(event: AccessibilityEvent?) {
		if (event == null) return
		if (!DeviceLockState.shouldLockDevice()) return
		if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
			event.eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
		) {
			return
		}

		val packageName = event.packageName?.toString() ?: return
		if (isAllowedPackage(packageName)) return

		val now = System.currentTimeMillis()
		if (packageName == lastBlockedPackage && now - lastBlockAt < 800L) {
			return
		}
		lastBlockedPackage = packageName
		lastBlockAt = now

		enforceLock(packageName)
	}

	private fun isAllowedPackage(packageName: String): Boolean {
		if (packageName == applicationContext.packageName) return true
		// Allow system UI shell briefly during transitions
		if (packageName == "com.android.systemui") return true
		return false
	}

	private fun enforceLock(blockedPackage: String) {
		performGlobalAction(GLOBAL_ACTION_HOME)
		LockOverlayManager.show(applicationContext)
		handler.postDelayed({
			if (!DeviceLockState.shouldLockDevice()) return@postDelayed
			DeviceAdminHelper.lockNow(applicationContext)
			val intent = Intent(applicationContext, LockActivity::class.java).apply {
				addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
			}
			startActivity(intent)
		}, 150L)
	}

	override fun onInterrupt() = Unit

	override fun onServiceConnected() {
		super.onServiceConnected()
		if (DeviceLockState.shouldLockDevice()) {
			LockOverlayManager.show(applicationContext)
		}
	}
}
