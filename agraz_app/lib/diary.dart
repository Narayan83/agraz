import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'auth_token.dart';
import 'feedback_fab.dart';
import 'l10n/app_l10n.dart';
import 'login.dart';

const Map<String, IconData> kDiaryIconMap = {
  'label': Icons.label_rounded,
  'money': Icons.attach_money_rounded,
  'calendar': Icons.calendar_month_rounded,
  'work': Icons.work_rounded,
  'note': Icons.note_rounded,
  'star': Icons.star_rounded,
  'home': Icons.home_rounded,
  'food': Icons.restaurant_rounded,
};

IconData diaryIconFor(String? name) =>
    kDiaryIconMap[name?.trim().toLowerCase() ?? ''] ?? Icons.label_rounded;

class DiaryPage extends StatefulWidget {
  const DiaryPage({super.key});

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  final _api = ApiService();
  final _contentCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _numDaysCtrl = TextEditingController();
  final _dateFmt = DateFormat('yyyy-MM-dd');

  DateTime _date = DateTime.now();
  List<Map<String, dynamic>> _labels = [];
  int? _selectedLabelId;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _amountCtrl.dispose();
    _numDaysCtrl.dispose();
    super.dispose();
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse('$v');
  }

  Future<bool> _ensureLogin({bool force = false}) async {
    if (!force) {
      final token = await getAuthToken();
      if (token != null && token.isNotEmpty) return true;
    } else {
      await clearAuthToken();
    }
    if (!mounted) return false;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    return ok == true;
  }

  bool _isAuthFailure(Map<String, dynamic> result) {
    final code = result['statusCode'];
    if (code == 401) return true;
    final msg = (result['message']?.toString() ?? '').toLowerCase();
    return msg.contains('jwt') ||
        msg.contains('unauthorized') ||
        msg.contains('login required') ||
        msg.contains('missing or malformed');
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.expense : AppColors.income,
      ),
    );
  }

  Future<void> _bootstrap() async {
    if (!await _ensureLogin()) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    var result = await _api.fetchDiaryLabels();
    if (!mounted) return;
    if (result['success'] != true && _isAuthFailure(result)) {
      final ok = await _ensureLogin(force: true);
      if (ok == true && mounted) {
        result = await _api.fetchDiaryLabels();
      }
    }
    if (!mounted) return;
    if (result['success'] == true) {
      final labels = (result['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        _labels = labels;
        if (_selectedLabelId != null &&
            !_labels.any((l) => _asInt(l['id']) == _selectedLabelId)) {
          _selectedLabelId = null;
        }
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      _snack(
        result['message']?.toString() ?? tr('Failed to load diary labels'),
        error: true,
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      _snack(tr('Content is required'), error: true);
      return;
    }
    if (!await _ensureLogin()) return;

    setState(() => _saving = true);
    final amount = double.tryParse(_amountCtrl.text.trim());
    final numDays = double.tryParse(_numDaysCtrl.text.trim());
    final payload = <String, dynamic>{
      'content': content,
      'date': _dateFmt.format(_date),
      if (_selectedLabelId != null) 'label_id': _selectedLabelId,
      if (amount != null) 'amount': amount,
      if (numDays != null) 'num_days': numDays,
    };

    var result = await _api.createDiaryEntry(payload);
    if (!mounted) return;
    if (result['success'] != true && _isAuthFailure(result)) {
      final ok = await _ensureLogin(force: true);
      if (ok == true && mounted) {
        result = await _api.createDiaryEntry(payload);
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);

    if (result['success'] != true) {
      _snack(
        result['message']?.toString() ?? tr('Failed to save diary entry'),
        error: true,
      );
      return;
    }

    _contentCtrl.clear();
    _amountCtrl.clear();
    _numDaysCtrl.clear();
    _snack(tr('Diary entry saved'));
  }

  Future<void> _manageLabels() async {
    if (!await _ensureLogin()) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ManageLabelsDialog(
        api: _api,
        labels: List<Map<String, dynamic>>.from(_labels),
        onChanged: (labels) {
          setState(() => _labels = labels);
        },
        ensureLogin: () => _ensureLogin(force: true),
        isAuthFailure: _isAuthFailure,
      ),
    );
    await _bootstrap();
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DiaryHistoryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: tr('Diary'),
              subtitle: tr('Notes & daily log'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: withFeedbackAction(
                  context,
                  menu: 'diary',
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.history_rounded, color: Colors.white),
                      tooltip: tr('History'),
                      onPressed: _openHistory,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SectionTitle(
                                  icon: Icons.edit_note_rounded,
                                  title: tr('New Entry'),
                                  subtitle: tr('Date, content & label'),
                                ),
                                const SizedBox(height: 14),
                                InkWell(
                                  onTap: _pickDate,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: tr('Date'),
                                      prefixIcon: const Icon(
                                        Icons.calendar_today_rounded,
                                        size: 20,
                                      ),
                                    ),
                                    child: Text(_dateFmt.format(_date)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                AppField(
                                  controller: _contentCtrl,
                                  label: tr('Content'),
                                  icon: Icons.notes_rounded,
                                  minLines: 4,
                                  maxLines: 8,
                                  required: true,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppField(
                                        controller: _amountCtrl,
                                        label: tr('Amount'),
                                        icon: Icons.currency_rupee_rounded,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[0-9.]'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: AppField(
                                        controller: _numDaysCtrl,
                                        label: tr('Num days'),
                                        icon: Icons.timelapse_rounded,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[0-9.]'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(tr('Label'), style: AppText.label),
                                const SizedBox(height: 8),
                                if (_labels.isEmpty)
                                  Text(
                                    tr('No labels yet — manage labels to add some'),
                                    style: AppText.small,
                                  )
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _labels.map((l) {
                                      final id = _asInt(l['id']);
                                      final selected = id == _selectedLabelId;
                                      final icon = diaryIconFor('${l['icon']}');
                                      return FilterChip(
                                        selected: selected,
                                        avatar: Icon(icon, size: 16),
                                        label: Text('${l['name'] ?? ''}'),
                                        onSelected: (_) {
                                          setState(() {
                                            _selectedLabelId =
                                                selected ? null : id;
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          PrimaryButton(
                            label: tr('Save entry'),
                            icon: Icons.save_rounded,
                            loading: _saving,
                            onPressed: _saving ? null : _save,
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _manageLabels,
                            icon: const Icon(Icons.label_outline_rounded),
                            label: Text(tr('Manage Labels')),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _openHistory,
                            icon: const Icon(Icons.history_rounded),
                            label: Text(tr('History')),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageLabelsDialog extends StatefulWidget {
  final ApiService api;
  final List<Map<String, dynamic>> labels;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  final Future<bool> Function() ensureLogin;
  final bool Function(Map<String, dynamic>) isAuthFailure;

  const _ManageLabelsDialog({
    required this.api,
    required this.labels,
    required this.onChanged,
    required this.ensureLogin,
    required this.isAuthFailure,
  });

  @override
  State<_ManageLabelsDialog> createState() => _ManageLabelsDialogState();
}

class _ManageLabelsDialogState extends State<_ManageLabelsDialog> {
  late List<Map<String, dynamic>> _labels;
  final _nameCtrl = TextEditingController();
  String _icon = 'label';
  int? _editingId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _labels = List<Map<String, dynamic>>.from(widget.labels);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse('$v');
  }

  void _startEdit(Map<String, dynamic> row) {
    setState(() {
      _editingId = _asInt(row['id']);
      _nameCtrl.text = '${row['name'] ?? ''}';
      _icon = '${row['icon'] ?? 'label'}';
      if (!kDiaryIconMap.containsKey(_icon)) _icon = 'label';
    });
  }

  void _resetForm() {
    _editingId = null;
    _nameCtrl.clear();
    _icon = 'label';
  }

  Future<List<Map<String, dynamic>>> _reloadLabels() async {
    var result = await widget.api.fetchDiaryLabels();
    if (result['success'] != true && widget.isAuthFailure(result)) {
      final ok = await widget.ensureLogin();
      if (ok) result = await widget.api.fetchDiaryLabels();
    }
    if (result['success'] == true) {
      return (result['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    throw Exception(result['message']?.toString() ?? 'Failed to load labels');
  }

  Future<void> _saveLabel() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    try {
      Map<String, dynamic> result;
      if (_editingId != null) {
        result = await widget.api
            .updateDiaryLabel(_editingId!, name: name, icon: _icon);
      } else {
        result = await widget.api.createDiaryLabel(name: name, icon: _icon);
      }
      if (result['success'] != true && widget.isAuthFailure(result)) {
        final ok = await widget.ensureLogin();
        if (ok) {
          if (_editingId != null) {
            result = await widget.api
                .updateDiaryLabel(_editingId!, name: name, icon: _icon);
          } else {
            result = await widget.api.createDiaryLabel(name: name, icon: _icon);
          }
        }
      }
      if (result['success'] != true) {
        throw Exception(result['message']?.toString() ?? 'Save failed');
      }
      final labels = await _reloadLabels();
      if (!mounted) return;
      setState(() {
        _labels = labels;
        _resetForm();
      });
      widget.onChanged(labels);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.expense,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteLabel(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Delete Label')),
        content: Text(tr('Delete this label?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(d, true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      var result = await widget.api.deleteDiaryLabel(id);
      if (result['success'] != true && widget.isAuthFailure(result)) {
        final ok = await widget.ensureLogin();
        if (ok) result = await widget.api.deleteDiaryLabel(id);
      }
      if (result['success'] != true) {
        throw Exception(result['message']?.toString() ?? 'Delete failed');
      }
      final labels = await _reloadLabels();
      if (!mounted) return;
      setState(() {
        _labels = labels;
        if (_editingId == id) _resetForm();
      });
      widget.onChanged(labels);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.expense,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('Manage Labels')),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._labels.map((l) {
                final id = _asInt(l['id']);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(diaryIconFor('${l['icon']}')),
                  title: Text('${l['name'] ?? ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 20),
                        onPressed: () => _startEdit(l),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.expense,
                          size: 20,
                        ),
                        onPressed: id == null ? null : () => _deleteLabel(id),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(labelText: tr('Name')),
              ),
              const SizedBox(height: 10),
              Text(tr('Icon'), style: AppText.label),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: kDiaryIconMap.entries.map((e) {
                  final selected = _icon == e.key;
                  return ChoiceChip(
                    selected: selected,
                    avatar: Icon(e.value, size: 16),
                    label: Text(e.key),
                    onSelected: (_) => setState(() => _icon = e.key),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Close')),
        ),
        FilledButton(
          onPressed: _busy ? null : _saveLabel,
          child: Text(_editingId != null ? tr('Update') : tr('Add')),
        ),
      ],
    );
  }
}

class DiaryHistoryPage extends StatefulWidget {
  const DiaryHistoryPage({super.key});

  @override
  State<DiaryHistoryPage> createState() => _DiaryHistoryPageState();
}

class _DiaryHistoryPageState extends State<DiaryHistoryPage> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  final _dateFmt = DateFormat('yyyy-MM-dd');

  DateTime? _from;
  DateTime? _to;
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse('$v');
  }

  Future<bool> _ensureLogin({bool force = false}) async {
    if (!force) {
      final token = await getAuthToken();
      if (token != null && token.isNotEmpty) return true;
    } else {
      await clearAuthToken();
    }
    if (!mounted) return false;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    return ok == true;
  }

  bool _isAuthFailure(Map<String, dynamic> result) {
    final code = result['statusCode'];
    if (code == 401) return true;
    final msg = (result['message']?.toString() ?? '').toLowerCase();
    return msg.contains('jwt') ||
        msg.contains('unauthorized') ||
        msg.contains('login required') ||
        msg.contains('missing or malformed');
  }

  Future<void> _load() async {
    if (!await _ensureLogin()) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    var res = await _api.fetchDiaryEntries(
      from: _from == null ? null : _dateFmt.format(_from!),
      to: _to == null ? null : _dateFmt.format(_to!),
      q: _searchCtrl.text.trim(),
    );
    if (!mounted) return;
    if (res['success'] != true && _isAuthFailure(res)) {
      final ok = await _ensureLogin(force: true);
      if (ok && mounted) {
        res = await _api.fetchDiaryEntries(
          from: _from == null ? null : _dateFmt.format(_from!),
          to: _to == null ? null : _dateFmt.format(_to!),
          q: _searchCtrl.text.trim(),
        );
      }
    }
    if (!mounted) return;
    if (res['success'] == true) {
      final list = (res['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        _entries = list;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message']?.toString() ?? tr('Failed to load diary entries'),
          ),
          backgroundColor: AppColors.expense,
        ),
      );
    }
  }

  Future<DateTime?> _pick(DateTime? current) {
    return showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
  }

  Future<void> _editEntry(Map<String, dynamic> row) async {
    final id = _asInt(row['id']);
    if (id == null) return;
    final contentCtrl =
        TextEditingController(text: '${row['content'] ?? ''}');
    final amountCtrl = TextEditingController(
      text: row['amount'] == null ? '' : '${row['amount']}',
    );
    final daysCtrl = TextEditingController(
      text: row['num_days'] == null ? '' : '${row['num_days']}',
    );
    DateTime date = DateTime.tryParse('${row['date']}') ?? DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setLocal) => AlertDialog(
          title: Text(tr('Edit Entry')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    final p = await showDatePicker(
                      context: d,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (p != null) setLocal(() => date = p);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: tr('Date')),
                    child: Text(_dateFmt.format(date)),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contentCtrl,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(labelText: tr('Content')),
                ),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: tr('Amount')),
                ),
                TextField(
                  controller: daysCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: tr('Num days')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(tr('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text(tr('Save')),
            ),
          ],
        ),
      ),
    );
    final content = contentCtrl.text.trim();
    final amount = double.tryParse(amountCtrl.text.trim());
    final numDays = double.tryParse(daysCtrl.text.trim());
    contentCtrl.dispose();
    amountCtrl.dispose();
    daysCtrl.dispose();
    if (ok != true || content.isEmpty) return;
    final payload = <String, dynamic>{
      'content': content,
      'date': _dateFmt.format(date),
      if (amount != null) 'amount': amount,
      if (numDays != null) 'num_days': numDays,
      if (row['label_id'] != null) 'label_id': row['label_id'],
    };
    var result = await _api.updateDiaryEntry(id, payload);
    if (result['success'] != true && _isAuthFailure(result)) {
      final loggedIn = await _ensureLogin(force: true);
      if (loggedIn) result = await _api.updateDiaryEntry(id, payload);
    }
    if (!mounted) return;
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? tr('Failed to update entry'),
          ),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }
    await _load();
  }

  Future<void> _deleteEntry(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Delete Entry')),
        content: Text(tr('Delete this diary entry?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(d, true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    var result = await _api.deleteDiaryEntry(id);
    if (result['success'] != true && _isAuthFailure(result)) {
      final loggedIn = await _ensureLogin(force: true);
      if (loggedIn) result = await _api.deleteDiaryEntry(id);
    }
    if (!mounted) return;
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? tr('Failed to delete entry'),
          ),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: tr('Diary History'),
              subtitle: tr('Search & manage entries'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: withFeedbackAction(
                  context,
                  menu: 'diary_history',
                  actions: const [],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final p = await _pick(_from);
                              if (p != null) setState(() => _from = p);
                            },
                            child: Text(
                              _from == null
                                  ? tr('From')
                                  : _dateFmt.format(_from!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final p = await _pick(_to);
                              if (p != null) setState(() => _to = p);
                            },
                            child: Text(
                              _to == null ? tr('To') : _dateFmt.format(_to!),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        labelText: tr('Search'),
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.filter_alt_rounded),
                          onPressed: _load,
                        ),
                      ),
                      onSubmitted: (_) => _load(),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _entries.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 80),
                                Center(child: Text(tr('No entries'))),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                              itemCount: _entries.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final row = _entries[i];
                                final id = _asInt(row['id']);
                                final label = row['label'];
                                final iconName = label is Map
                                    ? '${label['icon'] ?? 'label'}'
                                    : 'label';
                                final labelName = label is Map
                                    ? '${label['name'] ?? ''}'
                                    : '';
                                final dateStr = '${row['date'] ?? ''}'
                                    .split('T')
                                    .first;
                                return AppCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(diaryIconFor(iconName),
                                              color: AppColors.primary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              dateStr,
                                              style: AppText.title,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_rounded),
                                            onPressed: () => _editEntry(row),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: AppColors.expense,
                                            ),
                                            onPressed: id == null
                                                ? null
                                                : () => _deleteEntry(id),
                                          ),
                                        ],
                                      ),
                                      if (labelName.isNotEmpty)
                                        Text(labelName, style: AppText.caption),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${row['content'] ?? ''}',
                                        style: AppText.body,
                                      ),
                                      if (row['amount'] != null ||
                                          row['num_days'] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(
                                            [
                                              if (row['amount'] != null)
                                                '${tr('Amount')}: ${row['amount']}',
                                              if (row['num_days'] != null)
                                                '${tr('Days')}: ${row['num_days']}',
                                            ].join(' · '),
                                            style: AppText.small,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
