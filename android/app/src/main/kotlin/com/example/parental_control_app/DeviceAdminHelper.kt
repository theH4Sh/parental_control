package com.example.parental_control_app

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent

object DeviceAdminHelper {
	private fun adminComponent(context: Context): ComponentName =
		ComponentName(context, ParentalDeviceAdminReceiver::class.java)

	fun isAdminActive(context: Context): Boolean {
		val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
		return dpm.isAdminActive(adminComponent(context))
	}

	fun createEnableIntent(context: Context): Intent {
		val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
		intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent(context))
		intent.putExtra(
			DevicePolicyManager.EXTRA_ADD_EXPLANATION,
			context.getString(R.string.device_admin_description),
		)
		return intent
	}

	fun lockNow(context: Context) {
		if (!isAdminActive(context)) return
		val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
		dpm.lockNow()
	}
}
