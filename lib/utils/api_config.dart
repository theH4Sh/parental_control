import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // Your computer's current LAN IP address (needed when testing on physical mobile devices).
  static const String localLanIp = '192.168.100.8';

  /// Override at build/run time: flutter run --dart-define=API_HOST=192.168.1.5
  static const String _apiHostOverride = String.fromEnvironment('API_HOST');

  /// Set true on physical Android devices: flutter run --dart-define=PHYSICAL_DEVICE=true
  static const bool physicalDevice =
      bool.fromEnvironment('PHYSICAL_DEVICE', defaultValue: false);

  /// Returns the base API URL dynamically depending on the current platform/device.
  static String get baseUrl {
    if (_apiHostOverride.isNotEmpty) {
      return 'http://$_apiHostOverride:8000/api';
    }

    if (kIsWeb) {
      return 'http://localhost:8000/api';
    }

    if (Platform.isAndroid) {
      if (physicalDevice) {
        return 'http://$localLanIp:8000/api';
      }
      // Android emulator loops back to host machine via 10.0.2.2.
      return 'http://10.0.2.2:8000/api';
    }

    // Linux desktop, macOS, Windows desktop, iOS Simulator, etc.
    return 'http://localhost:8000/api';
  }
}
