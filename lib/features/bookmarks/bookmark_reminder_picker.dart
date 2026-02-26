import 'package:flutter/material.dart';
import 'package:lunaris/core/models/bookmark.dart';

class BookmarkReminderResult {
  final String? name;
  final DateTime? reminderAt;
  final int autoDeletePreference;

  const BookmarkReminderResult({
    this.name,
    this.reminderAt,
    this.autoDeletePreference = AutoDeletePreference.never,
  });
}

Future<BookmarkReminderResult?> showBookmarkReminderPicker(
  BuildContext context, {
  String? initialName,
  DateTime? initialReminder,
  int initialAutoDelete = AutoDeletePreference.never,
}) {
  return showModalBottomSheet<BookmarkReminderResult>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _ReminderPickerSheet(
      initialName: initialName,
      initialReminder: initialReminder,
      initialAutoDelete: initialAutoDelete,
    ),
  );
}

class _ReminderPickerSheet extends StatefulWidget {
  final String? initialName;
  final DateTime? initialReminder;
  final int initialAutoDelete;

  const _ReminderPickerSheet({
    this.initialName,
    this.initialReminder,
    this.initialAutoDelete = AutoDeletePreference.never,
  });

  @override
  State<_ReminderPickerSheet> createState() => _ReminderPickerSheetState();
}

class _ReminderPickerSheetState extends State<_ReminderPickerSheet> {
  late final TextEditingController _nameController;
  DateTime? _selectedReminder;
  late int _autoDelete;

  static const _quickOptions = [
    ('Later today', _laterToday),
    ('Tomorrow', _tomorrow),
    ('Next week', _nextWeek),
    ('Next month', _nextMonth),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _selectedReminder = widget.initialReminder;
    _autoDelete = widget.initialAutoDelete;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  static DateTime _laterToday() {
    final now = DateTime.now();
    if (now.hour >= 18) {
      return DateTime(now.year, now.month, now.day + 1, 8, 0);
    }
    return DateTime(now.year, now.month, now.day, 18, 0);
  }

  static DateTime _tomorrow() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, 8, 0);
  }

  static DateTime _nextWeek() {
    final now = DateTime.now();
    final daysUntilMonday = (DateTime.monday - now.weekday + 7) % 7;
    final next = now.add(Duration(days: daysUntilMonday == 0 ? 7 : daysUntilMonday));
    return DateTime(next.year, next.month, next.day, 8, 0);
  }

  static DateTime _nextMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 1, 8, 0);
  }

  Future<void> _pickCustomDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedReminder ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _selectedReminder ?? DateTime(now.year, now.month, now.day, 8, 0),
      ),
    );
    if (time == null || !mounted) return;

    setState(() {
      _selectedReminder = DateTime(
        date.year, date.month, date.day, time.hour, time.minute,
      );
    });
  }

  void _submit() {
    Navigator.pop(
      context,
      BookmarkReminderResult(
        name: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        reminderAt: _selectedReminder,
        autoDeletePreference: _autoDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Bookmark', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name (optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 20),
                Text('Reminder', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final opt in _quickOptions)
                      ChoiceChip(
                        label: Text(opt.$1),
                        selected: _selectedReminder == opt.$2(),
                        onSelected: (_) =>
                            setState(() => _selectedReminder = opt.$2()),
                      ),
                    ActionChip(
                      label: const Text('Custom...'),
                      avatar: const Icon(Icons.calendar_today, size: 16),
                      onPressed: _pickCustomDateTime,
                    ),
                    if (_selectedReminder != null)
                      ActionChip(
                        label: const Text('Clear'),
                        avatar: const Icon(Icons.close, size: 16),
                        onPressed: () =>
                            setState(() => _selectedReminder = null),
                      ),
                  ],
                ),
                if (_selectedReminder != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _formatDateTime(_selectedReminder!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text('Auto-delete', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                RadioGroup<int>(
                  groupValue: _autoDelete,
                  onChanged: (v) => setState(() => _autoDelete = v ?? 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      return RadioListTile<int>(
                        value: i,
                        dense: true,
                        title: Text(AutoDeletePreference.label(i)),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submit,
                  child: const Text('Save bookmark'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final date =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$date at $time';
  }
}
