import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_submission_detail_screen.dart';
import 'app_settings.dart';
import 'app_widgets.dart';

class SubAdminHomeScreen extends StatefulWidget {
  const SubAdminHomeScreen({super.key});

  @override
  State<SubAdminHomeScreen> createState() => _SubAdminHomeScreenState();
}

class _SubAdminHomeScreenState extends State<SubAdminHomeScreen> {
  List<Map<String, dynamic>> _submissions = [];
  String _assignedCategory = '';
  String _selectedStatusFilter = 'All';
  String _selectedSort = 'Newest';
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  final statusFilters = ['All', 'Pending', 'In Progress', 'Solved'];
  final sortOptions = ['Newest', 'Oldest', 'Priority', 'Needs Attention'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _fetchMyCategory();
    await _fetchSubmissions();
  }

  Future<void> _fetchMyCategory() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final res = await Supabase.instance.client
          .from('profiles')
          .select('assigned_category')
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _assignedCategory = res['assigned_category'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _fetchSubmissions() async {
    if (_assignedCategory.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = await Supabase.instance.client
          .from('submissions')
          .select()
          .eq('category', _assignedCategory)
          .order('created_at', ascending: false);

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

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
    }
  }

  int get _totalCount => _submissions.length;
  int get _pendingCount =>
      _submissions.where((s) => s['status'] == 'pending').length;
  int get _inProgressCount =>
      _submissions.where((s) => s['status'] == 'in_progress').length;
  int get _solvedCount =>
      _submissions.where((s) => s['status'] == 'solved').length;
  int get _unsatisfiedCount =>
      _submissions.where((s) => s['satisfaction'] == 'not_satisfied').length;

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

  DateTime _dueDate(Map<String, dynamic> item) {
    final dueAt = DateTime.tryParse(item['due_at']?.toString() ?? '');
    if (dueAt != null) return dueAt.toLocal();
    final createdAt = DateTime.tryParse(item['created_at']?.toString() ?? '');
    return (createdAt ?? DateTime.now()).toLocal().add(const Duration(days: 3));
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

  bool _matchesSearch(Map<String, dynamic> item) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    final text = [
      item['title'],
      item['description'],
      item['category'],
      item['submission_type'],
      item['priority'],
      item['status'],
    ].join(' ').toLowerCase();
    return text.contains(query);
  }

  List<Map<String, dynamic>> get _filteredSubmissions {
    final items = _submissions.where((s) {
      final statusMatch = _selectedStatusFilter == 'All' ||
          s['status'] ==
              _selectedStatusFilter.toLowerCase().replaceAll(' ', '_');
      return statusMatch && _matchesSearch(s);
    }).toList();

    items.sort((a, b) {
      switch (_selectedSort) {
        case 'Oldest':
          return (DateTime.tryParse(a['created_at']?.toString() ?? '') ??
                  DateTime.now())
              .compareTo(
            DateTime.tryParse(b['created_at']?.toString() ?? '') ??
                DateTime.now(),
          );
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

          return rank(a['priority']?.toString())
              .compareTo(rank(b['priority']?.toString()));
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
      'title,status,category,type,priority,reopen_requested,created_at',
    );
    for (final item in _filteredSubmissions) {
      String cell(dynamic value) =>
          '"${(value ?? '').toString().replaceAll('"', '""')}"';
      buffer.writeln([
        cell(item['title']),
        cell(item['status']),
        cell(item['category']),
        cell(item['submission_type']),
        cell(item['priority']),
        cell(item['reopen_requested']),
        cell(item['created_at']),
      ].join(','));
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current list copied as CSV')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = _submissions.where((s) {
      final status = s['status']?.toString() ?? 'pending';
      return status != 'solved' && DateTime.now().isAfter(_dueDate(s));
    }).length;
    final reopenRequested =
        _submissions.where((s) => s['reopen_requested'] == true).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _assignedCategory.isEmpty
              ? 'Category Admin Dashboard'
              : '$_assignedCategory Admin',
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: 'Copy CSV',
            onPressed: _copyCsv,
          ),
          IconButton(
            icon: const Icon(Icons.dark_mode_outlined),
            tooltip: 'Toggle theme',
            onPressed: AppSettings.toggleThemeMode,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchSubmissions,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  AppGradientPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _assignedCategory.isEmpty
                              ? 'No assigned category yet'
                              : 'Manage $_assignedCategory items',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _assignedCategory.isEmpty
                              ? 'Ask the main admin to assign you a category so you can start reviewing submissions.'
                              : 'Search the queue, sort by urgency, respond in chat, and keep users updated with clear progress notes.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            AppTagChip(
                              label: '$reopenRequested reopen requested',
                              icon: Icons.replay_circle_filled_outlined,
                              color: Colors.white.withValues(alpha: 0.14),
                              foregroundColor: Colors.white,
                            ),
                            AppTagChip(
                              label: '$overdue overdue',
                              icon: Icons.timer_off_outlined,
                              color: Colors.white.withValues(alpha: 0.14),
                              foregroundColor: Colors.white,
                            ),
                          ],
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
                          value: '$_totalCount',
                          icon: Icons.inbox_rounded,
                          color: Colors.deepPurple,
                        ),
                        const SizedBox(width: 12),
                        AppStatCard(
                          title: 'Pending',
                          value: '$_pendingCount',
                          icon: Icons.pending_actions_rounded,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 12),
                        AppStatCard(
                          title: 'In Progress',
                          value: '$_inProgressCount',
                          icon: Icons.timelapse_rounded,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        AppStatCard(
                          title: 'Solved',
                          value: '$_solvedCount',
                          icon: Icons.task_alt_rounded,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 12),
                        AppStatCard(
                          title: 'Unsatisfied',
                          value: '$_unsatisfiedCount',
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
                          title: 'Search and sort',
                          subtitle: 'Filter your category queue by status and urgency.',
                          icon: Icons.filter_alt_outlined,
                        ),
                        const SizedBox(height: 16),
                        AppSearchField(
                          controller: _searchController,
                          hintText: 'Search by title, description, category, status, or priority',
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
                              onSelected: (_) =>
                                  setState(() => _selectedStatusFilter = filter),
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
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
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
                  if (_assignedCategory.isEmpty)
                    const SizedBox(
                      height: 320,
                      child: AppEmptyState(
                        title: 'No assigned category',
                        subtitle: 'You do not have an assigned category yet. Contact the main admin.',
                        icon: Icons.folder_off_outlined,
                      ),
                    )
                  else if (_filteredSubmissions.isEmpty)
                    const SizedBox(
                      height: 320,
                      child: AppEmptyState(
                        title: 'No submissions found',
                        subtitle: 'There are no items for the selected search or filters.',
                        icon: Icons.search_off_rounded,
                      ),
                    )
                  else
                    ..._filteredSubmissions.map((item) {
                      final status = item['status'] ?? 'pending';
                      final statusColor = _statusColor(status);
                      final hasUnsatisfied =
                          item['satisfaction'] == 'not_satisfied';
                      final isOverdue = status != 'solved' &&
                          DateTime.now().isAfter(_dueDate(item));

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
                                  builder: (_) => AdminSubmissionDetailScreen(
                                    submission: item,
                                    subAdmins: const [],
                                    isMainAdmin: false,
                                  ),
                                ),
                              );
                              _fetchSubmissions();
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
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    AppTagChip(label: item['submission_type'] ?? ''),
                                    AppTagChip(
                                      label: '${(item['priority'] ?? 'medium').toString().toUpperCase()} priority',
                                      color: _priorityColor(item['priority']),
                                      foregroundColor: _priorityColor(item['priority']),
                                      outlined: true,
                                      icon: Icons.flag_outlined,
                                    ),
                                    AppTagChip(
                                      label: 'Created ${_timeAgo(item['created_at'])}',
                                      icon: Icons.schedule_outlined,
                                    ),
                                    if (hasUnsatisfied)
                                      const AppTagChip(
                                        label: 'Not satisfied',
                                        color: Colors.pink,
                                        foregroundColor: Colors.pink,
                                        outlined: true,
                                        icon: Icons.sentiment_dissatisfied_rounded,
                                      ),
                                    if (item['reopen_requested'] == true)
                                      const AppTagChip(
                                        label: 'Reopen requested',
                                        color: Colors.orange,
                                        foregroundColor: Colors.orange,
                                        outlined: true,
                                        icon: Icons.replay_circle_filled_outlined,
                                      ),
                                    if (isOverdue)
                                      const AppTagChip(
                                        label: 'Overdue',
                                        color: Colors.red,
                                        foregroundColor: Colors.red,
                                        outlined: true,
                                        icon: Icons.timer_off_outlined,
                                      ),
                                  ],
                                ),
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
}
