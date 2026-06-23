import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../api_service.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  List<Map<String, dynamic>> children = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadChildren();
  }

  Future<void> loadChildren() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final list = await AuthService.instance.getChildren();
      setState(() {
        children = list;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
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
      await AuthService.instance.logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _openRegisterChildDialog() {
    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1F29),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8906).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_add_rounded, color: Color(0xFFFF8906)),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Register Child',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Create a secure account for your child. They can use these credentials to sign in on their tracking device.',
                        style: TextStyle(color: Color(0xFFA7A9BE), fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: usernameController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Child Username',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                          prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFFA7A9BE), size: 20),
                          filled: true,
                          fillColor: const Color(0xFF0F0E17),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Username is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Child Email',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                          prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFA7A9BE), size: 20),
                          filled: true,
                          fillColor: const Color(0xFF0F0E17),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email is required';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFA7A9BE), size: 20),
                          filled: true,
                          fillColor: const Color(0xFF0F0E17),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        validator: (v) => (v == null || v.length < 6) ? 'Password must be at least 6 characters' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFFA7A9BE))),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSaving = true);

                          try {
                            await AuthService.instance.registerChild(
                              usernameController.text.trim(),
                              emailController.text.trim(),
                              passwordController.text,
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Successfully registered ${usernameController.text}!'),
                                  backgroundColor: const Color(0xFF2ECC71),
                                ),
                              );
                              loadChildren();
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
                                  backgroundColor: const Color(0xFFE74C3C),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8906),
                    foregroundColor: const Color(0xFF0F0E17),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Color(0xFF0F0E17))),
                        )
                      : const Text('Register', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Parent Dashboard',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
            ),
            if (AuthService.instance.username != null)
              Text(
                '👨‍👩‍👧 Welcome back, ${AuthService.instance.username}',
                style: const TextStyle(fontSize: 12, color: Color(0xFFA7A9BE)),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFF8906)),
            onPressed: loadChildren,
            tooltip: 'Refresh child list',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFA7A9BE)),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadChildren,
          color: const Color(0xFFFF8906),
          backgroundColor: const Color(0xFF1E1F29),
          child: _buildBody(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openRegisterChildDialog,
        backgroundColor: const Color(0xFFFF8906),
        foregroundColor: const Color(0xFF0F0E17),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Register Child', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8906)),
        ),
      );
    }

    if (errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          const Icon(Icons.cloud_off_outlined, color: Color(0xFFE74C3C), size: 80),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Connection Error',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFA7A9BE), fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              onPressed: loadChildren,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8906),
                foregroundColor: const Color(0xFF0F0E17),
              ),
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    if (children.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          Icon(
            Icons.child_care_rounded,
            size: 100,
            color: const Color(0xFFFF8906).withValues(alpha: 0.2),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'No Children Registered',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Keep your kids safe online. Register a child account, sign them in on their device, and start monitoring their active screen time.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFA7A9BE), fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 32),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: children.length,
      itemBuilder: (context, index) {
        final child = children[index];
        final String childName = child['username'] ?? 'Unknown';
        final String childEmail = child['email'] ?? '';
        final String? childDeviceId = child['deviceId'];

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChildReportScreen(
                    childName: childName,
                    deviceId: childDeviceId,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0E17),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (childDeviceId != null ? const Color(0xFF2ECC71) : const Color(0xFFA7A9BE)).withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        childName.isNotEmpty ? childName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Color(0xFFFF8906),
                          fontSize: 24,
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
                          childName,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          childEmail,
                          style: const TextStyle(color: Color(0xFFA7A9BE), fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: childDeviceId != null ? const Color(0xFF2ECC71) : const Color(0xFFE53170),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              childDeviceId != null ? 'Linked Device Active' : 'No Device Linked',
                              style: TextStyle(
                                color: childDeviceId != null ? const Color(0xFF2ECC71) : const Color(0xFFE53170),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFFA7A9BE), size: 28),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ChildReportScreen extends StatefulWidget {
  final String childName;
  final String? deviceId;

  const ChildReportScreen({
    super.key,
    required this.childName,
    this.deviceId,
  });

  @override
  State<ChildReportScreen> createState() => _ChildReportScreenState();
}

class _ChildReportScreenState extends State<ChildReportScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> dailyReports = [];
  Map<String, dynamic>? selectedReport;

  @override
  void initState() {
    super.initState();
    fetchStats();
  }

  Future<void> fetchStats() async {
    if (widget.deviceId == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final list = await ApiService.instance.getUsageStats(widget.deviceId!);
      setState(() {
        dailyReports = list;
        if (list.isNotEmpty) {
          selectedReport = list.first; // Default to showing the latest day
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  String _formatMs(int ms) {
    final Duration duration = Duration(milliseconds: ms);
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      final int secs = duration.inSeconds.remainder(60);
      return '${secs}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        title: Text('${widget.childName}\'s Activity'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.deviceId != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFFFF8906)),
              onPressed: fetchStats,
            ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (widget.deviceId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.phonelink_setup_rounded,
                size: 80,
                color: const Color(0xFFFF8906).withValues(alpha: 0.3),
              ),
              const SizedBox(height: 24),
              const Text(
                'Waiting for Connection',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'To see usage statistics, log in as "${widget.childName}" on their device. The app will pair automatically and report usage.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFA7A9BE), fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8906)),
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFE74C3C), size: 64),
              const SizedBox(height: 16),
              const Text(
                'Failed to load report',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFA7A9BE), fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: fetchStats,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8906),
                  foregroundColor: const Color(0xFF0F0E17),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (dailyReports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.hourglass_empty_rounded,
                size: 80,
                color: const Color(0xFFFF8906).withValues(alpha: 0.3),
              ),
              const SizedBox(height: 24),
              const Text(
                'No Stats Reported Yet',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                '${widget.childName} has logged into their device but hasn\'t sent any screen time reports yet. Please wait, or click refresh above.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFA7A9BE), fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    final totalScreenTimeMs = selectedReport?['totalScreenTimeMs'] as int? ?? 0;
    final List<dynamic> apps = selectedReport?['apps'] ?? [];
    final String deviceInfo = selectedReport?['deviceInfo'] ?? 'Unknown Device';
    final maxMs = apps.isNotEmpty ? (apps.first['totalMs'] as int? ?? 1) : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Selector Row
        Container(
          height: 60,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: dailyReports.length,
            itemBuilder: (context, index) {
              final report = dailyReports[index];
              final date = report['date'] as String? ?? '';
              final isSelected = selectedReport == report;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ChoiceChip(
                  label: Text(
                    date,
                    style: TextStyle(
                      color: isSelected ? const Color(0xFF0F0E17) : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFFFF8906),
                  backgroundColor: const Color(0xFF1E1F29),
                  checkmarkColor: const Color(0xFF0F0E17),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        selectedReport = report;
                      });
                    }
                  },
                ),
              );
            },
          ),
        ),

        // Main Summary Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E2F3E), Color(0xFF1E1F29)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatMs(totalScreenTimeMs),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Total Screen Time Today',
                        style: TextStyle(fontSize: 14, color: Color(0xFFA7A9BE)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53170).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: Color(0xFFE53170),
                      size: 28,
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.devices_rounded, size: 16, color: Color(0xFFFF8906)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      deviceInfo,
                      style: const TextStyle(color: Color(0xFFA7A9BE), fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Monitored App Usage',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),

        // Apps List
        Expanded(
          child: apps.isEmpty
              ? const Center(
                  child: Text(
                    'No individual app activity recorded.',
                    style: TextStyle(color: Color(0xFFA7A9BE)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    final String displayName = app['displayName'] ?? '';
                    final String packageName = app['packageName'] ?? '';
                    final int totalMs = app['totalMs'] as int? ?? 0;
                    final double percent = maxMs > 0 ? (totalMs / maxMs) : 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F0E17),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        color: Color(0xFFFF8906),
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        packageName,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFFA7A9BE),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatMs(totalMs),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF8906),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Stack(
                                children: [
                                  Container(height: 6, color: const Color(0xFF0F0E17)),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 500),
                                    height: 6,
                                    width: MediaQuery.of(context).size.width * 0.75 * percent,
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
                  },
                ),
        ),
      ],
    );
  }
}
