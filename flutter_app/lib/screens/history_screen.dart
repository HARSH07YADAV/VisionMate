import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/history_service.dart';

/// History screen (Feature 20)
/// Shows detection history for caregiver review
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryEntry> _entries = [];
  Map<String, int> _classCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = context.read<HistoryService>();
    
    final entries = await history.getRecentHistory(limit: 100);
    final counts = await history.getClassCounts(days: 7);
    
    setState(() {
      _entries = entries;
      _classCounts = counts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detection History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _confirmClear,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No detection history yet',
                style: TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Start detecting objects and they will be logged here.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Summary section
        _buildSummary(),
        const Divider(),
        // Entries list
        Expanded(
          child: ListView.builder(
            itemCount: _entries.length,
            itemBuilder: (context, index) => _buildEntry(_entries[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final topClasses = _classCounts.entries.take(5).toList();
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Last 7 Days Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: topClasses.map((e) => Chip(
              label: Text('${e.key}: ${e.value}'),
              backgroundColor: _getClassColor(e.key),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEntry(HistoryEntry entry) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _getClassColor(entry.className),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            entry.className[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: Text(
        entry.className,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '${_formatTime(entry.timestamp)} • ${_formatDistance(entry.distanceMeters)}',
      ),
      trailing: Text(
        '${(entry.confidence * 100).toInt()}%',
        style: TextStyle(color: Colors.grey.shade400),
      ),
    );
  }

  Color _getClassColor(String className) {
    final colors = [
      Colors.blue, Colors.red, Colors.green, Colors.orange,
      Colors.purple, Colors.teal, Colors.pink, Colors.indigo,
    ];
    return colors[className.hashCode % colors.length];
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatDistance(double? distance) {
    if (distance == null || distance < 0) return 'Unknown distance';
    if (distance < 1) return '${(distance * 100).toInt()}cm';
    return '${distance.toStringAsFixed(1)}m';
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to delete all detection history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<HistoryService>().clearAllHistory();
              Navigator.pop(context);
              await _loadHistory();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
