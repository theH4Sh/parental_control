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
		window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
	}

	override fun onResume() {
		super.onResume()
		if (!DeviceLockService.shouldLockDevice()) {
			finish()
		}
	}

	override fun onDestroy() {
		if (instance == this) {
			instance = null
		}
		super.onDestroy()
	}

	@Deprecated("Deprecated in Java")
	override fun onBackPressed() {
		// Block back navigation while locked.
	}

	companion object {
		@Volatile
		private var instance: LockActivity? = null

		fun finishIfShowing() {
			instance?.runOnUiThread {
				instance?.finish()
			}
		}

		val isShowing: Boolean
			get() = instance != null
	}
}
