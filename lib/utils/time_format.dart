String formatDurationMs(int ms) {
  final duration = Duration(milliseconds: ms);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);

  if (hours > 0) {
    return '${hours}h ${minutes}m';
  } else if (minutes > 0) {
    return '${minutes}m';
  } else {
    final secs = duration.inSeconds.remainder(60);
    return '${secs}s';
  }
}
