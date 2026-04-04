import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  String selectedFilter = 'All';
  final filters = ['All', 'Complaint', 'Suggestion', 'Feedback'];

  List<Map<String, dynamic>> submissions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSubmissions();
  }

  Future<void> _fetchSubmissions() async {
    setState(() => _isLoading = true);

    try {
      final data = await Supabase.instance.client
          .from('submissions')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          submissions = List<Map<String, dynamic>>.from(data);
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
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  List<Map<String, dynamic>> get filteredSubmissions {
    if (selectedFilter == 'All') return submissions;
    return submissions
        .where((s) => s['submission_type'] == selectedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSubmissions,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _logout();
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _StatCard(
                        title: 'Total',
                        count: submissions.length,
                        color: const Color.fromARGB(255, 83, 197, 87),
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        title: 'Complaints',
                        count: submissions
                            .where((s) => s['submission_type'] == 'Complaint')
                            .length,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        title: 'Suggestions',
                        count: submissions
                            .where((s) => s['submission_type'] == 'Suggestion')
                            .length,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 50,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: filters
                        .map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(f),
                              selected: selectedFilter == f,
                              onSelected: (_) =>
                                  setState(() => selectedFilter = f),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filteredSubmissions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 80,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Submissions Yet',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Submissions from users will appear here',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _fetchSubmissions,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredSubmissions.length,
                            itemBuilder: (context, index) {
                              final item = filteredSubmissions[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  title: Text(
                                    item['title'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 8),
                                      Text(
                                        item['description'] ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Chip(
                                            label: Text(
                                              item['submission_type'] ?? '',
                                              style: const TextStyle(
                                                  fontSize: 12),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Chip(
                                            label: Text(
                                              item['category'] ?? '',
                                              style: const TextStyle(
                                                  fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _StatCard({
    required String title,
    required int count,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
