import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'auth_token.dart';
import 'feedback_fab.dart';
import 'l10n/app_l10n.dart';
import 'login.dart';

const List<String> kFuturePlanStatuses = [
  'planned',
  'in_progress',
  'completed',
  'cancelled',
];

class FuturePlansPage extends StatefulWidget {
  const FuturePlansPage({super.key});

  @override
  State<FuturePlansPage> createState() => _FuturePlansPageState();
}

class _FuturePlansPageState extends State<FuturePlansPage> {
  final _api = ApiService();
  final _nameCtrl = TextEditingController();
  final _lineCountCtrl = TextEditingController(text: '1');
  final _dateFmt = DateFormat('yyyy-MM-dd');

  DateTime _entryDate = DateTime.now();
  late int _year;
  int _month = 0; // 0 = All
  List<_PlanLineCtrls> _lines = [_PlanLineCtrls()];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _year = _entryDate.year;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lineCountCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
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

  void _syncLineCount(int count) {
    if (count < 1) count = 1;
    if (count > 30) count = 30;
    setState(() {
      while (_lines.length < count) {
        _lines.add(_PlanLineCtrls());
      }
      while (_lines.length > count) {
        _lines.removeLast().dispose();
      }
      _lineCountCtrl.text = '$count';
    });
  }

