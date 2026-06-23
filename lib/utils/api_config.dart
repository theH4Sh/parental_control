import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // Your computer's current LAN IP address (needed when testing on physical mobile devices).
  static const String localLanIp = '192.168.100.8';

  /// Returns the base API URL dynamically depending on the current platform/device.
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000/api';
    }
    
    if (Platform.isAndroid) {
      // Android emulator loops back to host machine via 10.0.2.2.
      // If testing on a physical Android device, replace with your host machine's LAN IP (e.g. '192.168.100.8').
      return 'http://10.0.2.2:8000/api';
    }
    
    // Linux desktop, macOS, Windows desktop, iOS Simulator, etc.
    return 'http://localhost:8000/api';
  }
}
