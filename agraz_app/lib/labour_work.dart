import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'auth_token.dart';
import 'feedback_fab.dart';
import 'labor_categories.dart';
import 'l10n/app_l10n.dart';
import 'login.dart';

class LabourWorkPage extends StatefulWidget {
  const LabourWorkPage({super.key});

  @override
  State<LabourWorkPage> createState() => _LabourWorkPageState();
}

class _LabourWorkPageState extends State<LabourWorkPage>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _nameCtrl = TextEditingController();
  final _daysHourCtrl = TextEditingController(text: '1');
  final _rateCtrl = TextEditingController();
  final _narrationCtrl = TextEditingController();
  final _dateFmt = DateFormat('yyyy-MM-dd');

  late TabController _tabs;
  DateTime _date = DateTime.now();
  String _category = kLaborWorkCategories.first;
  String _shift = 'fullday';
  String _gender = 'Male';
  bool _saving = false;

  final _shifts = const ['fullday', 'morning', 'evening', 'night'];
  final _genders = const ['Male', 'Female'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _applyShiftDefaultDays(_shift);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    _daysHourCtrl.dispose();
    _rateCtrl.dispose();
    _narrationCtrl.dispose();
    super.dispose();
  }

  void _applyShiftDefaultDays(String shift) {
    final v = switch (shift) {
      'morning' || 'evening' => '0.5',
      'night' || 'fullday' => '1',
      _ => '1',
    };
    _daysHourCtrl.text = v;
  }

  Future<bool> _ensureLogin() async {
    var token = await getAuthToken();
    if (token != null && token.isNotEmpty) return true;
    if (!mounted) return false;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    return ok == true;
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

  String get _entryKind => _tabs.index == 0 ? 'receivable' : 'receipt';

  Future<void> _save() async {
    if (!await _ensureLogin()) return;
    final name = _nameCtrl.text.trim();
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;
    final hours = double.tryParse(_daysHourCtrl.text.trim()) ?? 0;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Name is required'))),
      );
      return;
    }
    if (rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Rate must be greater than zero'))),
      );
      return;
    }
    if (_entryKind == 'receivable' && hours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Days/hour must be greater than zero'))),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = {
        'name': name,
        'wage': rate,
        'hours': _entryKind == 'receipt' && hours <= 0 ? 1.0 : hours,
        'shift': _shift,
        'category': _entryKind == 'receipt' ? 'Receipt' : _category,
        'gender': _gender,
        'narration': _narrationCtrl.text.trim(),
        'entry_kind': _entryKind,
        'date': _dateFmt.format(_date),
        'work_type': 'Daily Wages',
        'location': 'Farm',
        'number_of_labours': 1,
      };
      final res = await _api.createLaborWork(payload);
      if (!mounted) return;
      if (res['success'] == true) {
        _nameCtrl.clear();
        _rateCtrl.clear();
        _narrationCtrl.clear();
        _applyShiftDefaultDays(_shift);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${res['message'] ?? tr('Saved')}'),
            backgroundColor: AppColors.income,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${res['message'] ?? tr('Failed')}'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.expense,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openReports() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LabourWorkReportsPage()),
    );
  }

  Widget _buildForm() {
    final isReceipt = _tabs.index == 1;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(
                  icon: isReceipt
                      ? Icons.payments_rounded
                      : Icons.work_history_rounded,
                  title: isReceipt ? tr('Receipt') : tr('Work Entry'),
                  subtitle: isReceipt
                      ? tr('Money received')
                      : tr('Receivable work'),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: tr('Date'),
                      prefixIcon:
                          const Icon(Icons.calendar_today_rounded, size: 20),
                    ),
                    child: Text(_dateFmt.format(_date)),
                  ),
                ),
                const SizedBox(height: 12),
                AppField(
                  controller: _nameCtrl,
                  label: tr('Name'),
                  icon: Icons.person_rounded,
                  required: true,
                ),
                if (!isReceipt) ...[
                  const SizedBox(height: 12),
                  AppDropdown(
                    label: tr('Category'),
                    value: _category,
                    items: kLaborWorkCategories,
                    icon: Icons.category_rounded,
                    onChanged: (v) {
                      if (v != null) setState(() => _category = v);
                    },
                    required: true,
                  ),
                  const SizedBox(height: 12),
                  AppDropdown(
                    label: tr('Shift'),
                    value: _shift,
                    items: _shifts,
                    icon: Icons.schedule_rounded,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _shift = v;
                        _applyShiftDefaultDays(v);
                      });
                    },
                    required: true,
                  ),
                  const SizedBox(height: 12),
                  AppField(
                    controller: _daysHourCtrl,
                    label: tr('Days / Hour'),
                    icon: Icons.timelapse_rounded,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    required: true,
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  AppField(
                    controller: _daysHourCtrl,
                    label: tr('Days / Hour'),
                    icon: Icons.timelapse_rounded,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    hint: '1',
                  ),
                ],
                const SizedBox(height: 12),
                AppField(
                  controller: _rateCtrl,
                  label: tr('Rate'),
                  icon: Icons.currency_rupee_rounded,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  required: true,
                ),
                const SizedBox(height: 12),
                AppDropdown(
                  label: tr('Gender'),
                  value: _gender,
                  items: _genders,
                  icon: Icons.wc_rounded,
                  onChanged: (v) {
                    if (v != null) setState(() => _gender = v);
                  },
                ),
                const SizedBox(height: 12),
                AppField(
                  controller: _narrationCtrl,
                  label: tr('Narration'),
                  icon: Icons.notes_rounded,
                  minLines: 3,
                  maxLines: 5,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: tr('Save'),
            icon: Icons.save_rounded,
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _openReports,
            icon: const Icon(Icons.insights_rounded),
            label: Text(tr('History / Reports')),
          ),
        ],
      ),
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
              title: tr('Labour Work'),
              subtitle: tr('Receivable & receipts'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: withFeedbackAction(
                  context,
                  menu: 'labour_work',
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.insights_rounded, color: Colors.white),
                      tooltip: tr('Reports'),
                      onPressed: _openReports,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              color: AppColors.surface,
              child: TabBar(
                controller: _tabs,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.primary,
                onTap: (_) => setState(() {}),
                tabs: [
                  Tab(text: tr('Work Entry')),
                  Tab(text: tr('Receipt')),
                ],
              ),
            ),
            Expanded(child: _buildForm()),
          ],
        ),
      ),
    );
  }
}

