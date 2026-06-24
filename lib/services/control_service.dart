import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'notification_service.dart';
import '../utils/api_config.dart';
import 'websocket_service.dart';

class ChildSettingsService {
  ChildSettingsService._();
  static final ChildSettingsService instance = ChildSettingsService._();

  Map<String, dynamic>? _settings;
  String? _limitNotifiedDate;

  Map<String, dynamic>? get settings => _settings;
  int get dailyTimeLimitMs => _settings?['dailyTimeLimitMs'] as int? ?? 0;
  bool get bedtimeEnabled => _settings?['bedtimeEnabled'] as bool? ?? false;

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

  /// Returns true if a limit notification was shown.
  Future<bool> checkTimeLimit(int totalScreenTimeMs) async {
    if (dailyTimeLimitMs <= 0) return false;
    if (totalScreenTimeMs < dailyTimeLimitMs) return false;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (_limitNotifiedDate == today) return false;

    _limitNotifiedDate = today;
    await NotificationService.instance.show(
      title: '⏰ Screen Time Limit Reached',
      body: 'You\'ve used your allowed screen time for today. Please take a break!',
      payload: 'time_limit',
    );
    return true;
  }

  void initWebSocketListener() {
    WebSocketService.instance.onSettingsUpdated = handleSettingsUpdate;
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
  }) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/auth/children/$childId/settings'),
      headers: AuthService.instance.authHeaders,
      body: jsonEncode({
        if (dailyTimeLimitMs != null) 'dailyTimeLimitMs': dailyTimeLimitMs,
        if (bedtimeHour != null) 'bedtimeHour': bedtimeHour,
        if (bedtimeMinute != null) 'bedtimeMinute': bedtimeMinute,
        if (bedtimeEnabled != null) 'bedtimeEnabled': bedtimeEnabled,
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
}
