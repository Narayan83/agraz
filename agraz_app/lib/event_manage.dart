import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'auth_token.dart';
import 'event_alarms.dart';
import 'feedback_fab.dart';
import 'l10n/app_l10n.dart';
import 'login.dart';

const _recurrenceOptions = [
  ('yearly', 'Yearly'),
  ('monthly', 'Monthly'),
  ('weekly', 'Weekly'),
  ('daily', 'Daily'),
];

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse('$v');
}

String recurrenceLabel(String value) {
  switch (value) {
    case 'monthly':
      return tr('Monthly');
    case 'weekly':
      return tr('Weekly');
    case 'daily':
      return tr('Daily');
    default:
      return tr('Yearly');
  }
}

class EventManagePage extends StatefulWidget {
  const EventManagePage({super.key});

  @override
  State<EventManagePage> createState() => _EventManagePageState();
}

class _EventManagePageState extends State<EventManagePage> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (!await _ensureLogin()) {
      if (mounted) Navigator.pop(context);
      return;
    }
    await _load();
  }

  Future<bool> _ensureLogin() async {
    var token = await getAuthToken();
    if (token != null && token.isNotEmpty) return true;
    if (!mounted) return false;
    final loggedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (loggedIn != true) return false;
    token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _api.fetchManagedEvents();
      if (!mounted) return;
      setState(() {
        _events = rows;
        _loading = false;
      });
      await EventAlarms.instance.syncFromApi();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EventFormPage(existing: existing)),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final id = _asInt(row['id']);
    if (id == null) return;
    final name = '${row['name'] ?? ''}'.trim();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Delete event?')),
        content: Text(
          trf('Delete "{0}"? This cannot be undone.', [name.isEmpty ? tr('this event') : name]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteManagedEvent(id);
      await EventAlarms.instance.cancelEvent(id);
      if (mounted) await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _rowMenu(Map<String, dynamic> row) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(tr('Edit')),
              onTap: () {
                Navigator.pop(ctx);
                _openForm(existing: row);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.expense),
              title: Text(tr('Delete')),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(row);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientAppBar(
        title: tr('Event Manage'),
        actions: withFeedbackAction(
          context,
          menu: 'event_manage',
          actions: [
            IconButton(
              tooltip: tr('Refresh'),
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('Add event')),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: AppText.body),
              const SizedBox(height: 12),
              SecondaryButton(label: tr('Retry'), onPressed: _load),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            child: Text(
              tr(
                'Save birthdays, insurance renewals, and other reminders. The phone will ring an alarm at the notification time.',
              ),
              style: AppText.caption,
            ),
          ),
          if (_events.isEmpty)
            AppCard(
              child: Column(
                children: [
                  const Icon(Icons.event_available_rounded,
                      size: 42, color: AppColors.primary),
                  const SizedBox(height: 10),
                  Text(
                    tr('No events yet'),
                    style: AppText.bodyStrong,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr('Tap Add event to save a birthday or renewal reminder.'),
                    style: AppText.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ..._events.map(_eventTile),
        ],
      ),
    );
  }

  Widget _eventTile(Map<String, dynamic> row) {
    final name = '${row['name'] ?? ''}'.trim();
    final recurrence = '${row['recurrence'] ?? 'yearly'}'.toLowerCase();
    final eventDate = parseManagedEventDate(row['event_date']);
    final notify = parseNotifyTime(row['notify_time']);
    final next = nextOccurrence(eventDate, recurrence, notify);
    final dateLabel = DateFormat('d MMM yyyy').format(eventDate);
    final nextLabel = next == null
        ? ''
        : trf('Next: {0}', [DateFormat('d MMM, h:mm a').format(next)]);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      onTap: () => _openForm(existing: row),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.cake_outlined, color: AppColors.accent),
        ),
        title: Text(name.isEmpty ? tr('Untitled') : name, style: AppText.bodyStrong),
        subtitle: Text(
          [
            '$dateLabel · ${recurrenceLabel(recurrence)}',
            '${tr('Alarm')} ${formatNotifyTime(notify)}',
            if (nextLabel.isNotEmpty) nextLabel,
          ].join('\n'),
          style: AppText.caption,
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () => _rowMenu(row),
        ),
      ),
    );
  }
}

class EventFormPage extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const EventFormPage({super.key, this.existing});

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<EventFormPage> {
  final _api = ApiService();
  final _nameCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _dateFmt = DateFormat('yyyy-MM-dd');

  DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  String _recurrence = 'yearly';
  bool _saving = false;

  bool get _editing => _asInt(widget.existing?['id']) != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameCtrl.text = '${existing['name'] ?? ''}';
      _date = parseManagedEventDate(existing['event_date']);
      final t = parseNotifyTime(existing['notify_time']);
      _time = TimeOfDay(hour: t.hour, minute: t.minute);
      final rec = '${existing['recurrence'] ?? 'yearly'}'.toLowerCase();
      if (_recurrenceOptions.any((e) => e.$1 == rec)) _recurrence = rec;
    }
    _syncDateTimeFields();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  void _syncDateTimeFields() {
    _dateCtrl.text = _dateFmt.format(_date);
    _timeCtrl.text = formatNotifyTime((hour: _time.hour, minute: _time.minute));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _date = picked;
      _syncDateTimeFields();
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null) return;
    setState(() {
      _time = picked;
      _syncDateTimeFields();
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Event name is required'))),
      );
      return;
    }
    setState(() => _saving = true);
    final payload = {
      'name': name,
      'event_date': _dateFmt.format(_date),
      'recurrence': _recurrence,
      'notify_time': formatNotifyTime((hour: _time.hour, minute: _time.minute)),
    };
    try {
      Map<String, dynamic> saved;
      final id = _asInt(widget.existing?['id']);
      if (id != null) {
        saved = await _api.updateManagedEvent(id, payload);
      } else {
        saved = await _api.createManagedEvent(payload);
      }
      await EventAlarms.instance.scheduleEvent({...payload, ...saved});
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientAppBar(
        title: _editing ? tr('Edit event') : tr('Add event'),
        actions: withFeedbackAction(context, menu: 'event_manage'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppField(
                  controller: _nameCtrl,
                  label: tr('Event name'),
                  icon: Icons.event_note_rounded,
                  hint: tr('e.g. Ravi birthday, LIC renewal'),
                  required: true,
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _pickDate,
                  child: AbsorbPointer(
                    child: AppField(
                      controller: _dateCtrl,
                      label: tr('Date'),
                      icon: Icons.calendar_month_rounded,
                      required: true,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(tr('Occurring'), style: AppText.caption),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final opt in _recurrenceOptions)
                      ChoiceChip(
                        label: Text(tr(opt.$2)),
                        selected: _recurrence == opt.$1,
                        onSelected: (_) => setState(() => _recurrence = opt.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(_recurrenceHint(), style: AppText.caption),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _pickTime,
                  child: AbsorbPointer(
                    child: AppField(
                      controller: _timeCtrl,
                      label: tr('Notification time'),
                      icon: Icons.alarm_rounded,
                      required: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: _editing ? tr('Update') : tr('Save'),
            icon: Icons.save_rounded,
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  String _recurrenceHint() {
    switch (_recurrence) {
      case 'daily':
        return tr('Alarm every day at the notification time.');
      case 'weekly':
        return tr('Alarm on the same weekday every week.');
      case 'monthly':
        return tr('Alarm on the same date every month.');
      default:
        return tr('Alarm on this date every year. Use this for birthdays.');
    }
  }
}
