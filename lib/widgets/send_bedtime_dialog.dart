import 'package:flutter/material.dart';
import '../services/control_service.dart';

/// Shows a dialog for the parent to send an instant bedtime notification to a child.
Future<void> showSendBedtimeDialog(
  BuildContext context, {
  required String childId,
  required String childName,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _SendBedtimeDialog(
      childId: childId,
      childName: childName,
    ),
  );
}

class _SendBedtimeDialog extends StatefulWidget {
  final String childId;
  final String childName;

  const _SendBedtimeDialog({
    required this.childId,
    required this.childName,
  });

  @override
  State<_SendBedtimeDialog> createState() => _SendBedtimeDialogState();
}

class _SendBedtimeDialogState extends State<_SendBedtimeDialog> {
  late final TextEditingController _messageController;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(
      text: 'It\'s time to put your device away and get some rest!',
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _isSending = true);
    try {
      final result = await ParentControlService.instance.sendNotification(
        widget.childId,
        type: 'bedtime',
        title: '🌙 Bedtime',
        body: _messageController.text.trim(),
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      final delivered = result['delivered'] == true;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            delivered
                ? 'Bedtime notification sent to ${widget.childName}'
                : '${widget.childName}\'s device is offline — ask them to open the app',
          ),
          backgroundColor: delivered ? const Color(0xFF2ECC71) : const Color(0xFFFF8906),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
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
              color: const Color(0xFFE53170).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bedtime_rounded, color: Color(0xFFE53170)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Send Bedtime to ${widget.childName}',
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
              'This sends an instant notification to your child\'s device. They must have the app open or in the background.',
              style: TextStyle(color: Color(0xFFA7A9BE), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              enabled: !_isSending,
              decoration: InputDecoration(
                labelText: 'Message',
                labelStyle: const TextStyle(color: Color(0xFFA7A9BE)),
                filled: true,
                fillColor: const Color(0xFF0F0E17),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFFA7A9BE))),
        ),
        ElevatedButton.icon(
          onPressed: _isSending ? null : _send,
          icon: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F0E17)),
                )
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(_isSending ? 'Sending...' : 'Send Now'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE53170),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}
