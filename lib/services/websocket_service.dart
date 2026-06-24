import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../utils/api_config.dart';
import 'auth_service.dart';
import 'notification_service.dart';

typedef SettingsCallback = void Function(Map<String, dynamic> settings);

class WebSocketService {
  WebSocketService._();
  static final WebSocketService instance = WebSocketService._();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  SettingsCallback? onSettingsUpdated;

  bool get isConnected => _channel != null;

  void connect() {
    final token = AuthService.instance.token;
    if (token == null || token.isEmpty) return;

    disconnect();
    final uri = Uri.parse('${ApiConfig.wsUrl}?token=$token');

    try {
      _channel = WebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('WebSocket closed');
          _scheduleReconnect();
        },
      );
      debugPrint('🔌 WebSocket connecting to $uri');
    } catch (e) {
      debugPrint('WebSocket connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      final type = message['type'] as String?;
      final payload = message['payload'];

      switch (type) {
        case 'connected':
          debugPrint('✅ WebSocket connected');
          _reconnectTimer?.cancel();
          break;
        case 'notification':
          if (payload is Map) {
            final map = Map<String, dynamic>.from(payload);
            NotificationService.instance.show(
              title: map['title'] as String? ?? 'Parental Control',
              body: map['body'] as String? ?? '',
              payload: map['notificationType'] as String?,
            );
          }
          break;
        case 'settings_updated':
          if (payload is Map && onSettingsUpdated != null) {
            onSettingsUpdated!(Map<String, dynamic>.from(payload));
          }
          break;
      }
    } catch (e) {
      debugPrint('WebSocket message parse error: $e');
    }
  }

  void _scheduleReconnect() {
    _subscription?.cancel();
    _channel = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), connect);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
