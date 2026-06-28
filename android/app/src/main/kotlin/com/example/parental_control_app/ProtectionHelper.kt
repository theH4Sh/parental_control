package com.example.parental_control_app

import android.content.Context
import android.content.Intent
import android.provider.Settings

object ProtectionHelper {
	fun isAccessibilityEnabled(context: Context): Boolean {
		val enabled = Settings.Secure.getInt(
			context.contentResolver,
			Settings.Secure.ACCESSIBILITY_ENABLED,
			0,
		) == 1
		if (!enabled) return false
		val services = Settings.Secure.getString(
			context.contentResolver,
			Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
		) ?: return false
		val expected = "${context.packageName}/${AppLockAccessibilityService::class.java.canonicalName}"
		return services.split(':').any { it.equals(expected, ignoreCase = true) }
	}

	fun openAccessibilitySettings(context: Context) {
		val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
			addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
		}
		context.startActivity(intent)
	}

	fun getProtectionStatus(context: Context): Map<String, Boolean> {
		return mapOf(
			"usageAccess" to hasUsageAccess(context),
			"accessibility" to isAccessibilityEnabled(context),
			"deviceAdmin" to DeviceAdminHelper.isAdminActive(context),
			"overlay" to LockOverlayManager.hasOverlayPermission(context),
		)
	}

	private fun hasUsageAccess(context: Context): Boolean {
		val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
		val mode = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
			appOps.unsafeCheckOpNoThrow(
				android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
				android.os.Process.myUid(),
				context.packageName,
			)
		} else {
			appOps.checkOpNoThrow(
				android.app.AppOpsManager.OPSTR_GET_USAGE_STATS,
				android.os.Process.myUid(),
				context.packageName,
			)
		}
		return mode == android.app.AppOpsManager.MODE_ALLOWED
	}
}
