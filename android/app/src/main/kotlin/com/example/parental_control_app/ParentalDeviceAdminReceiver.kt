package com.example.parental_control_app

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.widget.Toast

class ParentalDeviceAdminReceiver : DeviceAdminReceiver() {
	override fun onEnabled(context: Context, intent: Intent) {
		Toast.makeText(context, "Parental control device admin enabled", Toast.LENGTH_SHORT).show()
	}

	override fun onDisabled(context: Context, intent: Intent) {
		Toast.makeText(context, "Device admin disabled — parental lock weakened", Toast.LENGTH_LONG).show()
	}
}
