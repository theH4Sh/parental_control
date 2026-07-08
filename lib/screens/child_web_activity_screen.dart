import 'package:flutter/material.dart';
import '../api_service.dart';

class ChildWebActivityScreen extends StatefulWidget {
  final String childId;
  final String childName;

  const ChildWebActivityScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<ChildWebActivityScreen> createState() => _ChildWebActivityScreenState();
}

class _ChildWebActivityScreenState extends State<ChildWebActivityScreen> {
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> domains = [];
  bool showDomains = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final data = await ApiService.instance.getChildBrowsingHistory(widget.childId);
      if (!mounted) return;
      setState(() {
        events = (data['events'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        domains = (data['domains'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
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
        title: Text('${widget.childName}\'s Web Activity'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFF8906)),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF8906)))
          : errorMessage != null
              ? _buildError()
              : events.isEmpty
                  ? _buildEmpty()
                  : Column(
                      children: [
                        _buildToggle(),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadHistory,
                            color: const Color(0xFFFF8906),
                            child: showDomains ? _buildDomainList() : _buildEventList(),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: ChoiceChip(
              label: Text('Top sites (${domains.length})'),
              selected: showDomains,
              onSelected: (v) => setState(() => showDomains = true),
              selectedColor: const Color(0xFFFF8906),
              labelStyle: TextStyle(
                color: showDomains ? const Color(0xFF0F0E17) : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ChoiceChip(
              label: Text('All visits (${events.length})'),
              selected: !showDomains,
              onSelected: (v) => setState(() => showDomains = false),
              selectedColor: const Color(0xFFFF8906),
              labelStyle: TextStyle(
                color: !showDomains ? const Color(0xFF0F0E17) : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDomainList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: domains.length,
      itemBuilder: (context, index) {
        final item = domains[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF0F0E17),
              child: Text(
                (item['domain'] as String? ?? '?')[0].toUpperCase(),
                style: const TextStyle(color: Color(0xFFFF8906), fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              item['domain'] as String? ?? 'Unknown',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${item['visitCount']} visits · ${item['uniqueUrls']} URLs',
              style: const TextStyle(color: Color(0xFFA7A9BE), fontSize: 12),
            ),
            trailing: Text(
              _formatTime(item['lastVisited']),
              style: const TextStyle(color: Color(0xFFA7A9BE), fontSize: 11),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final url = event['url'] as String? ?? '';
        final title = event['title'] as String? ?? event['domain'] as String? ?? url;
        final browser = event['browserName'] as String? ?? 'Browser';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.language_rounded, color: Color(0xFFFF8906), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  url,
                  style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _badge(browser, const Color(0xFFE53170)),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(event['visitedAt']),
                      style: const TextStyle(color: Color(0xFFA7A9BE), fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore_rounded, size: 64, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            const Text(
              'No web activity yet',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Browsing is tracked when the child uses Chrome or other browsers '
              'and the Accessibility service is enabled on their device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFA7A9BE), height: 1.4),
            ),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: _loadHistory, child: const Text('Refresh')),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(errorMessage!, style: const TextStyle(color: Color(0xFFE74C3C))),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadHistory, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  String _formatTime(dynamic value) {
    if (value == null) return '';
    try {
      final dt = value is String ? DateTime.parse(value).toLocal() : DateTime.fromMillisecondsSinceEpoch(value as int).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }
}
