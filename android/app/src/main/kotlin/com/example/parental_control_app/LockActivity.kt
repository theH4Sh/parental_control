package com.example.parental_control_app

import android.app.Activity
import android.os.Build
import android.os.Bundle
import android.view.WindowManager

class LockActivity : Activity() {
	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		instance = this
		setContentView(R.layout.activity_lock)

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
			setShowWhenLocked(true)
			setTurnScreenOn(true)
		}
		window.addFlags(
			WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
				WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
				WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED,
		)

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
			try {
				startLockTask()
			} catch (_: Exception) {
				// Screen pinning requires user consent unless device owner.
			}
		}

		LockOverlayManager.show(applicationContext)
		DeviceAdminHelper.lockNow(this)
	}

	override fun onResume() {
		super.onResume()
		if (!DeviceLockState.shouldLockDevice()) {
			stopLockTaskSafely()
			LockOverlayManager.hide()
			finish()
			return
		}
		LockOverlayManager.show(applicationContext)
	}

	override fun onDestroy() {
		stopLockTaskSafely()
		if (instance == this) {
			instance = null
		}
		super.onDestroy()
	}

	@Deprecated("Deprecated in Java")
	override fun onBackPressed() {
		// Block back navigation while locked.
	}

	override fun onUserLeaveHint() {
		super.onUserLeaveHint()
		if (DeviceLockState.shouldLockDevice()) {
			DeviceLockEnforcer.enforce(applicationContext)
		}
	}

	private fun stopLockTaskSafely() {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
			try {
				stopLockTask()
			} catch (_: Exception) {
				// ignore
			}
		}
	}

	companion object {
		@Volatile
		private var instance: LockActivity? = null

		fun finishIfShowing() {
			instance?.runOnUiThread {
				instance?.stopLockTaskSafely()
				instance?.finish()
			}
		}

		val isShowing: Boolean
			get() = instance != null
	}
}