  Future<void> _pickEntryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _entryDate = picked;
        _year = picked.year;
      });
    }
  }

  Future<void> _submit() async {
    if (!await _ensureLogin()) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Plan name is required'))),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final lines = _lines
          .map((l) => {
                'description': l.desc.text.trim(),
                'estimate_cost':
                    double.tryParse(l.cost.text.trim()) ?? 0.0,
              })
          .toList();
      await _api.createFuturePlan({
        'plan_name': name,
        'entry_date': _dateFmt.format(_entryDate),
        'plan_year': _year,
        'plan_month': _month,
        'line_count': lines.length,
        'status': 'planned',
        'lines': lines,
      });
      if (!mounted) return;
      _nameCtrl.clear();
      for (final l in _lines) {
        l.desc.clear();
        l.cost.clear();
      }
      _syncLineCount(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Plan created')),
          backgroundColor: AppColors.income,
        ),
      );
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

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FuturePlansHistoryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final years = List.generate(11, (i) => DateTime.now().year - 2 + i);
    final months = [
      tr('All'),
      ...List.generate(12, (i) => DateFormat.MMMM().format(DateTime(2000, i + 1))),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: tr('Future Plans'),
              subtitle: tr('Plan work & estimates'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: withFeedbackAction(
                  context,
                  menu: 'future_plans',
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionTitle(
                            icon: Icons.flag_rounded,
                            title: tr('New Plan'),
                            subtitle: tr('Entry details & line estimates'),
                          ),
                          const SizedBox(height: 14),
                          InkWell(
                            onTap: _pickEntryDate,
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: tr('Entry date'),
                                prefixIcon: const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 20,
                                ),
                              ),
                              child: Text(_dateFmt.format(_entryDate)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          AppField(
                            controller: _nameCtrl,
                            label: tr('Plan name'),
                            icon: Icons.title_rounded,
                            required: true,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _year,
                                  decoration: InputDecoration(
                                    labelText: tr('Year'),
                                    prefixIcon: const Icon(Icons.event_rounded),
                                  ),
                                  items: years
                                      .map((y) => DropdownMenuItem(
                                            value: y,
                                            child: Text('$y'),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => _year = v);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _month,
                                  decoration: InputDecoration(
                                    labelText: tr('Month'),
                                    prefixIcon:
                                        const Icon(Icons.calendar_view_month),
                                  ),
                                  items: List.generate(
                                    13,
                                    (i) => DropdownMenuItem(
                                      value: i,
                                      child: Text(months[i]),
                                    ),
                                  ),
                                  onChanged: (v) {
                                    if (v != null) setState(() => _month = v);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          AppField(
                            controller: _lineCountCtrl,
                            label: tr('Number of lines'),
                            icon: Icons.format_list_numbered_rounded,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (v) {
                              final n = int.tryParse(v.trim());
                              if (n != null) _syncLineCount(n);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(_lines.length, (i) {
                      final line = _lines[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SectionTitle(
                                icon: Icons.playlist_add_check_rounded,
                                title: '${tr('Line')} ${i + 1}',
                              ),
                              const SizedBox(height: 12),
                              AppField(
                                controller: line.desc,
                                label: tr('Description'),
                                icon: Icons.description_outlined,
                                minLines: 2,
                                maxLines: 4,
                              ),
                              const SizedBox(height: 10),
                              AppField(
                                controller: line.cost,
                                label: tr('Estimate cost'),
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
                            ],
                          ),
                        ),
                      );
                    }),
                    PrimaryButton(
                      label: tr('Create plan'),
                      icon: Icons.save_rounded,
                      loading: _saving,
                      onPressed: _saving ? null : _submit,
                    ),
                    const SizedBox(height: 10),
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

class _PlanLineCtrls {
  final desc = TextEditingController();
  final cost = TextEditingController();

  void dispose() {
    desc.dispose();
    cost.dispose();
  }
}

class FuturePlansHistoryPage extends StatefulWidget {
  const FuturePlansHistoryPage({super.key});

  @override
  State<FuturePlansHistoryPage> createState() => _FuturePlansHistoryPageState();
}

class _FuturePlansHistoryPageState extends State<FuturePlansHistoryPage> {
  final _api = ApiService();
  final _dateFmt = DateFormat('yyyy-MM-dd');
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
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
      final rows = await _api.fetchFuturePlans();
      if (!mounted) return;
      setState(() => _plans = rows);
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

  Future<void> _openDetail(Map<String, dynamic> plan) async {
    final id = _asInt(plan['id']);
    if (id == null) return;
    Map<String, dynamic> full = plan;
    try {
      full = await _api.fetchFuturePlan(id);
    } catch (_) {}
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _PlanDetailDialog(
        api: _api,
        plan: full,
        dateFmt: _dateFmt,
        onSaved: _load,
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
              title: tr('Plans History'),
              subtitle: tr('Tap a plan to update'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: withFeedbackAction(
                  context,
                  menu: 'future_plans_history',
                  actions: const [],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _plans.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 80),
                                Center(child: Text(tr('No plans'))),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                              itemCount: _plans.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final p = _plans[i];
                                final lines = (p['lines'] as List? ?? []);
                                final estimate = lines.fold<double>(0, (s, e) {
                                  if (e is Map) {
                                    return s + _asDouble(e['estimate_cost']);
                                  }
                                  return s;
                                });
                                final entry =
                                    '${p['entry_date'] ?? ''}'.split('T').first;
                                return AppCard(
                                  onTap: () => _openDetail(p),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${p['plan_name'] ?? ''}',
                                        style: AppText.title,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          entry,
                                          '${p['plan_year'] ?? ''}',
                                          if ((p['plan_month'] ?? 0) != 0)
                                            'M${p['plan_month']}',
                                          '${p['status'] ?? ''}',
                                        ].join(' · '),
                                        style: AppText.small,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${tr('Lines')}: ${p['line_count'] ?? lines.length}'
                                        ' · ${tr('Estimate')}: ${estimate.toStringAsFixed(2)}',
                                        style: AppText.bodyStrong,
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

class _PlanDetailDialog extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic> plan;
  final DateFormat dateFmt;
  final VoidCallback onSaved;

  const _PlanDetailDialog({
    required this.api,
    required this.plan,
    required this.dateFmt,
    required this.onSaved,
  });

  @override
  State<_PlanDetailDialog> createState() => _PlanDetailDialogState();
}

class _PlanDetailDialogState extends State<_PlanDetailDialog> {
  late String _status;
  late TextEditingController _actualCtrl;
  late List<_PlanLineCtrls> _lines;
  DateTime? _endDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = '${widget.plan['status'] ?? 'planned'}';
    if (!kFuturePlanStatuses.contains(_status)) _status = 'planned';
    final actual = widget.plan['actual_cost'];
    _actualCtrl = TextEditingController(
      text: actual == null ? '' : '$actual',
    );
    final end = widget.plan['end_date'];
    if (end != null) _endDate = DateTime.tryParse('$end');
    final rawLines = (widget.plan['lines'] as List? ?? []);
    _lines = rawLines.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final c = _PlanLineCtrls();
      c.desc.text = '${m['description'] ?? ''}';
      c.cost.text = '${m['estimate_cost'] ?? ''}';
      return c;
    }).toList();
    if (_lines.isEmpty) _lines = [_PlanLineCtrls()];
  }

  @override
  void dispose() {
    _actualCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse('$v');
  }

  Future<void> _save() async {
    final id = _asInt(widget.plan['id']);
    if (id == null) return;
    setState(() => _saving = true);
    try {
      final actual = double.tryParse(_actualCtrl.text.trim());
      await widget.api.updateFuturePlan(id, {
        'status': _status,
        if (_endDate != null) 'end_date': widget.dateFmt.format(_endDate!),
        if (actual != null) 'actual_cost': actual,
        'lines': _lines
            .map((l) => {
                  'description': l.desc.text.trim(),
                  'estimate_cost':
                      double.tryParse(l.cost.text.trim()) ?? 0.0,
                })
            .toList(),
      });
      if (!mounted) return;
      widget.onSaved();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Plan updated')),
          backgroundColor: AppColors.income,
        ),
      );
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

  Future<void> _delete() async {
    final id = _asInt(widget.plan['id']);
    if (id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tr('Delete Plan')),
        content: Text(tr('Delete this plan?')),
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
      await widget.api.deleteFuturePlan(id);
      if (!mounted) return;
      widget.onSaved();
      Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.plan['plan_name'] ?? tr('Plan')}'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: InputDecoration(labelText: tr('Status')),
                items: kFuturePlanStatuses
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _status = v);
                },
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (p != null) setState(() => _endDate = p);
                },
                child: InputDecorator(
                  decoration: InputDecoration(labelText: tr('End date')),
                  child: Text(
                    _endDate == null
                        ? tr('Optional')
                        : widget.dateFmt.format(_endDate!),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _actualCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: tr('Actual cost')),
              ),
              const SizedBox(height: 12),
              Text(tr('Lines'), style: AppText.label),
              const SizedBox(height: 6),
              ...List.generate(_lines.length, (i) {
                final line = _lines[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      TextField(
                        controller: line.desc,
                        decoration: InputDecoration(
                          labelText: '${tr('Description')} ${i + 1}',
                        ),
                      ),
                      TextField(
                        controller: line.cost,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: tr('Estimate cost'),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: () => setState(() => _lines.add(_PlanLineCtrls())),
                icon: const Icon(Icons.add),
                label: Text(tr('Add line')),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _delete,
          child: Text(
            tr('Delete'),
            style: const TextStyle(color: AppColors.expense),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Cancel')),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(tr('Save')),
        ),
      ],
    );
  }
}
