package com.example.parental_control_app

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.TextView

object LockOverlayManager {
	private var overlayView: View? = null
	private var windowManager: WindowManager? = null

	fun hasOverlayPermission(context: Context): Boolean =
		Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)

	fun openOverlaySettings(context: Context) {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
		val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
			data = android.net.Uri.parse("package:${context.packageName}")
			addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
		}
		context.startActivity(intent)
	}

	fun show(context: Context) {
		if (!hasOverlayPermission(context)) return
		if (overlayView != null) return

		windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
		val inflater = LayoutInflater.from(context)
		val view = inflater.inflate(R.layout.overlay_lock, null)
		view.findViewById<TextView>(R.id.overlay_title)?.text = "Time's Up!"
		view.isClickable = true
		view.isFocusable = true
		view.setOnTouchListener { _, _ -> true }

		val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
		} else {
			@Suppress("DEPRECATION")
			WindowManager.LayoutParams.TYPE_PHONE
		}

		val params = WindowManager.LayoutParams(
			WindowManager.LayoutParams.MATCH_PARENT,
			WindowManager.LayoutParams.MATCH_PARENT,
			layoutType,
			WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
				WindowManager.LayoutParams.FLAG_FULLSCREEN,
			PixelFormat.OPAQUE,
		).apply {
			gravity = Gravity.TOP or Gravity.START
		}

		try {
			windowManager?.addView(view, params)
			overlayView = view
		} catch (_: Exception) {
			overlayView = null
		}
	}

	fun hide() {
		val view = overlayView ?: return
		try {
			windowManager?.removeView(view)
		} catch (_: Exception) {
			// ignore
		}
		overlayView = null
	}

	fun sync(context: Context) {
		Handler(Looper.getMainLooper()).post {
			if (DeviceLockState.shouldLockDevice()) {
				show(context.applicationContext)
			} else {
				hide()
			}
		}
	}
}
