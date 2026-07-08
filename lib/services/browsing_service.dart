import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BrowsingService {
  BrowsingService._();
  static final BrowsingService instance = BrowsingService._();

  static const MethodChannel _channel =
      MethodChannel('com.example.parental_control_app/browsing');

  Future<List<Map<String, dynamic>>> drainPendingEvents() async {
    if (!Platform.isAndroid) return [];
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getPendingBrowsingEvents');
      if (result == null) return [];
      return result
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (e) {
      debugPrint('Failed to drain browsing events: $e');
      return [];
    }
  }

  Future<int> pendingCount() async {
    if (!Platform.isAndroid) return 0;
    try {
      final count = await _channel.invokeMethod<int>('getPendingBrowsingCount');
      return count ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
