package com.example.parental_control_app

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val USAGE_CHANNEL = "com.example.parental_control_app/usage"
	private val LOCK_CHANNEL = "com.example.parental_control_app/device_lock"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USAGE_CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"hasUsageAccess" -> {
					result.success(hasUsageAccess())
				}
				"openUsageAccessSettings" -> {
					val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
					intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
					startActivity(intent)
					result.success(true)
				}
				"getAppDetails" -> {
					val packageNames = call.arguments as? List<*>
					result.success(getAppDetails(packageNames))
				}
				else -> result.notImplemented()
			}
		}
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCK_CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"syncLockState" -> {
					val limitMs = call.argument<Number>("dailyLimitMs")?.toLong() ?: 0L
					val totalMs = call.argument<Number>("totalUsedMs")?.toLong() ?: 0L
					val lockEnabled = call.argument<Boolean>("lockEnabled") ?: true
					val unlockUntilMs = call.argument<Number>("unlockUntilMs")?.toLong() ?: 0L
					val forceLock = call.argument<Boolean>("forceDeviceLock") ?: false
					DeviceLockService.updateState(this, limitMs, totalMs, lockEnabled, unlockUntilMs, forceLock)
					if (DeviceLockState.shouldMonitor()) {
						DeviceLockService.start(this)
					} else {
						DeviceLockService.stop(this)
					}
					result.success(true)
				}
				"stopLockMonitor" -> {
					DeviceLockService.stop(this)
					result.success(true)
				}
				"isDeviceLocked" -> {
					result.success(DeviceLockService.shouldLockDevice())
				}
				"getProtectionStatus" -> {
					result.success(ProtectionHelper.getProtectionStatus(this))
				}
				"openAccessibilitySettings" -> {
					ProtectionHelper.openAccessibilitySettings(this)
					result.success(true)
				}
				"openOverlaySettings" -> {
					LockOverlayManager.openOverlaySettings(this)
					result.success(true)
				}
				"requestDeviceAdmin" -> {
					startActivity(DeviceAdminHelper.createEnableIntent(this))
					result.success(true)
				}
				else -> result.notImplemented()
			}
		}
	}

	private fun hasUsageAccess(): Boolean {
		val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
		val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
			appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
		} else {
			appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
		}
		return mode == AppOpsManager.MODE_ALLOWED
	}

	private fun getAppDetails(packageNames: List<*>?): List<Map<String, Any?>> {
		if (packageNames == null) return emptyList()
		return packageNames.mapNotNull { pkgObj ->
			val pkg = pkgObj as? String ?: return@mapNotNull null
			try {
				val appInfo = packageManager.getApplicationInfo(pkg, 0)
				val label = packageManager.getApplicationLabel(appInfo).toString()
				val icon = packageManager.getApplicationIcon(appInfo)
				val bytes = drawableToPng(icon)
				mapOf(
					"packageName" to pkg,
					"appName" to label,
					"icon" to bytes,
				)
			} catch (_: PackageManager.NameNotFoundException) {
				null
			}
		}
	}

	private fun drawableToPng(drawable: Drawable): ByteArray {
		val bitmap = when (drawable) {
			is BitmapDrawable -> drawable.bitmap
			else -> {
				val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 1
				val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 1
				val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
				val canvas = Canvas(bmp)
				drawable.setBounds(0, 0, canvas.width, canvas.height)
				drawable.draw(canvas)
				bmp
			}
		}
		val stream = java.io.ByteArrayOutputStream()
		bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
		return stream.toByteArray()
	}
}
