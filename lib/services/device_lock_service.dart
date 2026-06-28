import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ProtectionStatus {
  final bool usageAccess;
  final bool accessibility;
  final bool deviceAdmin;
  final bool overlay;

  const ProtectionStatus({
    required this.usageAccess,
    required this.accessibility,
    required this.deviceAdmin,
    required this.overlay,
  });

  bool get isFullyProtected =>
      usageAccess && accessibility && deviceAdmin && overlay;

  factory ProtectionStatus.fromMap(Map<dynamic, dynamic> map) {
    return ProtectionStatus(
      usageAccess: map['usageAccess'] as bool? ?? false,
      accessibility: map['accessibility'] as bool? ?? false,
      deviceAdmin: map['deviceAdmin'] as bool? ?? false,
      overlay: map['overlay'] as bool? ?? false,
    );
  }
}

class DeviceLockService {
  DeviceLockService._();
  static final DeviceLockService instance = DeviceLockService._();

  static const MethodChannel _channel =
      MethodChannel('com.example.parental_control_app/device_lock');

  Future<void> syncLockState({
    required int dailyLimitMs,
    required int totalUsedMs,
    required bool lockEnabled,
    required int unlockUntilMs,
    required bool forceDeviceLock,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('syncLockState', {
        'dailyLimitMs': dailyLimitMs,
        'totalUsedMs': totalUsedMs,
        'lockEnabled': lockEnabled,
        'unlockUntilMs': unlockUntilMs,
        'forceDeviceLock': forceDeviceLock,
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

  Future<ProtectionStatus> getProtectionStatus() async {
    if (!Platform.isAndroid) {
      return const ProtectionStatus(
        usageAccess: false,
        accessibility: false,
        deviceAdmin: false,
        overlay: false,
      );
    }
    try {
      final map = await _channel.invokeMethod<Map<dynamic, dynamic>>('getProtectionStatus');
      return ProtectionStatus.fromMap(map ?? {});
    } catch (e) {
      debugPrint('Protection status check failed: $e');
      return const ProtectionStatus(
        usageAccess: false,
        accessibility: false,
        deviceAdmin: false,
        overlay: false,
      );
    }
  }

  Future<void> openAccessibilitySettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('openAccessibilitySettings');
  }

  Future<void> openOverlaySettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('openOverlaySettings');
  }

  Future<void> requestDeviceAdmin() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('requestDeviceAdmin');
  }
}
