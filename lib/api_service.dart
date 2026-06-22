import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Singleton
  ApiService._privateConstructor();
  static final ApiService instance = ApiService._privateConstructor();

  // For Android emulator: 10.0.2.2 maps to the host machine's localhost.
  // For a physical device on the same LAN, replace with your machine's IP.
  static const String _baseUrl = 'http://10.0.2.2:8000/api';

  String? _deviceId;
  String? get deviceId => _deviceId;

  /// Initialises the service: loads or registers a device ID.
  Future<String?> init() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id');

    if (_deviceId == null) {
      _deviceId = await _registerDevice();
      if (_deviceId != null) {
        await prefs.setString('device_id', _deviceId!);
      }
    }

    debugPrint('🔑 Device ID: $_deviceId');
    return _deviceId;
  }

  /// Registers a new device with the backend, returns a unique deviceId.
  Future<String?> _registerDevice() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register-device'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 201) {
        final body = jsonDecode(response.body);
        return body['deviceId'] as String?;
      }
      debugPrint('Register device failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Register device error: $e');
      return null;
    }
  }

  /// Syncs usage statistics to the Node.js backend (MongoDB).
  Future<void> syncUsageStats({
    required String deviceId,
    required List<Map<String, dynamic>> usageData,
  }) async {
    final dateStr = DateTime.now().toIso8601String().substring(0, 10);

    final totalScreenTimeMs = usageData.fold<int>(
      0,
      (acc, item) => acc + (item['totalMs'] as int? ?? 0),
    );

    final payload = {
      'deviceId': deviceId,
      'date': dateStr,
      'deviceInfo': 'Android Device (${Platform.operatingSystemVersion})',
      'totalScreenTimeMs': totalScreenTimeMs,
      'apps': usageData,
    };

    final response = await http.post(
      Uri.parse('$_baseUrl/usage-stats'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Sync failed with status ${response.statusCode}: ${response.body}',
      );
    }

    debugPrint('✅ Usage stats synced successfully');
  }
}
