import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_widgets.dart';
import 'notifications_screen.dart';
import 'user_submission_detail_screen.dart';

class MySubmissionsScreen extends StatefulWidget {
  const MySubmissionsScreen({super.key});

  @override
  State<MySubmissionsScreen> createState() => _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends State<MySubmissionsScreen> {
  List<Map<String, dynamic>> _submissions = [];
  bool _isLoading = true;
  String? _deviceToken;
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatusFilter = 'All';
  String _selectedSort = 'Newest';

  final statusFilters = ['All', 'Pending', 'In Progress', 'Solved'];
  final sortOptions = ['Newest', 'Oldest', 'Priority', 'Needs Attention'];

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSubmissions() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _deviceToken = prefs.getString('device_token') ?? '';
      final userId = Supabase.instance.client.auth.currentUser?.id;

      dynamic query = Supabase.instance.client.from('submissions').select();

      if (userId != null) {
        query = query.eq('user_id', userId);
      } else {
        query = query.eq('device_token', _deviceToken!);
      }

      final data = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _submissions = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading submissions: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _totalCount => _submissions.length;
  int get _solvedCount =>
      _submissions.where((s) => s['status'] == 'solved').length;
  int get _pendingCount =>
      _submissions.where((s) => s['status'] == 'pending').length;
  int get _inProgressCount =>
      _submissions.where((s) => s['status'] == 'in_progress').length;

  double get _solvedPercent =>
      _totalCount == 0 ? 0.0 : (_solvedCount / _totalCount) * 100;

  Color _statusColor(String? status) {
    switch (status) {
      case 'solved':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'solved':
        return 'Solved';
      case 'in_progress':
        return 'In Progress';
      default:
        return 'Pending';
    }
  }

  String _priorityLabel(String? priority) {
    switch ((priority ?? 'medium').toLowerCase()) {
      case 'high':
        return 'High Priority';
      case 'low':
        return 'Low Priority';
      default:
        return 'Medium Priority';
    }
  }

  Color _priorityColor(String? priority) {
    switch ((priority ?? 'medium').toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    final dt = DateTime.tryParse(createdAt)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  DateTime _dueDate(Map<String, dynamic> item) {
    final dueAt = DateTime.tryParse(item['due_at']?.toString() ?? '');
    if (dueAt != null) return dueAt.toLocal();
    final createdAt = DateTime.tryParse(item['created_at']?.toString() ?? '');
    return (createdAt ?? DateTime.now()).toLocal().add(const Duration(days: 3));
  }

  bool _matchesSearch(Map<String, dynamic> item) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;

    final text = [
      item['title'],
      item['description'],
      item['category'],
      item['submission_type'],
      item['priority'],
    ].join(' ').toLowerCase();

    return text.contains(query);
  }

  List<Map<String, dynamic>> get _filteredSubmissions {
    final items = _submissions.where((item) {
      final status = item['status']?.toString() ?? 'pending';
      final statusMatch =
          _selectedStatusFilter == 'All' ||
          status == _selectedStatusFilter.toLowerCase().replaceAll(' ', '_');
      return statusMatch && _matchesSearch(item);
    }).toList();

    items.sort((a, b) {
      switch (_selectedSort) {
        case 'Oldest':
          return DateTime.tryParse(
                a['created_at']?.toString() ?? '',
              )?.compareTo(
                DateTime.tryParse(b['created_at']?.toString() ?? '') ??
                    DateTime.now(),
              ) ??
              0;
        case 'Priority':
          int rank(String? p) {
            switch ((p ?? 'medium').toLowerCase()) {
              case 'high':
                return 0;
              case 'medium':
                return 1;
              default:
                return 2;
            }
          }

          return rank(
            a['priority']?.toString(),
          ).compareTo(rank(b['priority']?.toString()));
        case 'Needs Attention':
          int attention(Map<String, dynamic> item) {
            if (item['reopen_requested'] == true) return 0;
            if (item['satisfaction'] == 'not_satisfied') return 1;
            if (item['status'] == 'pending') return 2;
            if (item['status'] == 'in_progress') return 3;
            return 4;
          }

          return attention(a).compareTo(attention(b));
        default:
          return (DateTime.tryParse(b['created_at']?.toString() ?? '') ??
                  DateTime.now())
              .compareTo(
                DateTime.tryParse(a['created_at']?.toString() ?? '') ??
                    DateTime.now(),
              );
      }
    });

    return items;
  }

  Future<void> _copyCsv() async {
    final buffer = StringBuffer();
    buffer.writeln(
      'title,status,category,type,priority,created_at,reopen_requested',
    );
    for (final item in _filteredSubmissions) {
      String cell(dynamic value) =>
          '"${(value ?? '').toString().replaceAll('"', '""')}"';
      buffer.writeln(
        [
          cell(item['title']),
          cell(item['status']),
          cell(item['category']),
          cell(item['submission_type']),
          cell(item['priority']),
          cell(item['created_at']),
          cell(item['reopen_requested']),
        ].join(','),
      );
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('CSV copied to clipboard')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Submissions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: 'Copy CSV',
            onPressed: _copyCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadSubmissions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSubmissions,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  AppGradientPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Track your submissions',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Search, sort, check due dates, see priority, and request reopen if a solved issue still needs work.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildSummaryCard(theme),
                  const SizedBox(height: 18),
                  AppSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionTitle(
                          title: 'Search and filter',
                          subtitle:
                              'Find submissions faster by keyword, status, and sort order.',
                          icon: Icons.tune_rounded,
                        ),
                        const SizedBox(height: 16),
                        AppSearchField(
                          controller: _searchController,
                          hintText:
                              'Search by title, category, type, or priority',
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: statusFilters.map((filter) {
                            return ChoiceChip(
                              label: Text(filter),
                              selected: _selectedStatusFilter == filter,
                              onSelected: (_) => setState(
                                () => _selectedStatusFilter = filter,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedSort,
                          decoration: const InputDecoration(
                            labelText: 'Sort by',
                            prefixIcon: Icon(Icons.sort_rounded),
                          ),
                          items: sortOptions
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedSort = value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_submissions.isEmpty)
                    const SizedBox(
                      height: 320,
                      child: AppEmptyState(
                        title: 'No submissions yet',
                        subtitle:
                            'Your submitted issues and suggestions will appear here.',
                        icon: Icons.inbox_outlined,
                      ),
                    )
                  else if (_filteredSubmissions.isEmpty)
                    const SizedBox(
                      height: 320,
                      child: AppEmptyState(
                        title: 'Nothing matches your filters',
                        subtitle:
                            'Try clearing the search or changing the status filter.',
                        icon: Icons.search_off_rounded,
                      ),
                    )
                  else
                    ..._filteredSubmissions.map((item) {
                      final status = item['status'] ?? 'pending';
                      final statusColor = _statusColor(status);
                      final satisfaction = item['satisfaction'];
                      final isSolved = status == 'solved';
                      final needsFeedback = isSolved && satisfaction == null;
                      final dueDate = _dueDate(item);
                      final isOverdue =
                          status != 'solved' && DateTime.now().isAfter(dueDate);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppSurface(
                          padding: const EdgeInsets.all(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserSubmissionDetailScreen(
                                    submission: item,
                                  ),
                                ),
                              );
                              _loadSubmissions();
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['title'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    AppStatusChip(
                                      label: _statusLabel(status),
                                      color: statusColor,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  item['description'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    AppTagChip(label: item['category'] ?? ''),
                                    AppTagChip(
                                      label: item['submission_type'] ?? '',
                                    ),
                                    AppTagChip(
                                      label: _priorityLabel(
                                        item['priority']?.toString(),
                                      ),
                                      color: _priorityColor(
                                        item['priority']?.toString(),
                                      ),
                                      foregroundColor: _priorityColor(
                                        item['priority']?.toString(),
                                      ),
                                      outlined: true,
                                      icon: Icons.flag_outlined,
                                    ),
                                    AppTagChip(
                                      label:
                                          'Submitted ${_timeAgo(item['created_at'])}',
                                      icon: Icons.schedule_outlined,
                                    ),
                                    AppTagChip(
                                      label: isOverdue
                                          ? 'Overdue'
                                          : 'Due ${dueDate.day}/${dueDate.month}',
                                      color: isOverdue
                                          ? Colors.red
                                          : Colors.blue,
                                      foregroundColor: isOverdue
                                          ? Colors.red
                                          : Colors.blue,
                                      outlined: true,
                                      icon: isOverdue
                                          ? Icons.timer_off_outlined
                                          : Icons.event_available_outlined,
                                    ),
                                    if (item['reopen_requested'] == true)
                                      const AppTagChip(
                                        label: 'Reopen requested',
                                        color: Colors.orange,
                                        foregroundColor: Colors.orange,
                                        outlined: true,
                                        icon:
                                            Icons.replay_circle_filled_outlined,
                                      ),
                                  ],
                                ),
                                if (needsFeedback) ...[
                                  const SizedBox(height: 12),
                                  const AppInfoBanner(
                                    message:
                                        'This issue was marked as solved. Tap to give feedback or request a reopen.',
                                    icon: Icons.feedback_outlined,
                                    color: Colors.blue,
                                  ),
                                ],
                                if (satisfaction != null) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(
                                        satisfaction == 'satisfied'
                                            ? Icons.sentiment_satisfied_alt
                                            : Icons.sentiment_dissatisfied,
                                        size: 16,
                                        color: satisfaction == 'satisfied'
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        satisfaction == 'satisfied'
                                            ? 'You marked this as satisfied'
                                            : 'You marked this as not satisfied',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: satisfaction == 'satisfied'
                                              ? Colors.green[700]
                                              : Colors.orange[800],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionTitle(
            title: 'Submission summary',
            subtitle: 'A quick overview of your current submission pipeline.',
            icon: Icons.dashboard_outlined,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              AppTagChip(
                label: '$_totalCount total',
                icon: Icons.inbox_outlined,
              ),
              AppTagChip(
                label: '$_pendingCount pending',
                color: Colors.red,
                foregroundColor: Colors.red,
                outlined: true,
                icon: Icons.pending_actions_rounded,
              ),
              AppTagChip(
                label: '$_inProgressCount in progress',
                color: Colors.orange,
                foregroundColor: Colors.orange,
                outlined: true,
                icon: Icons.timelapse_rounded,
              ),
              AppTagChip(
                label: '$_solvedCount solved',
                color: Colors.green,
                foregroundColor: Colors.green,
                outlined: true,
                icon: Icons.task_alt_rounded,
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 12,
              value: _solvedPercent / 100,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Solved rate: ${_solvedPercent.toStringAsFixed(0)}%',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
