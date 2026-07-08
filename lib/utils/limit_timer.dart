/// Helpers for countdown-style screen time limits (starts when parent sets the limit).
class LimitTimer {
  static int elapsedMs(Map<String, dynamic>? settings) {
    final limitMs = settings?['dailyTimeLimitMs'] as int? ?? 0;
    final startedRaw = settings?['limitStartedAt'];
    if (limitMs <= 0 || startedRaw == null) return 0;
    try {
      final started = DateTime.parse(startedRaw as String).toLocal();
      return DateTime.now().difference(started).inMilliseconds.clamp(0, 1 << 31);
    } catch (_) {
      return 0;
    }
  }

  static int remainingMs(Map<String, dynamic>? settings) {
    final limitMs = settings?['dailyTimeLimitMs'] as int? ?? 0;
    if (limitMs <= 0) return 0;
    return (limitMs - elapsedMs(settings)).clamp(0, limitMs);
  }

  static bool isOverLimit(Map<String, dynamic>? settings) {
    final limitMs = settings?['dailyTimeLimitMs'] as int? ?? 0;
    if (limitMs <= 0 || settings?['limitStartedAt'] == null) return false;
    return elapsedMs(settings) >= limitMs;
  }

  static bool isActive(Map<String, dynamic>? settings) {
    final limitMs = settings?['dailyTimeLimitMs'] as int? ?? 0;
    return limitMs > 0 && settings?['limitStartedAt'] != null;
  }
}
