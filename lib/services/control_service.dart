import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'notification_service.dart';
import '../utils/api_config.dart';
import 'device_lock_service.dart';
import 'websocket_service.dart';

class ChildSettingsService {
  ChildSettingsService._();
  static final ChildSettingsService instance = ChildSettingsService._();

  Map<String, dynamic>? _settings;
  String? _limitNotifiedSession;
  VoidCallback? onSettingsChanged;

  Map<String, dynamic>? get settings => _settings;
  int get dailyTimeLimitMs => _settings?['dailyTimeLimitMs'] as int? ?? 0;
  bool get bedtimeEnabled => _settings?['bedtimeEnabled'] as bool? ?? false;
  bool get lockDeviceOnLimit => _settings?['lockDeviceOnLimit'] as bool? ?? true;
  bool get forceDeviceLock => _settings?['forceDeviceLock'] as bool? ?? false;
  bool get hasTimeLimit => dailyTimeLimitMs > 0 && limitStartedAt != null;

  DateTime? get limitStartedAt {
    final raw = _settings?['limitStartedAt'];
    if (raw == null) return null;
    try {
      return DateTime.parse(raw as String).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Wall-clock elapsed time since the parent started the current limit session.
  int get elapsedLimitMs {
    final started = limitStartedAt;
    if (!hasTimeLimit || started == null) return 0;
    return DateTime.now().difference(started).inMilliseconds.clamp(0, 1 << 31);
  }

  bool get isUnlockedByParent {
    final until = _settings?['unlockUntil'];
    if (until == null) return false;
    try {
      return DateTime.now().isBefore(DateTime.parse(until as String));
    } catch (_) {
      return false;
    }
  }

  DateTime? get unlockUntil {
    final until = _settings?['unlockUntil'];
    if (until == null) return null;
    try {
      return DateTime.parse(until as String);
    } catch (_) {
      return null;
    }
  }

  int get unlockUntilMs {
    final dt = unlockUntil;
    if (dt == null) return 0;
    return dt.millisecondsSinceEpoch;
  }

  bool shouldLockDevice() {
    if (isUnlockedByParent) return false;
    if (forceDeviceLock) return true;
    return lockDeviceOnLimit && isOverLimit();
  }

  bool isDeviceLocked() => shouldLockDevice();

  bool isOverLimit() => hasTimeLimit && elapsedLimitMs >= dailyTimeLimitMs;

  int get remainingMs =>
      hasTimeLimit ? (dailyTimeLimitMs - elapsedLimitMs).clamp(0, dailyTimeLimitMs) : 0;

  double get limitProgress =>
      hasTimeLimit ? (elapsedLimitMs / dailyTimeLimitMs).clamp(0.0, 1.0) : 0.0;

  Future<void> loadSettings() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/my-settings'),
        headers: AuthService.instance.authHeaders,
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        _applySettings(body['settings'] as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Failed to load child settings: $e');
    }
  }

  void _applySettings(Map<String, dynamic> settings) {
    _settings = settings;
    _updateBedtimeSchedule();
    syncDeviceLock();
    onSettingsChanged?.call();
  }

  void handleSettingsUpdate(Map<String, dynamic> settings) {
    _applySettings(settings);
  }

  Future<void> _updateBedtimeSchedule() async {
    if (bedtimeEnabled) {
      await NotificationService.instance.scheduleBedtime(
        hour: _settings?['bedtimeHour'] as int? ?? 21,
        minute: _settings?['bedtimeMinute'] as int? ?? 0,
      );
    } else {
      await NotificationService.instance.cancelBedtime();
    }
  }

  /// Returns true if a limit notification was shown for the current session.
  Future<bool> checkTimeLimit() async {
    await syncDeviceLock();
    if (!isOverLimit()) return false;

    final sessionKey = limitStartedAt?.toIso8601String();
    if (sessionKey != null && _limitNotifiedSession == sessionKey) return true;

    _limitNotifiedSession = sessionKey;
    await NotificationService.instance.show(
      title: '⏰ Time\'s Up!',
      body: 'Your screen time allowance has ended. Your device is now locked.',
      payload: 'time_limit',
    );
    return true;
  }

  Future<void> syncDeviceLock() async {
    final shouldMonitor = lockDeviceOnLimit && (dailyTimeLimitMs > 0 || forceDeviceLock);
    if (!shouldMonitor) {
      await DeviceLockService.instance.stopLockMonitor();
      return;
    }
    await DeviceLockService.instance.syncLockState(
      dailyLimitMs: dailyTimeLimitMs,
      totalUsedMs: elapsedLimitMs,
      lockEnabled: lockDeviceOnLimit,
      unlockUntilMs: unlockUntilMs,
      forceDeviceLock: forceDeviceLock,
    );
  }

  void initWebSocketListener() {
    WebSocketService.instance.onSettingsUpdated = handleSettingsUpdate;
    WebSocketService.instance.onTimeLimitReached = () {
      onSettingsChanged?.call();
    };
  }
}

class ParentControlService {
  ParentControlService._();
  static final ParentControlService instance = ParentControlService._();

