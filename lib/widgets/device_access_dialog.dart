import 'package:flutter/material.dart';
import '../services/control_service.dart';

Future<void> showDeviceAccessDialog(
  BuildContext context, {
  required String childId,
  required String childName,
  bool currentlyLocked = false,
  String? unlockUntil,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _DeviceAccessDialog(
      childId: childId,
      childName: childName,
      currentlyLocked: currentlyLocked,
      unlockUntil: unlockUntil,
    ),
  );
}

class _DeviceAccessDialog extends StatefulWidget {
  final String childId;
  final String childName;
  final bool currentlyLocked;
  final String? unlockUntil;

  const _DeviceAccessDialog({
    required this.childId,
    required this.childName,
    required this.currentlyLocked,
    this.unlockUntil,
  });

  @override
  State<_DeviceAccessDialog> createState() => _DeviceAccessDialogState();
}

class _DeviceAccessDialogState extends State<_DeviceAccessDialog> {
  bool isSaving = false;

  Future<void> _unlockFor(Duration duration) async {
    setState(() => isSaving = true);
    try {
      await ParentControlService.instance.unlockDevice(widget.childId, duration: duration);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.childName}\'s device unlocked'),
          backgroundColor: const Color(0xFF2ECC71),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFE74C3C),
        ),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _lockNow() async {
    setState(() => isSaving = true);
    try {
      await ParentControlService.instance.lockDeviceNow(widget.childId);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.childName}\'s device locked'),
          backgroundColor: const Color(0xFFE53170),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFE74C3C),
        ),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlockLabel = widget.unlockUntil != null
        ? 'Unlocked until ${_formatUnlockUntil(widget.unlockUntil!)}'
        : null;

    return AlertDialog(
      backgroundColor: const Color(0xFF1E1F29),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            widget.currentlyLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
            color: widget.currentlyLocked ? const Color(0xFFE53170) : const Color(0xFF2ECC71),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.childName,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.currentlyLocked
                ? 'Device is locked. Grant temporary access or keep it locked.'
                : 'Grant temporary access or lock the device immediately.',
            style: const TextStyle(color: Color(0xFFA7A9BE), height: 1.4),
          ),
          if (unlockLabel != null) ...[
            const SizedBox(height: 12),
            Text(
              unlockLabel,
              style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 16),
          const Text('Unlock for:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _durationChip('15m', const Duration(minutes: 15)),
              _durationChip('30m', const Duration(minutes: 30)),
              _durationChip('1h', const Duration(hours: 1)),
              _durationChip('2h', const Duration(hours: 2)),
              _durationChip('Rest of day', _restOfDay()),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFFA7A9BE))),
        ),
        OutlinedButton(
          onPressed: isSaving ? null : _lockNow,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE53170),
            side: const BorderSide(color: Color(0xFFE53170)),
          ),
          child: isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE53170)),
                )
              : const Text('Lock now'),
        ),
      ],
    );
  }

  Widget _durationChip(String label, Duration duration) {
    return ActionChip(
      label: Text(label),
      backgroundColor: const Color(0xFF0F0E17),
      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      side: BorderSide(color: const Color(0xFFFF8906).withValues(alpha: 0.5)),
      onPressed: isSaving ? null : () => _unlockFor(duration),
    );
  }

  Duration _restOfDay() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return end.difference(now);
  }

  String _formatUnlockUntil(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return iso;
    }
  }
}
