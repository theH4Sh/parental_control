package com.example.parental_control_app

import android.content.Context
import android.content.Intent

object DeviceLockEnforcer {
	fun enforce(context: Context) {
		if (!DeviceLockState.shouldLockDevice()) {
			release(context)
			return
		}

		LockOverlayManager.show(context.applicationContext)
		DeviceAdminHelper.lockNow(context)

		if (!LockActivity.isShowing) {
			val intent = Intent(context, LockActivity::class.java).apply {
				addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
			}
			context.startActivity(intent)
		}
	}

	fun release(context: Context) {
		LockOverlayManager.hide()
		LockActivity.finishIfShowing()
	}
}
