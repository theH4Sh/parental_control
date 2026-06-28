import 'package:flutter/material.dart';
import '../services/device_lock_service.dart';

class ChildProtectionSetupCard extends StatefulWidget {
  final VoidCallback? onStatusChanged;

  const ChildProtectionSetupCard({super.key, this.onStatusChanged});

  @override
  State<ChildProtectionSetupCard> createState() => _ChildProtectionSetupCardState();
}

class _ChildProtectionSetupCardState extends State<ChildProtectionSetupCard> {
  ProtectionStatus? status;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => isLoading = true);
    final next = await DeviceLockService.instance.getProtectionStatus();
    if (!mounted) return;
    setState(() {
      status = next;
      isLoading = false;
    });
    widget.onStatusChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF8906)),
            ),
          ),
        ),
      );
    }

    final s = status!;
    if (s.isFullyProtected) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.verified_user_rounded, color: Color(0xFF2ECC71)),
          title: const Text('Deep protection enabled', style: TextStyle(color: Colors.white)),
          subtitle: const Text(
            'Device will be fully locked when screen time runs out',
            style: TextStyle(color: Color(0xFFA7A9BE), fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFA7A9BE)),
            onPressed: _loadStatus,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.shield_rounded, color: Color(0xFFFF8906)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Enable deep device lock',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Grant all permissions below so the device becomes unusable when time is up. '
              'Only a parent can unlock it remotely.',
              style: TextStyle(color: Color(0xFFA7A9BE), fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 16),
            _step('Usage access', s.usageAccess, 'Already granted on previous screen'),
            _step('Accessibility service', s.accessibility, 'Blocks all apps when locked', () async {
              await DeviceLockService.instance.openAccessibilitySettings();
              await Future.delayed(const Duration(seconds: 1));
              await _loadStatus();
            }),
            _step('Display over other apps', s.overlay, 'Shows lock screen on top of everything', () async {
              await DeviceLockService.instance.openOverlaySettings();
              await Future.delayed(const Duration(seconds: 1));
              await _loadStatus();
            }),
            _step('Device admin', s.deviceAdmin, 'Prevents bypass and locks the screen', () async {
              await DeviceLockService.instance.requestDeviceAdmin();
              await Future.delayed(const Duration(seconds: 1));
              await _loadStatus();
            }),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _loadStatus,
                icon: const Icon(Icons.refresh, color: Color(0xFFFF8906), size: 18),
                label: const Text('Refresh status', style: TextStyle(color: Color(0xFFFF8906))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(String title, bool done, String subtitle, [Future<void> Function()? onTap]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: done ? const Color(0xFF2ECC71) : const Color(0xFFE53170),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(color: Color(0xFFA7A9BE), fontSize: 11)),
              ],
            ),
          ),
          if (!done && onTap != null)
            TextButton(
              onPressed: onTap,
              child: const Text('Enable', style: TextStyle(color: Color(0xFFFF8906))),
            ),
        ],
      ),
    );
  }
}