class LabourWorkReportsPage extends StatefulWidget {
  const LabourWorkReportsPage({super.key});

  @override
  State<LabourWorkReportsPage> createState() => _LabourWorkReportsPageState();
}

class _LabourWorkReportsPageState extends State<LabourWorkReportsPage> {
  final _api = ApiService();
  final _dateFmt = DateFormat('yyyy-MM-dd');
  final _searchCtrl = TextEditingController();

  DateTime? _from;
  DateTime? _to;
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _summary = {};
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

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final from = _from == null ? null : _dateFmt.format(_from!);
      final to = _to == null ? null : _dateFmt.format(_to!);
      final q = _searchCtrl.text.trim();
      final results = await Future.wait([
        _api.fetchLaborWorkReports(name: q.isEmpty ? null : q, from: from, to: to),
        _api.fetchLaborWorks(q: q.isEmpty ? null : q, from: from, to: to, limit: 100),
      ]);
      final report = results[0];
      final listRes = results[1];
      final list = (listRes['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _summary = Map<String, dynamic>.from(
          (report['summary'] as Map?) ?? {},
        );
        _rows = list;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.expense,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Delete Entry')),
        content: Text(tr('Delete this work entry?')),
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
    try {
      await _api.deleteLaborWork(id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.expense,
        ),
      );
    }
  }

  Widget _summaryBox(String label, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(label, style: AppText.caption),
          Text(
            value.toStringAsFixed(2),
            style: AppText.title.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final receivable = _asDouble(_summary['total_receivable']);
    final received = _asDouble(_summary['total_received']);
    final balance = _asDouble(_summary['balance']);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: tr('Work Reports'),
              subtitle: tr('Receivable · Received · Balance'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: withFeedbackAction(
                  context,
                  menu: 'labour_work_reports',
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
                              final p = await showDatePicker(
                                context: context,
                                initialDate: _from ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
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
                              final p = await showDatePicker(
                                context: context,
                                initialDate: _to ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
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
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _summaryBox(
                                  tr('Receivable'),
                                  receivable,
                                  AppColors.info,
                                  Icons.trending_up_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _summaryBox(
                                  tr('Received'),
                                  received,
                                  AppColors.income,
                                  Icons.payments_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _summaryBox(
                                  tr('Balance'),
                                  balance,
                                  AppColors.accent,
                                  Icons.account_balance_wallet_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (_rows.isEmpty)
                            Center(child: Text(tr('No entries')))
                          else
                            ..._rows.map((row) {
                              final id = _asInt(row['id']);
                              final wage = _asDouble(row['wage']);
                              final hours = _asDouble(row['hours']);
                              final total = wage * hours;
                              final kind = '${row['entry_kind'] ?? ''}';
                              final dateStr =
                                  '${row['date'] ?? ''}'.split('T').first;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: AppCard(
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      '${row['name'] ?? ''}',
                                      style: AppText.title,
                                    ),
                                    subtitle: Text(
                                      [
                                        dateStr,
                                        kind,
                                        if ('${row['category'] ?? ''}'.isNotEmpty)
                                          '${row['category']}',
                                        total.toStringAsFixed(2),
                                      ].join(' · '),
                                      style: AppText.small,
                                    ),
                                    trailing: id == null
                                        ? null
                                        : IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: AppColors.expense,
                                            ),
                                            onPressed: () => _delete(id),
                                          ),
                                  ),
                                ),
                              );
                            }),
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
