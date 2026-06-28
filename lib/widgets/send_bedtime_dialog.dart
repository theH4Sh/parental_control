import 'package:flutter/material.dart';
import '../services/control_service.dart';

/// Shows a dialog for the parent to send an instant bedtime notification to a child.
Future<void> showSendBedtimeDialog(
  BuildContext context, {
  required String childId,
  required String childName,
}) async {
  final messageController = TextEditingController(
    text: 'It\'s time to put your device away and get some rest!',
  );
  var isSending = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
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
                    'Send Bedtime to $childName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This sends an instant notification to your child\'s device. They must have the app open or in the background.',
                  style: TextStyle(color: Color(0xFFA7A9BE), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
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
            actions: [
              TextButton(
                onPressed: isSending ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFFA7A9BE))),
              ),
              ElevatedButton.icon(
                onPressed: isSending
                    ? null
                    : () async {
                        setDialogState(() => isSending = true);
                        try {
                          final result = await ParentControlService.instance.sendNotification(
                            childId,
                            type: 'bedtime',
                            title: '🌙 Bedtime',
                            body: messageController.text.trim(),
                          );
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          if (!context.mounted) return;
                          final delivered = result['delivered'] == true;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                delivered
                                    ? 'Bedtime notification sent to $childName'
                                    : '$childName\'s device is offline — ask them to open the app',
                              ),
                              backgroundColor:
                                  delivered ? const Color(0xFF2ECC71) : const Color(0xFFFF8906),
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => isSending = false);
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                e.toString().replaceFirst('Exception: ', ''),
                              ),
                              backgroundColor: const Color(0xFFE74C3C),
                            ),
                          );
                        }
                      },
                icon: isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F0E17)),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(isSending ? 'Sending...' : 'Send Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53170),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          );
        },
      );
    },
  );

  messageController.dispose();
}
