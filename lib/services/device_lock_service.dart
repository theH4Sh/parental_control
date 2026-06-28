import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceLockService {
  DeviceLockService._();
  static final DeviceLockService instance = DeviceLockService._();

  static const MethodChannel _channel =
      MethodChannel('com.example.parental_control_app/device_lock');

  Future<void> syncLockState({
    required int dailyLimitMs,
    required int totalUsedMs,
    required bool lockEnabled,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('syncLockState', {
        'dailyLimitMs': dailyLimitMs,
        'totalUsedMs': totalUsedMs,
        'lockEnabled': lockEnabled,
      });
    } catch (e) {
      debugPrint('Device lock sync failed: $e');
    }
  }

  Future<void> stopLockMonitor() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopLockMonitor');
    } catch (e) {
      debugPrint('Stop device lock monitor failed: $e');
    }
  }

  Future<bool> isDeviceLocked() async {
    if (!Platform.isAndroid) return false;
    try {
      final locked = await _channel.invokeMethod<bool>('isDeviceLocked');
      return locked ?? false;
    } catch (e) {
      debugPrint('Device lock status check failed: $e');
      return false;
    }
  }
}
