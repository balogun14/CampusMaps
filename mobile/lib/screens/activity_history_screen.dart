import 'package:flutter/material.dart';
import '../models/recorded_activity.dart';
import '../services/recording_service.dart';
import '../theme.dart';

class ActivityHistoryScreen extends StatefulWidget {
  final RecordingService recordingService;
  const ActivityHistoryScreen({super.key, required this.recordingService});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  List<RecordedActivity> _activities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final acts = await widget.recordingService.getHistory();
    if (mounted) setState(() { _activities = acts; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity History'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.coral))
          : _activities.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.coral,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _activities.length,
                    itemBuilder: (context, i) => _activityCard(_activities[i]),
                  ),
                ),
    );
  }

  Widget _emptyState() {
    return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.coralLight, AppTheme.sunny],
                  ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.directions_walk, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text('No activities yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Go for a walk and record it!',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _activityCard(RecordedActivity a) {
    final typeIcon = switch (a.type) {
      ActivityType.walk => Icons.directions_walk,
      ActivityType.run => Icons.directions_run,
      ActivityType.hike => Icons.terrain,
    };

    final color = switch (a.type) {
      ActivityType.walk => AppTheme.teal,
      ActivityType.run => AppTheme.coral,
      ActivityType.hike => AppTheme.purple,
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showActivityDetail(a),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withAlpha(180)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _statLabel(a.formattedDistance, color),
                        const SizedBox(width: 12),
                        _statLabel(a.formattedDuration, color),
                        const SizedBox(width: 12),
                        _statLabel(a.formattedPace, color),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${a.date.day}/${a.date.month}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${a.points.length} pts',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade300),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statLabel(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  void _showActivityDetail(RecordedActivity activity) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44, height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(activity.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('${activity.date.day}/${activity.date.month}/${activity.date.year}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 16),
            Row(
              children: [
                _detailCard(Icons.timer_outlined, activity.formattedDuration, 'Duration', AppTheme.teal),
                const SizedBox(width: 12),
                _detailCard(Icons.straighten, activity.formattedDistance, 'Distance', AppTheme.coral),
                const SizedBox(width: 12),
                _detailCard(Icons.speed, activity.formattedPace, 'Pace', AppTheme.purple),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                label: const Text('Delete Activity', style: TextStyle(color: Colors.redAccent)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  widget.recordingService.storage.deleteActivity(activity.id);
                  Navigator.pop(ctx);
                  _load();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailCard(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
            Text(label,
                style: TextStyle(fontSize: 11, color: color.withAlpha(150))),
          ],
        ),
      ),
    );
  }
}
