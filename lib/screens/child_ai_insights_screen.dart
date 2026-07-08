import 'package:flutter/material.dart';
import '../api_service.dart';

class ChildAiInsightsScreen extends StatefulWidget {
  final String childId;
  final String childName;

  const ChildAiInsightsScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<ChildAiInsightsScreen> createState() => _ChildAiInsightsScreenState();
}

class _ChildAiInsightsScreenState extends State<ChildAiInsightsScreen> {
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? insights;
  Map<String, dynamic>? activityContext;
  String? generatedAt;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await ApiService.instance.getChildAiInsights(widget.childId);
      if (!mounted) return;
      setState(() {
        insights = data['insights'] as Map<String, dynamic>?;
        activityContext = data['context'] as Map<String, dynamic>?;
        generatedAt = data['generatedAt'] as String?;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        title: Text('AI Insights — ${widget.childName}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFF8906)),
            onPressed: isLoading ? null : _loadInsights,
            tooltip: 'Refresh insights',
          ),
        ],
      ),
      body: isLoading
          ? _buildLoading()
          : errorMessage != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadInsights,
                  color: const Color(0xFFFF8906),
                  backgroundColor: const Color(0xFF1E1F29),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      if (insights != null) ...[
                        _buildSummaryCard(),
                        const SizedBox(height: 16),
                        _buildAssessmentChip(),
                        const SizedBox(height: 16),
                        _buildListSection(
                          title: 'Highlights',
                          icon: Icons.check_circle_outline,
                          color: const Color(0xFF2ECC71),
                          items: _stringList(insights!['highlights']),
                        ),
                        if (_stringList(insights!['concerns']).isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildListSection(
                            title: 'Worth a look',
                            icon: Icons.info_outline,
                            color: const Color(0xFFFF8906),
                            items: _stringList(insights!['concerns']),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildActionsSection(),
                        const SizedBox(height: 16),
                        _buildContextSnapshot(),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFFF8906)),
          const SizedBox(height: 20),
          Text(
            'Analyzing ${widget.childName}\'s activity…',
            style: const TextStyle(color: Color(0xFFA7A9BE), fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            'This may take a few seconds',
            style: TextStyle(color: Color(0xFF6B6D7B), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.psychology_outlined, color: Color(0xFFE53170), size: 48),
            const SizedBox(height: 16),
            Text(
              errorMessage ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFA7A9BE)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadInsights,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8906),
                foregroundColor: const Color(0xFF0F0E17),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF8906).withValues(alpha: 0.2),
            const Color(0xFF6246EA).withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF8906).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8906).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome, color: Color(0xFFFF8906), size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Parent AI Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  generatedAt != null
                      ? 'Updated ${_formatGeneratedAt(generatedAt!)}'
                      : 'Personalized for today',
                  style: const TextStyle(color: Color(0xFFA7A9BE), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final summary = insights?['summary'] as String? ?? '';
    return _sectionCard(
      child: Text(
        summary,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildAssessmentChip() {
    final assessment = insights?['screenTimeAssessment'] as String? ?? 'unknown';
    final (label, color) = switch (assessment) {
      'healthy' => ('Screen time looks balanced', const Color(0xFF2ECC71)),
      'moderate' => ('Moderate screen time today', const Color(0xFFFF8906)),
      'high' => ('Higher screen time than usual', const Color(0xFFE53170)),
      _ => ('Not enough data to assess screen time', const Color(0xFFA7A9BE)),
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(color: Color(0xFFD0D1DB), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    final actions = (insights?['suggestedActions'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    if (actions.isEmpty) return const SizedBox.shrink();

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Color(0xFFFF8906), size: 20),
              SizedBox(width: 8),
              Text(
                'Suggested next steps',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...actions.map(_buildActionTile),
        ],
      ),
    );
  }

  Widget _buildActionTile(Map<String, dynamic> action) {
    final priority = action['priority'] as String? ?? 'medium';
    final (priorityLabel, priorityColor) = switch (priority) {
      'high' => ('High', const Color(0xFFE53170)),
      'low' => ('Low', const Color(0xFF2ECC71)),
      _ => ('Medium', const Color(0xFFFF8906)),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0E17),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2B38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  action['title'] as String? ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  priorityLabel,
                  style: TextStyle(color: priorityColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            action['description'] as String? ?? '',
            style: const TextStyle(color: Color(0xFFA7A9BE), fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildContextSnapshot() {
    final screenTime = activityContext?['screenTime'] as Map<String, dynamic>?;
    final controls = activityContext?['parentalControls'] as Map<String, dynamic>?;
    final web = activityContext?['webActivity'] as Map<String, dynamic>?;
    final availability = activityContext?['dataAvailability'] as Map<String, dynamic>?;

    if (availability?['isSparse'] == true) {
      return _sectionCard(
        child: const Text(
          'Limited data today — link your child\'s device and ensure usage & browsing tracking are enabled for richer insights.',
          style: TextStyle(color: Color(0xFFA7A9BE), height: 1.4),
        ),
      );
    }

    final topApps = (screenTime?['topApps'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .take(3)
        .map((app) => '${app['name']} (${app['time']})')
        .join(', ');

    final topDomains = (web?['topDomains'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .take(3)
        .map((d) => d['domain'] as String? ?? '')
        .where((d) => d.isNotEmpty)
        .join(', ');

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today at a glance',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 10),
          _snapshotRow('Screen time', screenTime?['total'] as String? ?? '—'),
          _snapshotRow('Daily limit', controls?['dailyLimit'] as String? ?? '—'),
          _snapshotRow('Bedtime', controls?['bedtime'] as String? ?? '—'),
          if (topApps.isNotEmpty) _snapshotRow('Top apps', topApps),
          if (topDomains.isNotEmpty) _snapshotRow('Top sites', topDomains),
        ],
      ),
    );
  }

  Widget _snapshotRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: Color(0xFF6B6D7B), fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Color(0xFFD0D1DB), fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2B38)),
      ),
      child: child,
    );
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return [];
    return value.whereType<String>().where((s) => s.trim().isNotEmpty).toList();
  }

  String _formatGeneratedAt(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '${dt.month}/${dt.day} at $hour:$minute $period';
    } catch (_) {
      return 'recently';
    }
  }
}
