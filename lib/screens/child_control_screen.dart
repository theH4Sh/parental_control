import 'package:flutter/material.dart';
import '../services/control_service.dart';
import '../utils/time_format.dart';
import '../widgets/send_bedtime_dialog.dart';
import '../widgets/set_time_limit_dialog.dart' show kTimeLimitPresets;
import '../widgets/device_access_dialog.dart';
import 'child_web_activity_screen.dart';
import 'child_account_screen.dart';

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

  int limitMs = 0;
  bool bedtimeEnabled = false;
  bool lockDeviceOnLimit = true;
  bool forceDeviceLock = false;
  String? unlockUntil;
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
      final loadedLimitMs = settings['dailyTimeLimitMs'] as int? ?? 0;
      setState(() {
        limitMs = loadedLimitMs;
        bedtimeEnabled = settings['bedtimeEnabled'] as bool? ?? false;
        lockDeviceOnLimit = settings['lockDeviceOnLimit'] as bool? ?? true;
        forceDeviceLock = settings['forceDeviceLock'] as bool? ?? false;
        unlockUntil = settings['unlockUntil'] as String?;
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
        dailyTimeLimitMs: limitMs,
        bedtimeHour: bedtime.hour,
        bedtimeMinute: bedtime.minute,
        bedtimeEnabled: bedtimeEnabled,
        lockDeviceOnLimit: lockDeviceOnLimit,
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
                    _sectionTitle('Child Account'),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.manage_accounts_rounded, color: Color(0xFFE53170)),
                        title: const Text('Username & password', style: TextStyle(color: Colors.white)),
                        subtitle: const Text(
                          'Update login details for this child',
                          style: TextStyle(color: Color(0xFFA7A9BE), fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFFA7A9BE)),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChildAccountScreen(
                                childId: widget.childId,
                                childName: widget.childName,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Device Access'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              forceDeviceLock
                                  ? 'Device is locked by you'
                                  : unlockUntil != null &&
                                          DateTime.now().isBefore(DateTime.parse(unlockUntil!))
                                      ? 'Device temporarily unlocked'
                                      : 'Device follows screen time rules',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Lock the device immediately or grant temporary access. '
                              'Deep lock requires the child to enable all protection permissions on their phone.',
                              style: TextStyle(color: Color(0xFFA7A9BE), fontSize: 12, height: 1.4),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => showDeviceAccessDialog(
                                  context,
                                  childId: widget.childId,
                                  childName: widget.childName,
                                  currentlyLocked: forceDeviceLock,
                                  unlockUntil: unlockUntil,
                                ).then((_) => _loadSettings()),
                                icon: const Icon(Icons.lock_open_rounded),
                                label: const Text('Lock / Unlock Device'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2ECC71),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ChildWebActivityScreen(
                                        childId: widget.childId,
                                        childName: widget.childName,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.language_rounded, color: Color(0xFFFF8906)),
                                label: const Text('View Web Activity'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFFF8906),
                                  side: const BorderSide(color: Color(0xFFFF8906)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Screen Time Timer'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              limitMs == 0
                                  ? 'No timer set'
                                  : '${formatDurationMs(limitMs)} countdown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Timer starts when you save a new duration. Use 1m or 5m to test quickly.',
                              style: TextStyle(color: Color(0xFFA7A9BE), fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: kTimeLimitPresets.map((preset) {
                                final (label, ms) = preset;
                                final selected = limitMs == ms;
                                return ActionChip(
                                  label: Text(label),
                                  backgroundColor:
                                      selected ? const Color(0xFFFF8906) : const Color(0xFF0F0E17),
                                  labelStyle: TextStyle(
                                    color: selected ? const Color(0xFF0F0E17) : Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  side: BorderSide(
                                    color: selected
                                        ? const Color(0xFFFF8906)
                                        : const Color(0xFFA7A9BE).withValues(alpha: 0.3),
                                  ),
                                  onPressed: () => setState(() => limitMs = ms),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Use 1m or 5m to test the "time is up" alert quickly.',
                              style: TextStyle(color: Color(0xFFA7A9BE), fontSize: 11, fontStyle: FontStyle.italic),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Child gets locked when the countdown reaches zero.',
                              style: TextStyle(color: Color(0xFFA7A9BE), fontSize: 12),
                            ),
                            if (limitMs > 0) ...[
                              const SizedBox(height: 12),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Lock device when timer ends',
                                  style: TextStyle(color: Colors.white, fontSize: 14),
                                ),
                                subtitle: const Text(
                                  'Blocks other apps and shows a lock screen on the child\'s phone',
                                  style: TextStyle(color: Color(0xFFA7A9BE), fontSize: 11),
                                ),
                                value: lockDeviceOnLimit,
                                activeThumbColor: const Color(0xFFFF8906),
                                onChanged: (v) => setState(() => lockDeviceOnLimit = v),
                              ),
                            ],
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
