import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_widgets.dart';

class AdminSubmissionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> submission;
  final List<Map<String, dynamic>> subAdmins;
  final bool isMainAdmin;

  const AdminSubmissionDetailScreen({
    super.key,
    required this.submission,
    required this.subAdmins,
    required this.isMainAdmin,
  });

  @override
  State<AdminSubmissionDetailScreen> createState() =>
      _AdminSubmissionDetailScreenState();
}

class _AdminSubmissionDetailScreenState
    extends State<AdminSubmissionDetailScreen> {
  late String _status;
  late TextEditingController _progressNoteController;
  late TextEditingController _internalNoteController;
  final TextEditingController _messageController = TextEditingController();
  String? _assignedTo;
  String _priority = 'medium';
  bool _isSaving = false;
  bool _isMarkingSolved = false;
  bool _isSendingMessage = false;
  bool _chatUnavailable = false;
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _status = widget.submission['status'] ?? 'pending';
    _priority = (widget.submission['priority'] ?? 'medium').toString();
    _progressNoteController = TextEditingController(
      text: widget.submission['progress_note'] ?? '',
    );
    _internalNoteController = TextEditingController(
      text: widget.submission['internal_note'] ?? '',
    );
    _assignedTo = widget.submission['assigned_to']?.toString();
    _loadMessages();
  }

  @override
  void dispose() {
    _progressNoteController.dispose();
    _internalNoteController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String get _submissionId => widget.submission['id'].toString();

  Color _statusColor(String status) {
    switch (status) {
      case 'solved':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'solved':
        return 'Solved';
      case 'in_progress':
        return 'In Progress';
      default:
        return 'Pending';
    }
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'low':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  DateTime _dueDate() {
    final dueAt = DateTime.tryParse(widget.submission['due_at']?.toString() ?? '');
    if (dueAt != null) return dueAt.toLocal();
    final createdAt =
        DateTime.tryParse(widget.submission['created_at']?.toString() ?? '');
    return (createdAt ?? DateTime.now()).toLocal().add(const Duration(days: 3));
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showSnack(String message, {Color color = Colors.green}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _safeInsertNotification(String title, String message) async {
    final deviceToken = widget.submission['device_token']?.toString();
    if (deviceToken == null || deviceToken.isEmpty) return;

    try {
      await Supabase.instance.client.from('notifications').insert({
        'device_token': deviceToken,
        'title': title,
        'message': message,
        'submission_id': _submissionId,
        'is_read': false,
      });
    } catch (_) {}
  }

  Future<void> _safeAuditLog(String action, String details) async {
    try {
      await Supabase.instance.client.from('audit_logs').insert({
        'submission_id': _submissionId,
        'actor_user_id': Supabase.instance.client.auth.currentUser?.id,
        'action': action,
        'details': details,
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
      await Supabase.instance.client.from('submission_messages').insert({
        'submission_id': _submissionId,
        'sender_role': 'admin',
        'sender_user_id': Supabase.instance.client.auth.currentUser?.id,
        'body': text,
      });

      await _safeInsertNotification(
        'New admin reply',
        'An admin sent a message on your submission "${widget.submission['title'] ?? ''}".',
      );
      await _safeAuditLog('message_sent', text);
      _messageController.clear();
      await _loadMessages();
    } catch (e) {
      _showSnack('Message failed: ${e.toString()}', color: Colors.red);
    } finally {
      if (mounted) setState(() => _isSendingMessage = false);
    }
  }

  Future<void> _saveProgressNote() async {
    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client
          .from('submissions')
          .update({
            'progress_note': _progressNoteController.text.trim(),
            'internal_note': _internalNoteController.text.trim(),
            'status': _status,
            'priority': _priority,
            'reopen_requested': false,
            if (_assignedTo != null) 'assigned_to': _assignedTo,
          })
          .eq('id', widget.submission['id']);

      await _safeInsertNotification(
        'Submission updated',
        'Your submission "${widget.submission['title'] ?? ''}" was updated to ${_statusLabel(_status)}.',
      );
      await _safeAuditLog(
        'submission_updated',
        'Status=$_status, Priority=$_priority, AssignedTo=${_assignedTo ?? 'none'}',
      );

      if (mounted) {
        _showSnack('Saved successfully');
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Error: ${e.toString()}', color: Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _markAsSolved() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as solved'),
        content: const Text(
          'Are you sure you want to mark this submission as solved? The user will be notified and asked for feedback.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark solved'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isMarkingSolved = true);
    try {
      await Supabase.instance.client
          .from('submissions')
          .update({
            'status': 'solved',
            'priority': _priority,
            'progress_note': _progressNoteController.text.trim(),
            'internal_note': _internalNoteController.text.trim(),
            'reopen_requested': false,
          })
          .eq('id', widget.submission['id']);

      setState(() => _status = 'solved');

      await _safeInsertNotification(
        'Submission solved',
        'Your submission "${widget.submission['title'] ?? ''}" was marked as solved. Please give your feedback.',
      );
      await _safeAuditLog('submission_solved', 'Marked as solved');

      if (mounted) {
        _showSnack('Marked as solved');
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Error: ${e.toString()}', color: Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isMarkingSolved = false);
    }
  }

  Future<void> _approveReopen() async {
    try {
      await Supabase.instance.client
          .from('submissions')
          .update({
            'status': 'in_progress',
            'reopen_requested': false,
          })
          .eq('id', widget.submission['id']);

      setState(() => _status = 'in_progress');
      await _safeInsertNotification(
        'Reopen approved',
        'Your submission "${widget.submission['title'] ?? ''}" has been reopened and moved back to In Progress.',
      );
      await _safeAuditLog('reopen_approved', 'Reopen approved by admin');
      if (mounted) {
        _showSnack('Reopen approved');
      }
    } catch (e) {
      _showSnack('Failed to approve reopen: ${e.toString()}', color: Colors.red);
    }
  }

  Widget _messageBubble(Map<String, dynamic> item) {
    final isAdmin = item['sender_role'] == 'admin';
    final color = isAdmin ? Theme.of(context).colorScheme.primary : Colors.grey;
    final createdAt = DateTime.tryParse(item['created_at']?.toString() ?? '');

    return Align(
      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isAdmin
              ? color.withValues(alpha: 0.14)
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
              isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              isAdmin ? 'Admin' : 'User',
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
                _formatDate(createdAt.toLocal()),
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
    final satisfaction = widget.submission['satisfaction'];
    final satisfactionComment = widget.submission['satisfaction_comment'];
    final isSolved = _status == 'solved';
    final dueDate = _dueDate();
    final isOverdue = !isSolved && DateTime.now().isAfter(dueDate);
    final attachmentUrl = widget.submission['attachment_url']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submission Detail'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
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
                            label: _statusLabel(_status),
                            color: _statusColor(_status),
                          ),
                          AppTagChip(label: widget.submission['submission_type'] ?? ''),
                          AppTagChip(label: widget.submission['category'] ?? ''),
                          AppTagChip(
                            label: '${_priority[0].toUpperCase()}${_priority.substring(1)} Priority',
                            color: _priorityColor(_priority),
                            foregroundColor: _priorityColor(_priority),
                            outlined: true,
                            icon: Icons.flag_outlined,
                          ),
                          AppTagChip(
                            label: isOverdue
                                ? 'Overdue'
                                : 'Due ${dueDate.day}/${dueDate.month}/${dueDate.year}',
                            color: isOverdue ? Colors.red : Colors.blue,
                            foregroundColor: isOverdue ? Colors.red : Colors.blue,
                            outlined: true,
                            icon: isOverdue
                                ? Icons.timer_off_outlined
                                : Icons.event_available_outlined,
                          ),
                          if (widget.submission['reopen_requested'] == true)
                            const AppTagChip(
                              label: 'Reopen requested',
                              color: Colors.orange,
                              foregroundColor: Colors.orange,
                              outlined: true,
                              icon: Icons.replay_circle_filled_outlined,
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        widget.submission['title'] ?? '',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.submission['description'] ?? '',
                          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                        ),
                      ),
                      if (attachmentUrl != null && attachmentUrl.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        AppInfoBanner(
                          message: 'Attachment link added by user: $attachmentUrl',
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
                if (widget.submission['reopen_requested'] == true) ...[
                  const SizedBox(height: 16),
                  AppInfoBanner(
                    message: 'The user requested a reopen for this solved submission.',
                    icon: Icons.replay_circle_filled_outlined,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _approveReopen,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Approve Reopen'),
                  ),
                ],
                const SizedBox(height: 16),
                AppSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionTitle(
                        title: 'Workflow controls',
                        subtitle: 'Update status, priority, notes, and assignment.',
                        icon: Icons.settings_suggest_outlined,
                      ),
                      const SizedBox(height: 16),
                      if (!isSolved) ...[
                        DropdownButtonFormField<String>(
                          value: _status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            prefixIcon: Icon(Icons.update_rounded),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'pending', child: Text('Pending')),
                            DropdownMenuItem(
                              value: 'in_progress',
                              child: Text('In Progress'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _status = val);
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      DropdownButtonFormField<String>(
                        value: _priority,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                          DropdownMenuItem(value: 'medium', child: Text('Medium')),
                          DropdownMenuItem(value: 'high', child: Text('High')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _priority = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _progressNoteController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'User-visible progress note',
                          hintText: 'Explain current progress or delay clearly',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _internalNoteController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Internal admin note',
                          hintText: 'Only for admin/internal follow-up',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                      ),
                      if (widget.isMainAdmin && widget.subAdmins.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String?>(
                          value: _assignedTo,
                          decoration: const InputDecoration(
                            labelText: 'Assign to sub-admin',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Unassigned'),
                            ),
                            ...widget.subAdmins.map(
                              (sa) => DropdownMenuItem<String?>(
                                value: sa['id']?.toString(),
                                child: Text(
                                  '${sa['assigned_category'] ?? 'No category'} Sub-Admin',
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) => setState(() => _assignedTo = val),
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (!isSolved)
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : _saveProgressNote,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(_isSaving ? 'Saving...' : 'Save changes'),
                        ),
                      if (!isSolved) const SizedBox(height: 12),
                      if (!isSolved)
                        FilledButton.icon(
                          onPressed: _isMarkingSolved ? null : _markAsSolved,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          icon: _isMarkingSolved
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
                            _isMarkingSolved ? 'Marking...' : 'Mark as Solved',
                          ),
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
                        title: 'Submission chat',
                        subtitle: 'Use this to ask follow-up questions or give direct updates.',
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
                          message: 'No messages yet. Start the conversation with the user.',
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
                            labelText: 'Reply',
                            hintText: 'Write a message to the user',
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
                          label: Text(_isSendingMessage ? 'Sending...' : 'Send reply'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (isSolved)
                  AppSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionTitle(
                          title: 'User feedback',
                          subtitle: 'Satisfaction result after the issue was marked solved.',
                          icon: Icons.feedback_outlined,
                        ),
                        const SizedBox(height: 16),
                        if (satisfaction != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: satisfaction == 'satisfied'
                                  ? Colors.green.withValues(alpha: 0.08)
                                  : Colors.orange.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: satisfaction == 'satisfied'
                                    ? Colors.green.withValues(alpha: 0.24)
                                    : Colors.orange.withValues(alpha: 0.24),
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
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      satisfaction == 'satisfied'
                                          ? 'User is satisfied'
                                          : 'User is not satisfied',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: satisfaction == 'satisfied'
                                            ? Colors.green[700]
                                            : Colors.orange[800],
                                      ),
                                    ),
                                  ],
                                ),
                                if (satisfactionComment != null &&
                                    satisfactionComment.toString().isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    satisfactionComment.toString(),
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ],
                            ),
                          )
                        else
                          const AppInfoBanner(
                            message: 'Waiting for user feedback.',
                            icon: Icons.hourglass_empty_rounded,
                            color: Colors.blue,
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
