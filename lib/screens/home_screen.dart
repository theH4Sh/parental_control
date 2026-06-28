import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:usage_stats/usage_stats.dart';

import '../api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/websocket_service.dart';
import '../services/control_service.dart';
import '../utils/time_format.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _AppUsage {
  final String packageName;
  final String displayName;
  final Uint8List? iconBytes;
  final int totalMs;

  _AppUsage({
    required this.packageName,
    required this.displayName,
    this.iconBytes,
    required this.totalMs,
  });
}

class _HomeScreenState extends State<HomeScreen> {
  List<_AppUsage> usages = [];
  bool hasPermission = false;
  bool isLoading = true;
  Timer? _pollTimer;
  static const MethodChannel _channel = MethodChannel(
    'com.example.parental_control_app/usage',
  );

  String? deviceId;
  String syncStatus = 'idle'; // 'idle', 'syncing', 'synced', 'error'
  DateTime? lastSynced;
  String? _timeUpDialogShownDate;

  @override
  void initState() {
    super.initState();
    initPermissionsAndStart();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WebSocketService.instance.disconnect();
    super.dispose();
  }

  Future<void> initBackend() async {
    try {
      final id = await ApiService.instance.init();
      debugPrint("🔑 Backend device ID: $id");
      setState(() {
        deviceId = id;
      });
    } catch (e) {
      debugPrint('Failed to initialize backend: $e');
      setState(() {
        syncStatus = 'error';
      });
    }
  }

