import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _showUnreadOnly = false;
  String? _deviceToken;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _deviceToken = prefs.getString('device_token');

      if (_deviceToken == null || _deviceToken!.isEmpty) {
        setState(() => _items = []);
        return;
      }

      final data = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('device_token', _deviceToken!)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() => _items = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Notifications are unavailable until the SQL setup is applied.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAllRead() async {
    if (_deviceToken == null || _deviceToken!.isEmpty) return;

    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('device_token', _deviceToken!)
          .eq('is_read', false);

      await _loadNotifications();
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (!_showUnreadOnly) return _items;
    return _items.where((item) => item['is_read'] != true).toList();
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

  @override
  Widget build(BuildContext context) {
    final unreadCount = _items.where((item) => item['is_read'] != true).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            onPressed: _loadNotifications,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                AppSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSectionTitle(
                        title: 'Updates',
                        subtitle: 'Status changes, solved updates, reopen requests, and admin replies appear here.',
                        icon: Icons.notifications_active_outlined,
                        trailing: unreadCount == 0
                            ? null
                            : TextButton(
                                onPressed: _markAllRead,
                                child: const Text('Mark all read'),
                              ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected: !_showUnreadOnly,
                            onSelected: (_) => setState(() => _showUnreadOnly = false),
                          ),
                          ChoiceChip(
                            label: Text('Unread ($unreadCount)'),
                            selected: _showUnreadOnly,
                            onSelected: (_) => setState(() => _showUnreadOnly = true),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  AppInfoBanner(
                    message: _error!,
                    icon: Icons.info_outline,
                    color: Colors.orange,
                  )
                else if (_filteredItems.isEmpty)
                  const SizedBox(
                    height: 360,
                    child: AppEmptyState(
                      title: 'No notifications',
                      subtitle: 'When admins update your submission, the alerts will appear here.',
                      icon: Icons.notifications_none_rounded,
                    ),
                  )
                else
                  ..._filteredItems.map((item) {
                    final isUnread = item['is_read'] != true;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppSurface(
                        padding: const EdgeInsets.all(18),
                        color: isUnread
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
                            : null,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                isUnread ? Icons.notifications_active : Icons.notifications_none,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item['title']?.toString() ?? 'Notification',
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      Text(
                                        _timeAgo(item['created_at']?.toString()),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item['message']?.toString() ?? '',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          height: 1.45,
                                        ),
                                  ),
                                  if (isUnread) ...[
                                    const SizedBox(height: 10),
                                    AppTagChip(
                                      label: 'Unread',
                                      icon: Icons.markunread_outlined,
                                      color: Theme.of(context).colorScheme.primary,
                                      foregroundColor: Theme.of(context).colorScheme.primary,
                                      outlined: true,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
