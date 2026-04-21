import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_settings.dart';
import 'app_widgets.dart';
import 'my_submissions_screen.dart';
import 'notifications_screen.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  String? selectedType;
  String? selectedCategory;
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final attachmentUrlController = TextEditingController();
  bool _isLoading = false;

  final types = ['Complaint', 'Suggestion', 'Feedback'];
  final categories = [
    'Infrastructure',
    'Academic',
    'Hostel',
    'Canteen',
    'Management',
    'Other',
  ];

  final List<String> _blockedWords = const [
    'idiot',
    'stupid',
    'damn',
    'hate',
    'abuse',
    'kill',
  ];

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    attachmentUrlController.dispose();
    super.dispose();
  }

  void _clearForm() {
    setState(() {
      selectedType = null;
      selectedCategory = null;
      titleController.clear();
      descriptionController.clear();
      attachmentUrlController.clear();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  bool _containsBlockedWords(String value) {
    final lower = value.toLowerCase();
    return _blockedWords.any((word) => lower.contains(word));
  }

  DateTime _defaultDueDate() => DateTime.now().add(const Duration(days: 3));

  Future<int> _unreadNotificationCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('device_token');
      if (token == null || token.isEmpty) return 0;
      final data = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('device_token', token)
          .eq('is_read', false);
      return (data as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<String?> _findAssignedSubAdmin(String category) async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('role', 'sub_admin')
          .eq('assigned_category', category)
          .limit(1);

      if ((data as List).isEmpty) return null;
      return data.first['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _confirmDuplicateIfNeeded(
    String deviceToken,
    String normalizedTitle,
  ) async {
    try {
      final recent = await Supabase.instance.client
          .from('submissions')
          .select('title, created_at')
          .eq('device_token', deviceToken)
          .order('created_at', ascending: false)
          .limit(10);

      for (final item in List<Map<String, dynamic>>.from(recent)) {
        final title = (item['title'] ?? '').toString().trim().toLowerCase();
        final createdAt = DateTime.tryParse(
          item['created_at']?.toString() ?? '',
        );
        if (title == normalizedTitle &&
            createdAt != null &&
            DateTime.now().difference(createdAt.toLocal()).inDays <= 14) {
          final result = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Possible duplicate'),
              content: const Text(
                'You recently submitted a very similar title. Do you still want to submit this again?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Submit anyway'),
                ),
              ],
            ),
          );
          return result == true;
        }
      }
    } catch (_) {}
    return true;
  }

  Future<void> _submitForm() async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final attachmentUrl = attachmentUrlController.text.trim();

    if (selectedType == null ||
        selectedCategory == null ||
        title.isEmpty ||
        description.isEmpty) {
      _showError('Please fill all required fields');
      return;
    }

    if (_containsBlockedWords(title) || _containsBlockedWords(description)) {
      _showError('Please keep the language respectful and professional');
      return;
    }

    if (attachmentUrl.isNotEmpty &&
        !attachmentUrl.startsWith('http://') &&
        !attachmentUrl.startsWith('https://')) {
      _showError('Attachment link must start with http:// or https://');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceToken = prefs.getString('device_token') ?? '';

      final shouldContinue = await _confirmDuplicateIfNeeded(
        deviceToken,
        title.toLowerCase(),
      );
      if (!shouldContinue) return;

      final assignedTo = await _findAssignedSubAdmin(selectedCategory!);

      await Supabase.instance.client.from('submissions').insert({
        'submission_type': selectedType,
        'category': selectedCategory,
        'title': title,
        'description': description,
        'attachment_url': attachmentUrl.isEmpty ? null : attachmentUrl,
        'device_token': deviceToken,
        'assigned_to': assignedTo,
        'status': 'pending',
        'priority': 'medium',
        'due_at': _defaultDueDate().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        _showError(
          'Submit failed. Apply the SQL setup file first if new columns are missing.\n${e.toString()}',
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

  Widget _buildNotificationButton() {
    return FutureBuilder<int>(
      future: _unreadNotificationCount(),
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;
        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'Notifications',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),
            if (unread > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('VoiceBox'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'My Submissions',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MySubmissionsScreen()),
              );
            },
          ),
          _buildNotificationButton(),
          IconButton(
            icon: const Icon(Icons.dark_mode_outlined),
            tooltip: 'Toggle theme',
            onPressed: AppSettings.toggleThemeMode,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppGradientPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Submit your voice',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your submission stays anonymous. It can be routed automatically and reopened if you are not satisfied.',
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
                            label: 'Anonymous tracking',
                            icon: Icons.privacy_tip_outlined,
                            color: Colors.white.withValues(alpha: 0.14),
                            foregroundColor: Colors.white,
                          ),
                          AppTagChip(
                            label: 'Auto-routing',
                            icon: Icons.alt_route_rounded,
                            color: Colors.white.withValues(alpha: 0.14),
                            foregroundColor: Colors.white,
                          ),
                          AppTagChip(
                            label: 'In-app notifications',
                            icon: Icons.notifications_active_outlined,
                            color: Colors.white.withValues(alpha: 0.14),
                            foregroundColor: Colors.white,
                          ),
                        ],
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
                        title: 'New submission',
                        subtitle:
                            'Fill in the required fields. Use a clear title and respectful language.',
                        icon: Icons.edit_note_rounded,
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Submission Type *',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        hint: const Text('Select type'),
                        items: types
                            .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => selectedType = value),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category *',
                          prefixIcon: Icon(Icons.folder_outlined),
                        ),
                        hint: const Text('Select category'),
                        items: categories
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => selectedCategory = value),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Title *',
                          hintText: 'Enter a short, clear title',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descriptionController,
                        maxLines: 6,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                          hintText: 'Explain the issue or suggestion clearly',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: attachmentUrlController,
                        decoration: InputDecoration(
                          labelText: 'Attachment link (optional)',
                          hintText: 'Paste a photo or file URL if you have one',
                          prefixIcon: const Icon(Icons.attach_file_rounded),
                          suffixIcon: attachmentUrlController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(
                                        text: attachmentUrlController.text,
                                      ),
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Attachment link copied',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.copy_rounded),
                                ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 18),
                      const AppInfoBanner(
                        message:
                            'Spam filtering and duplicate detection are active. Similar repeated titles may ask for confirmation before submitting.',
                        icon: Icons.shield_outlined,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _isLoading ? null : _submitForm,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(_isLoading ? 'Submitting...' : 'Submit'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
