import 'package:flutter/material.dart';

class DeviceLockedOverlay extends StatelessWidget {
  const DeviceLockedOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0F0E17),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53170).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE53170).withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.timer_off_rounded,
                    color: Color(0xFFE53170),
                    size: 64,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Time\'s Up!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'You\'ve reached your daily screen time limit. '
                  'This device is locked until tomorrow or your parent changes the limit.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFA7A9BE),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Ask a parent if you need more time.',
                  style: TextStyle(
                    color: Color(0xFFFF8906),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