  Future<void> initPermissionsAndStart() async {
    await initBackend();
    await NotificationService.instance.requestPermission();
    ChildSettingsService.instance.initWebSocketListener();
    ChildSettingsService.instance.onSettingsChanged = () {
      if (mounted) setState(() {});
    };
    await ChildSettingsService.instance.loadSettings();
    WebSocketService.instance.connect();

    if (!Platform.isAndroid) {
      setState(() {
        isLoading = false;
      });
      return;
    }
    await checkPermission();
    if (hasPermission) {
      await loadUsageStats();
    } else {
      setState(() {
        isLoading = false;
      });
    }
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (hasPermission) await loadUsageStats();
    });
  }

  Future<void> checkPermission() async {
    try {
      final bool granted = await _channel.invokeMethod('hasUsageAccess');
      setState(() {
        hasPermission = granted;
      });
    } on PlatformException {
      setState(() {
        hasPermission = false;
      });
    }
  }

  Future<void> openUsageAccessSettings() async {
    try {
      await _channel.invokeMethod('openUsageAccessSettings');
      await Future.delayed(const Duration(seconds: 1));
      await checkPermission();
      if (hasPermission) {
        setState(() {
          isLoading = true;
        });
        await loadUsageStats();
      }
    } on PlatformException {
      // ignore
    }
  }

  Future<void> loadUsageStats() async {
    if (!Platform.isAndroid) return;
    try {
      final List<UsageInfo> data = await UsageStats.queryUsageStats(
        DateTime.now().subtract(const Duration(days: 1)),
        DateTime.now(),
      );

      final totals = <String, int>{};
      for (final u in data) {
        final packageName = u.packageName ?? 'unknown';
        final int totalTime = int.tryParse(u.totalTimeInForeground ?? '0') ?? 0;
        totals[packageName] = (totals[packageName] ?? 0) + totalTime;
      }

      // Filter out zero usages
      final activeTotals = Map<String, int>.fromEntries(
        totals.entries.where((entry) => entry.value > 0),
      );

      final packageNames = activeTotals.keys.toList();
      if (packageNames.isEmpty) {
        setState(() {
          usages = [];
          isLoading = false;
        });
        await ChildSettingsService.instance.checkTimeLimit(0);
        _maybeShowTimeUpDialog(0);
        return;
      }

      final List<dynamic> details = await _channel.invokeMethod(
        'getAppDetails',
        packageNames,
      );
      final detailMap = <String, Map<String, Object?>>{};
      for (final item in details.cast<Map<dynamic, dynamic>>()) {
        final packageName = item['packageName'] as String;
        detailMap[packageName] = {
          'appName': item['appName'] as String?,
          'icon': item['icon'] as Uint8List?,
        };
      }

      final usageItems = activeTotals.entries.map((entry) {
        final detail = detailMap[entry.key];
        return _AppUsage(
          packageName: entry.key,
          displayName: detail?['appName'] as String? ?? entry.key,
          iconBytes: detail?['icon'] as Uint8List?,
          totalMs: entry.value,
        );
      }).toList()..sort((a, b) => b.totalMs.compareTo(a.totalMs));

      final totalMs = usageItems.fold<int>(0, (sum, u) => sum + u.totalMs);
      await ChildSettingsService.instance.checkTimeLimit(totalMs);
      _maybeShowTimeUpDialog(totalMs);
      setState(() {
        usages = usageItems;
        isLoading = false;
      });
      if (deviceId != null && usageItems.isNotEmpty) {
        syncToBackend();
      }
    } catch (e, stack) {
      debugPrint('Error loading usage stats: $e\n$stack');
      setState(() {
        usages = [];
        isLoading = false;
      });
    }
  }

  void _maybeShowTimeUpDialog(int totalMs) {
    final settings = ChildSettingsService.instance;
    if (!settings.isOverLimit(totalMs)) return;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (_timeUpDialogShownDate == today) return;
    _timeUpDialogShownDate = today;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1F29),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.timer_off_rounded, color: Color(0xFFE53170), size: 28),
              SizedBox(width: 12),
              Text('Time\'s Up!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'You\'ve reached your daily screen time limit set by your parent. '
            'Please take a break and put your device away.',
            style: TextStyle(color: Color(0xFFA7A9BE), height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8906),
                foregroundColor: const Color(0xFF0F0E17),
              ),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    });
  }

  Future<void> syncToBackend() async {
    if (deviceId == null) return;
    setState(() {
      syncStatus = 'syncing';
    });
    try {
      final data = usages
          .map(
            (u) => {
              'packageName': u.packageName,
              'displayName': u.displayName,
              'totalMs': u.totalMs,
            },
          )
          .toList();

      await ApiService.instance.syncUsageStats(
        deviceId: deviceId!,
        usageData: data,
      );

      setState(() {
        syncStatus = 'synced';
        lastSynced = DateTime.now();
      });
    } catch (e) {
      debugPrint('Failed to sync to backend: $e');
      setState(() {
        syncStatus = 'error';
      });
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1F29),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFE74C3C), size: 24),
            SizedBox(width: 12),
            Text('Logout',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Color(0xFFA7A9BE), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFFA7A9BE))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Logout',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      WebSocketService.instance.disconnect();
      await AuthService.instance.logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = usages.fold<int>(0, (sum, item) => sum + item.totalMs);
    final totalApps = usages.length;
    final topApp = usages.isNotEmpty ? usages.first.displayName : 'None';
    final maxMs = usages.isNotEmpty ? usages.first.totalMs : 1;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'App Usage Tracker',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
            if (AuthService.instance.username != null)
              Text(
                '${AuthService.instance.role == 'parent' ? '👨‍👩‍👧' : '👦'} ${AuthService.instance.username}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFA7A9BE),
                ),
              ),
          ],
        ),
        actions: [
          if (hasPermission)
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFFFF8906)),
              onPressed: () {
                setState(() {
                  isLoading = true;
                });
                loadUsageStats();
              },
            ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFA7A9BE)),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: !hasPermission
            ? _buildPermissionDeniedView()
            : isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8906)),
                ),
              )
            : usages.isEmpty
            ? Column(
                children: [
                  if (ChildSettingsService.instance.hasTimeLimit)
                    _buildTimeLimitCard(0),
                  Expanded(child: _buildEmptyView()),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (ChildSettingsService.instance.isOverLimit(totalMs))
                    _buildTimeUpBanner(),
                  _buildDashboardHeader(totalMs, totalApps, topApp),
                  if (ChildSettingsService.instance.hasTimeLimit)
                    _buildTimeLimitCard(totalMs),
                  _buildSyncStatusCard(),
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    child: Text(
                      'App Usage Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: usages.length,
                      itemBuilder: (context, index) {
                        final app = usages[index];
                        final percent = app.totalMs / maxMs;
                        return _buildAppUsageCard(app, percent);
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1F29),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFF8906).withValues(alpha: 0.2),
                  width: 3,
                ),
              ),
              child: const Icon(
                Icons.security_outlined,
                size: 80,
                color: Color(0xFFFF8906),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Usage Access Required',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'To track app screen time and parental control statistics, this app needs special Usage Access permission.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFFA7A9BE),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: openUsageAccessSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8906),
                foregroundColor: const Color(0xFF0F0E17),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Grant Permission',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 80,
              color: const Color(0xFFFF8906).withValues(alpha: 0.4),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Activity Recorded',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No application usage has been recorded in the last 24 hours.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Color(0xFFA7A9BE)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeUpBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE53170).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE53170).withValues(alpha: 0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.timer_off_rounded, color: Color(0xFFE53170), size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Time\'s Up!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Daily screen time limit reached. Please take a break.',
                  style: TextStyle(color: Color(0xFFA7A9BE), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeLimitCard(int totalMs) {
    final settings = ChildSettingsService.instance;
    final progress = settings.limitProgress(totalMs);
    final remaining = settings.remainingMs(totalMs);
    final overLimit = settings.isOverLimit(totalMs);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: overLimit
              ? const Color(0xFFE53170).withValues(alpha: 0.5)
              : const Color(0xFFFF8906).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DAILY LIMIT',
                style: TextStyle(
                  color: Color(0xFFFF8906),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                overLimit
                    ? 'Limit reached'
                    : '${formatDurationMs(remaining)} left',
                style: TextStyle(
                  color: overLimit ? const Color(0xFFE53170) : const Color(0xFFA7A9BE),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFF0F0E17),
              valueColor: AlwaysStoppedAnimation<Color>(
                overLimit ? const Color(0xFFE53170) : const Color(0xFFFF8906),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${formatDurationMs(totalMs)} used of ${formatDurationMs(settings.dailyTimeLimitMs)}',
            style: const TextStyle(color: Color(0xFFA7A9BE), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader(int totalMs, int totalApps, String topApp) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E2F3E), Color(0xFF1E1F29)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TODAY\'S SUMMARY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF8906),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatMs(totalMs),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Text(
                    'Total Screen Time',
                    style: TextStyle(fontSize: 14, color: Color(0xFFA7A9BE)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8906).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.query_stats,
                  color: Color(0xFFFF8906),
                  size: 32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSubStat('Apps Used', totalApps.toString(), Icons.apps),
              _buildSubStat('Most Active', topApp, Icons.star_border_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubStat(String label, String value, IconData icon) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFE53170)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFA7A9BE),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppUsageCard(_AppUsage app, double percent) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0E17),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: app.iconBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            app.iconBytes!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.contain,
                          ),
                        )
                      : Center(
                          child: Text(
                            app.displayName.isNotEmpty
                                ? app.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Color(0xFFFF8906),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        app.packageName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFA7A9BE),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatMs(app.totalMs),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF8906),
                      ),
                    ),
                    Text(
                      '${(percent * 100).toInt()}% of max',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFA7A9BE),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(height: 8, color: const Color(0xFF0F0E17)),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: 8,
                    width: MediaQuery.of(context).size.width * 0.7 * percent,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFE53170), Color(0xFFFF8906)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusCard() {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    final isSyncing = syncStatus == 'syncing';

    switch (syncStatus) {
      case 'syncing':
        statusColor = const Color(0xFFFF8906);
        statusText = 'Syncing statistics...';
        statusIcon = Icons.sync;
        break;
      case 'synced':
        statusColor = const Color(0xFF2ECC71); // elegant green
        statusText = 'Synced with Cloud';
        statusIcon = Icons.cloud_done_outlined;
        break;
      case 'error':
        statusColor = const Color(0xFFE74C3C); // red
        statusText = 'Sync failed';
        statusIcon = Icons.cloud_off_outlined;
        break;
      case 'idle':
      default:
        statusColor = const Color(0xFFA7A9BE);
        statusText = 'Ready to sync';
        statusIcon = Icons.cloud_queue_outlined;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            isSyncing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF8906),
                      ),
                    ),
                  )
                : Icon(statusIcon, color: statusColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (lastSynced != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Last sync: ${_formatLastSynced(lastSynced!)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFA7A9BE),
                      ),
                    ),
                  ],
                  if (deviceId != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Device ID: ',
                          style: TextStyle(
                            fontSize: 10,
                            color: const Color(
                              0xFFA7A9BE,
                            ).withValues(alpha: 0.7),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            deviceId!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: Color(0xFFFF8906),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: deviceId!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Device ID copied to clipboard!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Icon(
                            Icons.copy,
                            size: 12,
                            color: Color(0xFFFF8906),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (syncStatus != 'syncing' && deviceId != null)
              IconButton(
                icon: const Icon(Icons.cloud_sync, color: Color(0xFFFF8906)),
                onPressed: () {
                  syncToBackend();
                },
                tooltip: 'Sync now',
              ),
          ],
        ),
      ),
    );
  }

  String _formatLastSynced(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inHours}h ago';
    }
  }
}

String _formatMs(int ms) {
  final duration = Duration(milliseconds: ms);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
  if (minutes > 0) return '${minutes}m ${seconds}s';
  return '${seconds}s';
}
