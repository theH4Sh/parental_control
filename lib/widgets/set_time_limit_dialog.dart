import 'package:flutter/material.dart';
import '../services/control_service.dart';
import '../utils/time_format.dart';

/// Preset limits for quick selection (includes short values for testing).
const List<(String label, int ms)> kTimeLimitPresets = [
  ('1m', 60 * 1000),
  ('5m', 5 * 60 * 1000),
  ('15m', 15 * 60 * 1000),
  ('30m', 30 * 60 * 1000),
  ('1h', 60 * 60 * 1000),
  ('2h', 2 * 60 * 60 * 1000),
  ('Off', 0),
];

/// Dialog for the parent to set a daily screen time limit for a child.
Future<void> showSetTimeLimitDialog(
  BuildContext context, {
  required String childId,
  required String childName,
  int currentLimitMs = 0,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _SetTimeLimitDialog(
      childId: childId,
      childName: childName,
      initialLimitMs: currentLimitMs,
    ),
  );
}

class _SetTimeLimitDialog extends StatefulWidget {
  final String childId;
  final String childName;
  final int initialLimitMs;

  const _SetTimeLimitDialog({
    required this.childId,
    required this.childName,
    required this.initialLimitMs,
  });

  @override
  State<_SetTimeLimitDialog> createState() => _SetTimeLimitDialogState();
}

class _SetTimeLimitDialogState extends State<_SetTimeLimitDialog> {
  late int _limitMs;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _limitMs = widget.initialLimitMs;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ParentControlService.instance.updateChildSettings(
        widget.childId,
        dailyTimeLimitMs: _limitMs,
        restartLimitTimer: true,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _limitMs == 0
                ? 'Screen time limit removed for ${widget.childName}'
                : '${formatDurationMs(_limitMs)} timer started for ${widget.childName}',
          ),
          backgroundColor: const Color(0xFF2ECC71),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFE74C3C),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1F29),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8906).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.timer_rounded, color: Color(0xFFFF8906)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Time Limit for ${widget.childName}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The timer starts immediately when you save. Your child has this much time from right now.',
              style: TextStyle(color: Color(0xFFA7A9BE), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            Text(
              _limitMs == 0 ? 'No limit' : formatDurationMs(_limitMs),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _limitMs == 0 ? 'Unlimited screen time' : 'Countdown from when you save',
              style: const TextStyle(color: Color(0xFFA7A9BE), fontSize: 12),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kTimeLimitPresets.map((preset) {
                final (label, ms) = preset;
                return _presetChip(label, ms);
              }).toList(),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tip: use 1m or 5m to test — the countdown starts the moment you tap Save.',
              style: TextStyle(color: Color(0xFFA7A9BE), fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFFA7A9BE))),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF8906),
            foregroundColor: const Color(0xFF0F0E17),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F0E17)),
                )
              : const Text('Save Limit', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _presetChip(String label, int ms) {
    final selected = _limitMs == ms;
    return ActionChip(
      label: Text(label),
      backgroundColor: selected ? const Color(0xFFFF8906) : const Color(0xFF0F0E17),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF0F0E17) : Colors.white,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: selected ? const Color(0xFFFF8906) : const Color(0xFFA7A9BE).withValues(alpha: 0.3),
      ),
      onPressed: _isSaving ? null : () => setState(() => _limitMs = ms),
    );
  }
}
