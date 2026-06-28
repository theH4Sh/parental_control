import 'package:flutter/material.dart';
import '../services/control_service.dart';
import '../widgets/send_bedtime_dialog.dart';

class ChildControlScreen extends StatefulWidget {
  final String childId;
  final String childName;

  const ChildControlScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<ChildControlScreen> createState() => _ChildControlScreenState();
}

class _ChildControlScreenState extends State<ChildControlScreen> {
  bool isLoading = true;
  bool isSaving = false;
  String? errorMessage;

  double limitHours = 0;
  bool bedtimeEnabled = false;
  TimeOfDay bedtime = const TimeOfDay(hour: 21, minute: 0);

  final _customTitleController = TextEditingController();
  final _customBodyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _customTitleController.dispose();
    _customBodyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final settings = await ParentControlService.instance.getChildSettings(widget.childId);
      final limitMs = settings['dailyTimeLimitMs'] as int? ?? 0;
      setState(() {
        limitHours = limitMs / (1000 * 60 * 60);
        bedtimeEnabled = settings['bedtimeEnabled'] as bool? ?? false;
        bedtime = TimeOfDay(
          hour: settings['bedtimeHour'] as int? ?? 21,
          minute: settings['bedtimeMinute'] as int? ?? 0,
        );
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() => isSaving = true);
    try {
      await ParentControlService.instance.updateChildSettings(
        widget.childId,
        dailyTimeLimitMs: (limitHours * 60 * 60 * 1000).round(),
        bedtimeHour: bedtime.hour,
        bedtimeMinute: bedtime.minute,
        bedtimeEnabled: bedtimeEnabled,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved and sent to child device'),
          backgroundColor: Color(0xFF2ECC71),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: const Color(0xFFE74C3C),
        ),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _sendNotification({required String type, String? title, String? body}) async {
    try {
      final result = await ParentControlService.instance.sendNotification(
        widget.childId,
        type: type,
        title: title,
        body: body,
      );
      if (!mounted) return;
      final delivered = result['delivered'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            delivered
                ? 'Notification delivered to ${widget.childName}\'s device'
                : '${widget.childName}\'s device is offline — ask them to open the app',
          ),
          backgroundColor: delivered ? const Color(0xFF2ECC71) : const Color(0xFFFF8906),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: const Color(0xFFE74C3C),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        title: Text('Control ${widget.childName}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF8906)))
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(errorMessage!, style: const TextStyle(color: Color(0xFFE74C3C))),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadSettings, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sectionTitle('Daily Screen Time Limit'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              limitHours == 0
                                  ? 'No limit set'
                                  : '${limitHours.toStringAsFixed(1)} hours / day',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Slider(
                              value: limitHours,
                              min: 0,
                              max: 8,
                              divisions: 16,
                              label: limitHours == 0 ? 'Off' : '${limitHours.toStringAsFixed(1)}h',
                              activeColor: const Color(0xFFFF8906),
                              onChanged: (v) => setState(() => limitHours = v),
                            ),
                            const Text(
                              'Child gets a notification when they exceed this limit.',
                              style: TextStyle(color: Color(0xFFA7A9BE), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Bedtime Schedule'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text('Enable daily bedtime reminder',
                                  style: TextStyle(color: Colors.white)),
                              subtitle: const Text(
                                'Child device shows a notification at bedtime',
                                style: TextStyle(color: Color(0xFFA7A9BE), fontSize: 12),
                              ),
                              value: bedtimeEnabled,
                              activeThumbColor: const Color(0xFFFF8906),
                              onChanged: (v) => setState(() => bedtimeEnabled = v),
                            ),
                            if (bedtimeEnabled)
                              ListTile(
                                leading: const Icon(Icons.bedtime_rounded, color: Color(0xFFE53170)),
                                title: const Text('Bedtime', style: TextStyle(color: Colors.white)),
                                subtitle: Text(
                                  bedtime.format(context),
                                  style: const TextStyle(color: Color(0xFFFF8906)),
                                ),
                                trailing: const Icon(Icons.chevron_right, color: Color(0xFFA7A9BE)),
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: bedtime,
                                  );
                                  if (picked != null) setState(() => bedtime = picked);
                                },
                              ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => showSendBedtimeDialog(
                                  context,
                                  childId: widget.childId,
                                  childName: widget.childName,
                                ),
                                icon: const Icon(Icons.nightlight_round, color: Color(0xFFE53170)),
                                label: const Text('Send Bedtime Notification Now'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFE53170),
                                  side: const BorderSide(color: Color(0xFFE53170)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Custom Notification'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            TextField(
                              controller: _customTitleController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Title',
                                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                                filled: true,
                                fillColor: const Color(0xFF0F0E17),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _customBodyController,
                              style: const TextStyle(color: Colors.white),
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: 'Message to your child...',
                                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                                filled: true,
                                fillColor: const Color(0xFF0F0E17),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  if (_customTitleController.text.trim().isEmpty ||
                                      _customBodyController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Please enter a title and message'),
                                        backgroundColor: Color(0xFFE74C3C),
                                      ),
                                    );
                                    return;
                                  }
                                  _sendNotification(
                                    type: 'custom',
                                    title: _customTitleController.text.trim(),
                                    body: _customBodyController.text.trim(),
                                  );
                                },
                                icon: const Icon(Icons.send_rounded),
                                label: const Text('Send Notification'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF8906),
                                  foregroundColor: const Color(0xFF0F0E17),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2ECC71),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
