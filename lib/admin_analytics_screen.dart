import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_widgets.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> submissions;

  const AdminAnalyticsScreen({
    super.key,
    required this.submissions,
  });

  Map<String, int> _countBy(List<Map<String, dynamic>> items, String key) {
    final map = <String, int>{};
    for (final item in items) {
      final value = (item[key] ?? 'Unknown').toString();
      map[value] = (map[value] ?? 0) + 1;
    }
    return map;
  }

  DateTime _dueDate(Map<String, dynamic> item) {
    final dueAt = DateTime.tryParse(item['due_at']?.toString() ?? '');
    if (dueAt != null) return dueAt.toLocal();
    final createdAt = DateTime.tryParse(item['created_at']?.toString() ?? '');
    return (createdAt ?? DateTime.now()).toLocal().add(const Duration(days: 3));
  }

  Future<void> _copySummary(BuildContext context) async {
    final total = submissions.length;
    final pending = submissions.where((s) => s['status'] == 'pending').length;
    final inProgress =
        submissions.where((s) => s['status'] == 'in_progress').length;
    final solved = submissions.where((s) => s['status'] == 'solved').length;
    final unsatisfied =
        submissions.where((s) => s['satisfaction'] == 'not_satisfied').length;
    final overdue = submissions.where((s) {
      final status = s['status']?.toString() ?? 'pending';
      return status != 'solved' && DateTime.now().isAfter(_dueDate(s));
    }).length;

    final summary = '''
VoiceBox Analytics Summary
Total submissions: $total
Pending: $pending
In progress: $inProgress
Solved: $solved
Unsatisfied: $unsatisfied
Overdue: $overdue
''';

    await Clipboard.setData(ClipboardData(text: summary.trim()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Summary copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = submissions.length;
    final pending = submissions.where((s) => s['status'] == 'pending').length;
    final inProgress =
        submissions.where((s) => s['status'] == 'in_progress').length;
    final solved = submissions.where((s) => s['status'] == 'solved').length;
    final unsatisfied =
        submissions.where((s) => s['satisfaction'] == 'not_satisfied').length;
    final reopened =
        submissions.where((s) => s['reopen_requested'] == true).length;
    final overdue = submissions.where((s) {
      final status = s['status']?.toString() ?? 'pending';
      return status != 'solved' && DateTime.now().isAfter(_dueDate(s));
    }).length;

    final categories = _countBy(submissions, 'category');
    final types = _countBy(submissions, 'submission_type');
    final priorities = _countBy(
      submissions.map((e) {
        final copy = Map<String, dynamic>.from(e);
        copy['priority'] = (copy['priority'] ?? 'medium').toString();
        return copy;
      }).toList(),
      'priority',
    );

    double ratio(int count) => total == 0 ? 0 : count / total;

    List<Widget> metricBars(Map<String, int> map) {
      final entries = map.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return entries
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: AppMetricBar(
                label: e.key,
                count: e.value,
                fraction: ratio(e.value),
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          )
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            onPressed: () => _copySummary(context),
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: 'Copy summary',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          AppGradientPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard insights',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use these numbers to spot delays, frequent categories, and dissatisfaction trends.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 150,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                AppStatCard(
                  title: 'Total',
                  value: '$total',
                  icon: Icons.inbox_rounded,
                  color: Colors.deepPurple,
                ),
                const SizedBox(width: 12),
                AppStatCard(
                  title: 'Solved',
                  value: '$solved',
                  icon: Icons.task_alt_rounded,
                  color: Colors.green,
                ),
                const SizedBox(width: 12),
                AppStatCard(
                  title: 'Overdue',
                  value: '$overdue',
                  icon: Icons.timer_off_outlined,
                  color: Colors.red,
                ),
                const SizedBox(width: 12),
                AppStatCard(
                  title: 'Reopen',
                  value: '$reopened',
                  icon: Icons.replay_circle_filled_outlined,
                  color: Colors.orange,
                ),
                const SizedBox(width: 12),
                AppStatCard(
                  title: 'Unsatisfied',
                  value: '$unsatisfied',
                  icon: Icons.sentiment_dissatisfied_rounded,
                  color: Colors.pink,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionTitle(
                  title: 'Status split',
                  subtitle: 'How work is distributed right now.',
                  icon: Icons.pie_chart_outline_rounded,
                ),
                const SizedBox(height: 18),
                AppMetricBar(
                  label: 'Pending',
                  count: pending,
                  fraction: ratio(pending),
                  color: Colors.red,
                ),
                const SizedBox(height: 14),
                AppMetricBar(
                  label: 'In progress',
                  count: inProgress,
                  fraction: ratio(inProgress),
                  color: Colors.orange,
                ),
                const SizedBox(height: 14),
                AppMetricBar(
                  label: 'Solved',
                  count: solved,
                  fraction: ratio(solved),
                  color: Colors.green,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionTitle(
                  title: 'Category breakdown',
                  subtitle: 'Which areas create the most submissions.',
                  icon: Icons.folder_outlined,
                ),
                const SizedBox(height: 18),
                if (categories.isEmpty)
                  const Text('No data available')
                else
                  ...metricBars(categories),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionTitle(
                  title: 'Submission types',
                  subtitle: 'Complaint vs suggestion vs feedback.',
                  icon: Icons.category_outlined,
                ),
                const SizedBox(height: 18),
                if (types.isEmpty) const Text('No data available') else ...metricBars(types),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionTitle(
                  title: 'Priority mix',
                  subtitle: 'Helps you see how urgent the queue looks.',
                  icon: Icons.flag_outlined,
                ),
                const SizedBox(height: 18),
                if (priorities.isEmpty)
                  const Text('No data available')
                else
                  ...metricBars(priorities),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
