import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_widgets.dart';

class UserSubmissionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> submission;

  const UserSubmissionDetailScreen({
    super.key,
    required this.submission,
  });

  @override
  State<UserSubmissionDetailScreen> createState() =>
      _UserSubmissionDetailScreenState();
}

class _UserSubmissionDetailScreenState
    extends State<UserSubmissionDetailScreen> {
  late Map<String, dynamic> _submission;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSubmittingFeedback = false;
  bool _isRequestingReopen = false;
  bool _isSendingMessage = false;
  bool _chatUnavailable = false;
  String? _selectedSatisfaction;
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _submission = Map<String, dynamic>.from(widget.submission);
    _loadMessages();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String get _submissionId => _submission['id'].toString();

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

  String _formatDate(String? createdAt) {
    if (createdAt == null) return '';
    final dt = DateTime.tryParse(createdAt)?.toLocal();
    if (dt == null) return '';
    return '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  DateTime _dueDate() {
    final dueAt = DateTime.tryParse(_submission['due_at']?.toString() ?? '');
    if (dueAt != null) return dueAt.toLocal();
    final createdAt =
        DateTime.tryParse(_submission['created_at']?.toString() ?? '');
    return (createdAt ?? DateTime.now()).toLocal().add(const Duration(days: 3));
  }

  void _showSnack(String message, {Color color = Colors.green}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _safeInsertNotificationForAdmins(String title, String message) async {
    try {
      await Supabase.instance.client.from('audit_logs').insert({
        'submission_id': _submissionId,
        'actor_user_id': Supabase.instance.client.auth.currentUser?.id,
        'action': title,
        'details': message,
      });
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    try {
      final data = await Supabase.instance.client
          .from('submission_messages')
          .select()
          .eq('submission_id', _submissionId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data);
          _chatUnavailable = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _chatUnavailable = true);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSendingMessage = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceToken = prefs.getString('device_token');

      await Supabase.instance.client.from('submission_messages').insert({
        'submission_id': _submissionId,
        'sender_role': 'user',
        'device_token': deviceToken,
        'sender_user_id': Supabase.instance.client.auth.currentUser?.id,
        'body': text,
      });

      await _safeInsertNotificationForAdmins(
        'user_message',
        'User replied on "${_submission['title'] ?? ''}"',
      );
      _messageController.clear();
      await _loadMessages();
    } catch (e) {
      _showSnack('Message failed: ${e.toString()}', color: Colors.red);
    } finally {
      if (mounted) setState(() => _isSendingMessage = false);
    }
  }

  Future<void> _submitFeedback() async {
    if (_selectedSatisfaction == null) {
      _showSnack(
        'Please select Satisfied or Not Satisfied',
        color: Colors.red,
      );
      return;
    }

    if (_selectedSatisfaction == 'not_satisfied' &&
        _commentController.text.trim().isEmpty) {
      _showSnack(
        'Please add a comment explaining your concern',
        color: Colors.red,
      );
      return;
    }

    setState(() => _isSubmittingFeedback = true);

    try {
      final updateData = {
        'satisfaction': _selectedSatisfaction,
        if (_selectedSatisfaction == 'not_satisfied')
          'satisfaction_comment': _commentController.text.trim(),
        if (_selectedSatisfaction == 'not_satisfied')
          'reopen_requested': true,
      };

      await Supabase.instance.client
          .from('submissions')
          .update(updateData)
          .eq('id', _submission['id']);

      setState(() {
        _submission['satisfaction'] = _selectedSatisfaction;
        if (_selectedSatisfaction == 'not_satisfied') {
          _submission['satisfaction_comment'] = _commentController.text.trim();
          _submission['reopen_requested'] = true;
        }
      });

      await _safeInsertNotificationForAdmins(
        'user_feedback',
        _selectedSatisfaction == 'satisfied'
            ? 'User is satisfied with "${_submission['title'] ?? ''}"'
            : 'User is not satisfied and requested reopen for "${_submission['title'] ?? ''}"',
      );

      if (mounted) {
        _showSnack(
          _selectedSatisfaction == 'satisfied'
              ? 'Thank you for your feedback'
              : 'Feedback submitted and reopen requested',
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Error: ${e.toString()}', color: Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isSubmittingFeedback = false);
    }
  }

  Future<void> _requestReopenOnly() async {
    setState(() => _isRequestingReopen = true);
    try {
      await Supabase.instance.client
          .from('submissions')
          .update({'reopen_requested': true})
          .eq('id', _submission['id']);

      setState(() => _submission['reopen_requested'] = true);
      await _safeInsertNotificationForAdmins(
        'reopen_requested',
        'User requested reopen for "${_submission['title'] ?? ''}"',
      );
      _showSnack('Reopen requested');
    } catch (e) {
      _showSnack('Reopen failed: ${e.toString()}', color: Colors.red);
    } finally {
      if (mounted) setState(() => _isRequestingReopen = false);
    }
  }

  Widget _messageBubble(Map<String, dynamic> item) {
    final isAdmin = item['sender_role'] == 'admin';
    final color = isAdmin ? Theme.of(context).colorScheme.primary : Colors.grey;
    final createdAt = DateTime.tryParse(item['created_at']?.toString() ?? '');

    return Align(
      alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isAdmin
              ? color.withValues(alpha: 0.12)
              : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isAdmin
                ? color.withValues(alpha: 0.28)
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isAdmin ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Text(
              isAdmin ? 'Admin' : 'You',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isAdmin ? color : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item['body']?.toString() ?? '',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            if (createdAt != null) ...[
              const SizedBox(height: 6),
              Text(
                _formatDate(createdAt.toIso8601String()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _submission['status'] ?? 'pending';
    final isSolved = status == 'solved';
    final alreadyGaveFeedback = _submission['satisfaction'] != null;
    final satisfaction = _submission['satisfaction'];
    final satisfactionComment = _submission['satisfaction_comment'];
    final progressNote = _submission['progress_note'];
    final dueDate = _dueDate();
    final attachmentUrl = _submission['attachment_url']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submission Detail'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          AppStatusChip(
                            label: _statusLabel(status),
                            color: _statusColor(status),
                          ),
                          AppTagChip(label: _submission['submission_type'] ?? ''),
                          AppTagChip(label: _submission['category'] ?? ''),
                          AppTagChip(
                            label:
                                '${(_submission['priority'] ?? 'medium').toString().toUpperCase()} priority',
                            color: _priorityColor(_submission['priority']?.toString()),
                            foregroundColor:
                                _priorityColor(_submission['priority']?.toString()),
                            outlined: true,
                            icon: Icons.flag_outlined,
                          ),
                          AppTagChip(
                            label: 'Due ${dueDate.day}/${dueDate.month}/${dueDate.year}',
                            color: status == 'solved' ? Colors.green : Colors.blue,
                            foregroundColor:
                                status == 'solved' ? Colors.green : Colors.blue,
                            outlined: true,
                            icon: Icons.event_available_outlined,
                          ),
                          if (_submission['reopen_requested'] == true)
                            const AppTagChip(
                              label: 'Reopen requested',
                              color: Colors.orange,
                              foregroundColor: Colors.orange,
                              outlined: true,
                              icon: Icons.replay_circle_filled_outlined,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Submitted: ${_formatDate(_submission['created_at'])}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _submission['title'] ?? '',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _submission['description'] ?? '',
                          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                        ),
                      ),
                      if (attachmentUrl != null && attachmentUrl.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        AppInfoBanner(
                          message: 'Attachment link: $attachmentUrl',
                          icon: Icons.attach_file_rounded,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: attachmentUrl));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Attachment link copied')),
                                );
                              }
                            },
                            icon: const Icon(Icons.copy_rounded),
                            label: const Text('Copy attachment link'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (progressNote != null && progressNote.toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  AppSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionTitle(
                          title: 'Admin progress note',
                          subtitle: 'Latest visible update from the admin team.',
                          icon: Icons.notes_rounded,
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.18),
                            ),
                          ),
                          child: Text(
                            progressNote.toString(),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                AppSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionTitle(
                        title: 'Submission chat',
                        subtitle: 'Ask follow-up questions or reply to the admin team.',
                        icon: Icons.chat_bubble_outline_rounded,
                      ),
                      const SizedBox(height: 16),
                      if (_chatUnavailable)
                        const AppInfoBanner(
                          message: 'Chat will work after you apply the SQL setup file that creates the submission_messages table.',
                          icon: Icons.info_outline,
                          color: Colors.orange,
                        )
                      else if (_messages.isEmpty)
                        const AppInfoBanner(
                          message: 'No messages yet. You can send a follow-up if needed.',
                          icon: Icons.mark_chat_unread_outlined,
                          color: Colors.blue,
                        )
                      else
                        ..._messages.map(_messageBubble),
                      if (!_chatUnavailable) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _messageController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Message',
                            hintText: 'Type a message to the admin',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.reply_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _isSendingMessage ? null : _sendMessage,
                          icon: _isSendingMessage
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(_isSendingMessage ? 'Sending...' : 'Send message'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionTitle(
                        title: 'Satisfaction feedback',
                        subtitle: 'Tell the admin whether this issue was handled well.',
                        icon: Icons.feedback_outlined,
                      ),
                      const SizedBox(height: 16),
                      if (!isSolved)
                        const AppInfoBanner(
                          message:
                              'Your submission is being reviewed. You can give feedback once it is marked as solved.',
                          icon: Icons.hourglass_empty_rounded,
                          color: Colors.orange,
                        )
                      else if (alreadyGaveFeedback)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: (satisfaction == 'satisfied'
                                    ? Colors.green
                                    : Colors.orange)
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: (satisfaction == 'satisfied'
                                      ? Colors.green
                                      : Colors.orange)
                                  .withValues(alpha: 0.24),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    satisfaction == 'satisfied'
                                        ? Icons.sentiment_satisfied_alt
                                        : Icons.sentiment_dissatisfied,
                                    color: satisfaction == 'satisfied'
                                        ? Colors.green
                                        : Colors.orange,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    satisfaction == 'satisfied'
                                        ? 'You are satisfied'
                                        : 'You are not satisfied',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: satisfaction == 'satisfied'
                                          ? Colors.green[700]
                                          : Colors.orange[800],
                                    ),
                                  ),
                                ],
                              ),
                              if (satisfactionComment != null &&
                                  satisfactionComment.toString().isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Text(
                                  'Your comment',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  satisfactionComment.toString(),
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                              if (satisfaction == 'not_satisfied' &&
                                  _submission['reopen_requested'] != true) ...[
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed:
                                      _isRequestingReopen ? null : _requestReopenOnly,
                                  icon: _isRequestingReopen
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.replay_rounded),
                                  label: const Text('Request reopen again'),
                                ),
                              ],
                            ],
                          ),
                        )
                      else ...[
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ChoiceChip(
                              label: const Text('Satisfied'),
                              selected: _selectedSatisfaction == 'satisfied',
                              onSelected: (_) => setState(
                                () => _selectedSatisfaction = 'satisfied',
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('Not Satisfied'),
                              selected: _selectedSatisfaction == 'not_satisfied',
                              onSelected: (_) => setState(
                                () => _selectedSatisfaction = 'not_satisfied',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _commentController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: _selectedSatisfaction == 'not_satisfied'
                                ? 'Tell us what is still wrong *'
                                : 'Optional comment',
                            hintText: _selectedSatisfaction == 'not_satisfied'
                                ? 'Explain why the issue should be reopened'
                                : 'Add any extra feedback',
                            alignLabelWithHint: true,
                            prefixIcon: const Icon(Icons.edit_note_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_selectedSatisfaction == 'not_satisfied')
                          const AppInfoBanner(
                            message:
                                'Submitting Not Satisfied will also request a reopen for this issue.',
                            icon: Icons.replay_circle_filled_outlined,
                            color: Colors.orange,
                          ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed:
                              _isSubmittingFeedback ? null : _submitFeedback,
                          icon: _isSubmittingFeedback
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            _isSubmittingFeedback
                                ? 'Submitting...'
                                : 'Submit feedback',
                          ),
                        ),
                      ],
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