  Future<Map<String, dynamic>> getChildSettings(String childId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/auth/children/$childId/settings'),
      headers: AuthService.instance.authHeaders,
    );
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return body['settings'] as Map<String, dynamic>;
    }
    throw Exception(body['error'] ?? body['message'] ?? 'Failed to load settings');
  }

  Future<Map<String, dynamic>> updateChildSettings(
    String childId, {
    int? dailyTimeLimitMs,
    int? bedtimeHour,
    int? bedtimeMinute,
    bool? bedtimeEnabled,
    bool? lockDeviceOnLimit,
    String? unlockUntil,
    bool? forceDeviceLock,
    bool clearUnlock = false,
    bool restartLimitTimer = false,
  }) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/auth/children/$childId/settings'),
      headers: AuthService.instance.authHeaders,
      body: jsonEncode({
        if (dailyTimeLimitMs != null) 'dailyTimeLimitMs': dailyTimeLimitMs,
        if (bedtimeHour != null) 'bedtimeHour': bedtimeHour,
        if (bedtimeMinute != null) 'bedtimeMinute': bedtimeMinute,
        if (bedtimeEnabled != null) 'bedtimeEnabled': bedtimeEnabled,
        if (lockDeviceOnLimit != null) 'lockDeviceOnLimit': lockDeviceOnLimit,
        if (unlockUntil != null) 'unlockUntil': unlockUntil,
        if (clearUnlock) 'unlockUntil': null,
        if (forceDeviceLock != null) 'forceDeviceLock': forceDeviceLock,
        if (restartLimitTimer) 'restartLimitTimer': true,
      }),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return body['settings'] as Map<String, dynamic>;
    }
    throw Exception(body['error'] ?? body['message'] ?? 'Failed to update settings');
  }

  Future<Map<String, dynamic>> sendNotification(
    String childId, {
    required String type,
    String? title,
    String? body,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/children/$childId/notify'),
      headers: AuthService.instance.authHeaders,
      body: jsonEncode({
        'type': type,
        if (title != null) 'title': title,
        if (body != null) 'body': body,
      }),
    );
    final bodyJson = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return bodyJson as Map<String, dynamic>;
    }
    throw Exception(bodyJson['error'] ?? bodyJson['message'] ?? 'Failed to send notification');
  }

  Future<Map<String, dynamic>> unlockDevice(
    String childId, {
    required Duration duration,
  }) async {
    final until = DateTime.now().add(duration).toUtc().toIso8601String();
    return updateChildSettings(
      childId,
      unlockUntil: until,
      forceDeviceLock: false,
    );
  }

  Future<Map<String, dynamic>> lockDeviceNow(String childId) async {
    return updateChildSettings(
      childId,
      forceDeviceLock: true,
      clearUnlock: true,
    );
  }
}
