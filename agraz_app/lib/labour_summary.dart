import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'l10n/app_l10n.dart';

/// Searchable labourer directory + per-labour schedule summary.
class LabourSummaryPage extends StatefulWidget {
  const LabourSummaryPage({super.key});

  @override
  State<LabourSummaryPage> createState() => _LabourSummaryPageState();
}

class _LabourSummaryPageState extends State<LabourSummaryPage> {
  final ApiService _api = ApiService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _people = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _money(dynamic v) =>
      '₹${NumberFormat('#,##0').format(_num(v).round())}';

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    try {
      return DateFormat('d MMM yyyy').format(DateTime.parse(v.toString()));
    } catch (_) {
      return v.toString();
    }
  }

  Future<void> _load({String? q}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final people = await _api.fetchLaborPeople(q: q);
      if (!mounted) return;
      setState(() {
        _people = people;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _load(q: v.trim());
    });
  }

  void _openDetail(Map<String, dynamic> person) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LabourerDetailPage(
          name: person['name']?.toString() ?? '',
          mobile: person['mobile']?.toString(),
        ),
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
              icon: Icons.badge_rounded,
              title: tr('Labour Summary'),
              subtitle: tr('Search & schedule by labourer'),
              trailing: IconButton(
                tooltip: tr('Refresh'),
                onPressed: () => _load(q: _searchCtrl.text.trim()),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: tr('Search by name or mobile…'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            _load();
                            setState(() {});
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _loading
                      ? 'Loading…'
                      : '${_people.length} labourer${_people.length == 1 ? '' : 's'}',
                  style: AppText.caption,
                ),
              ),
            ),
            SizedBox(height: 6),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () =>
                                      _load(q: _searchCtrl.text.trim()),
                                  child: Text(tr('Retry')),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _people.isEmpty
                          ? AppCard(
                              margin: EdgeInsets.all(12),
                              child: EmptyState(
                                icon: Icons.person_search_rounded,
                                title: tr('No labourers found'),
                                subtitle:
                                    tr('Add labour entries first, then search here'),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () =>
                                  _load(q: _searchCtrl.text.trim()),
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  4,
                                  12,
                                  24,
                                ),
                                itemCount: _people.length,
                                separatorBuilder: (_, __) =>
                                    SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final p = _people[i];
                                  final name = p['name']?.toString() ?? '—';
                                  final mobile = p['mobile']?.toString();
                                  final gender = p['gender']?.toString() ?? '';
                                  return AppCard(
                                    onTap: () => _openDetail(p),
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: AppColors.primarySoft,
                                          child: Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                [
                                                  if (mobile != null &&
                                                      mobile.isNotEmpty)
                                                    mobile,
                                                  if (gender.isNotEmpty) gender,
                                                  '${p['entry_count'] ?? 0} entries',
                                                ].join(' · '),
                                                style: AppText.caption,
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Last: ${_fmtDate(p['last_date'])}'
                                                '${(p['last_category']?.toString().isNotEmpty ?? false) ? ' · ${p['last_category']}' : ''}',
                                                style: AppText.caption,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              _money(p['total_cost']),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              color: AppColors.textMuted,
                                            ),
                                          ],
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

/// Selected labourer: profile + monthly/weekly schedule + entries.
class LabourerDetailPage extends StatefulWidget {
  final String name;
  final String? mobile;

  const LabourerDetailPage({
    super.key,
    required this.name,
    this.mobile,
  });

  @override
  State<LabourerDetailPage> createState() => _LabourerDetailPageState();
}

class _LabourerDetailPageState extends State<LabourerDetailPage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabs;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _report;
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _rates = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String? get _mobile {
    final m = widget.mobile?.trim();
    if (m != null && m.isNotEmpty) return m;
    return null;
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _money(dynamic v) =>
      '₹${NumberFormat('#,##0').format(_num(v).round())}';

  String _hours(dynamic v) {
    final n = _num(v);
    return n == n.roundToDouble()
        ? n.toStringAsFixed(0)
        : n.toStringAsFixed(1);
  }

  List<Map<String, dynamic>> _list(String key) {
    final raw = _report?[key];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, dynamic> _map(String key) {
    final raw = _report?[key];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.fetchLaborReports(
          year: _selectedMonth.year,
          month: _selectedMonth.month,
          months: 6,
          mobile: _mobile,
          name: _mobile == null ? widget.name : null,
        ),
        _api.fetchLabors(
          mobile: _mobile,
          name: _mobile == null ? widget.name : null,
          limit: 50,
        ),
        if (_mobile != null) _api.fetchLaborRates(mobile: _mobile),
      ]);
      if (!mounted) return;
      setState(() {
        _report = results[0] as Map<String, dynamic>;
        _entries = results[1] as List<Map<String, dynamic>>;
        if (results.length > 2) {
          _rates = results[2] as List<Map<String, dynamic>>;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: 'Select month',
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _map('profile');
    final displayName =
        profile['name']?.toString().isNotEmpty == true
            ? profile['name'].toString()
            : widget.name;
    final displayMobile =
        profile['mobile']?.toString() ?? widget.mobile ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              icon: Icons.person_rounded,
              title: displayName,
              subtitle: displayMobile.isNotEmpty
                  ? displayMobile
                  : 'Labour schedule',
              trailing: IconButton(
                tooltip: tr('Refresh'),
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: InkWell(
                onTap: _pickMonth,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        DateFormat('MMMM yyyy').format(_selectedMonth),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.expand_more_rounded,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            TabBar(
              controller: _tabs,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              isScrollable: true,
              tabs: [
                Tab(text: tr('Overview')),
                Tab(text: tr('Monthly')),
                Tab(text: tr('Weekly')),
                Tab(text: tr('Entries')),
              ],
            ),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!),
                              TextButton(onPressed: _load, child: Text(tr('Retry'))),
                            ],
                          ),
                        )
                      : TabBarView(
                          controller: _tabs,
                          children: [
                            _buildOverview(profile),
                            _buildMonthly(),
                            _buildWeekly(),
                            _buildEntries(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(Map<String, dynamic> profile) {
    final monthSum = _map('month_summary');
    final allSum = _map('summary');
    final byCat = _list('by_category');
    final byShift = _list('by_shift');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile['name']?.toString() ?? widget.name,
                    style: AppText.h3),
                SizedBox(height: 6),
                if ((profile['mobile'] ?? widget.mobile)
                        ?.toString()
                        .isNotEmpty ==
                    true)
                  _kv('Mobile', (profile['mobile'] ?? widget.mobile).toString()),
                if ((profile['gender']?.toString() ?? '').isNotEmpty)
                  _kv('Gender', profile['gender'].toString()),
                if ((profile['last_work_type']?.toString() ?? '').isNotEmpty)
                  _kv('Work type', profile['last_work_type'].toString()),
                if ((profile['last_location']?.toString() ?? '').isNotEmpty)
                  _kv('Last location', profile['last_location'].toString()),
                if ((profile['last_category']?.toString() ?? '').isNotEmpty)
                  _kv('Last category', profile['last_category'].toString()),
              ],
            ),
          ),
          SizedBox(height: 12),
          Text(
            _report?['month_label']?.toString() ?? 'This month',
            style: AppText.h3,
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _stat(
                  'Cost',
                  _money(monthSum['total_cost']),
                  AppColors.primary,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _stat(
                  'Days/Hrs',
                  _hours(monthSum['total_hours']),
                  AppColors.info,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _stat(
                  'Entries',
                  '${monthSum['entry_count'] ?? 0}',
                  AppColors.accent,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('All-time', style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                _kv('Total cost', _money(allSum['total_cost'])),
                _kv('Total days/hrs', _hours(allSum['total_hours'])),
                _kv('Entries', '${allSum['entry_count'] ?? 0}'),
                _kv('Avg rate', _money(allSum['avg_rate'])),
              ],
            ),
          ),
          if (byCat.isNotEmpty) ...[
            SizedBox(height: 14),
            Text('Category this month', style: AppText.h3),
            SizedBox(height: 8),
            ...byCat.map((c) {
              final pct = _num(c['pct']).clamp(0, 100).toDouble();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c['category']?.toString() ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            _money(c['total_cost']),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          minHeight: 6,
                          backgroundColor: AppColors.primarySoft,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${_hours(c['total_hours'])} days/hrs · ${c['count'] ?? 0} entries · ${pct.toStringAsFixed(0)}%',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          if (byShift.isNotEmpty) ...[
            SizedBox(height: 8),
            Text('Shift this month', style: AppText.h3),
            SizedBox(height: 8),
            ...byShift.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s['shift']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(_money(s['total_cost'])),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (_rates.isNotEmpty) ...[
            SizedBox(height: 14),
            Text('Saved rates', style: AppText.h3),
            SizedBox(height: 8),
            AppCard(
              child: Column(
                children: _rates
                    .map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(r['category']?.toString() ?? '')),
                            Text(
                              _money(r['rate']),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthly() {
    final monthly = _list('monthly');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Text('Monthly schedule', style: AppText.h3),
          SizedBox(height: 4),
          Text('Cost & days by month for this labourer', style: AppText.caption),
          SizedBox(height: 12),
          if (monthly.isEmpty)
            AppCard(child: Text(tr('No monthly data')))
          else
            ...monthly.reversed.map((m) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            m['label']?.toString() ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _money(m['total_cost']),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        '${_hours(m['total_hours'])} days/hrs · ${m['count'] ?? 0} entries',
                        style: AppText.caption,
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

  Widget _buildWeekly() {
    final weekly = _list('weekly');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Text(
            'Weekly schedule · ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
            style: AppText.h3,
          ),
          SizedBox(height: 4),
          Text('Week-wise work for selected month', style: AppText.caption),
          SizedBox(height: 12),
          if (weekly.isEmpty)
            AppCard(child: Text(tr('No weekly data')))
          else
            ...weekly.map((w) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w['label']?.toString() ?? 'Week',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            _money(w['total_cost']),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_hours(w['total_hours'])} days/hrs · ${w['count'] ?? 0} entries',
                            style: AppText.caption,
                          ),
                        ],
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

  Widget _buildEntries() {
    return RefreshIndicator(
      onRefresh: _load,
      child: _entries.isEmpty
          ? ListView(
              children: [
                SizedBox(height: 40),
                Center(child: Text(tr('No entries for this labourer'))),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: _entries.length,
              separatorBuilder: (_, __) => SizedBox(height: 8),
              itemBuilder: (context, i) {
                final e = _entries[i];
                final wage = _num(e['wage']);
                final hours = _num(e['hours']);
                DateTime? date;
                try {
                  date = DateTime.parse(e['date'].toString());
                } catch (_) {}
                return AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              e['category']?.toString() ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            _money(wage * hours),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        [
                          if (date != null)
                            DateFormat('d MMM yyyy').format(date),
                          e['shift']?.toString() ?? '',
                          e['location']?.toString() ?? '',
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: AppText.caption,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Rate ${_money(wage)} × ${_hours(hours)} · ${e['work_type'] ?? ''}',
                        style: AppText.caption,
                      ),
                      if ((e['narration']?.toString() ?? '').isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          e['narration'].toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(label, style: AppText.caption),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(k, style: TextStyle(color: AppColors.textSecondary)),
          ),
          Text(v, style: TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Full labour entry history across all labourers — searchable, with an
/// alphabetical (by name) / newest-first (by date) sort toggle. Unlike the
/// entry page (which only shows the latest 5 entries), this page loads the
/// complete history.
class LaborHistoryPage extends StatefulWidget {
  const LaborHistoryPage({super.key});

  @override
  State<LaborHistoryPage> createState() => _LaborHistoryPageState();
}

class _LaborHistoryPageState extends State<LaborHistoryPage> {
  final ApiService _api = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  bool _sortByName = false;
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  void _sortEntries() {
    if (_sortByName) {
      _entries.sort((a, b) => (a['name']?.toString() ?? '')
          .toLowerCase()
          .compareTo((b['name']?.toString() ?? '').toLowerCase()));
    } else {
      _entries.sort((a, b) {
        final da =
            DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
        final db =
            DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });
    }
  }

  Future<void> _load({String? q}) async {
    setState(() => _loading = true);
    final rows = await _api.fetchLabors(q: q, limit: 300);
    if (!mounted) return;
    setState(() {
      _entries = rows;
      _sortEntries();
      _loading = false;
    });
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _load(q: v.trim()),
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
              icon: Icons.history_rounded,
              title: tr('History'),
              subtitle: tr('All labour entries'),
              trailing: IconButton(
                tooltip: _sortByName ? tr('Sort by date') : tr('Sort by name'),
                onPressed: () {
                  setState(() {
                    _sortByName = !_sortByName;
                    _sortEntries();
                  });
                },
                icon: Icon(
                  _sortByName
                      ? Icons.sort_by_alpha_rounded
                      : Icons.calendar_today_rounded,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: tr('Search by name, category, location…'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchCtrl.clear();
                            _load();
                            setState(() {});
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _loading
                      ? tr('Loading…')
                      : '${_entries.length} ${_entries.length == 1 ? tr('entry') : tr('entries')}',
                  style: AppText.caption,
                ),
              ),
            ),
            SizedBox(height: 6),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _entries.isEmpty
                      ? AppCard(
                          margin: const EdgeInsets.all(12),
                          child: EmptyState(
                            icon: Icons.history_rounded,
                            title: tr('No labour entries found'),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _load(q: _searchCtrl.text.trim()),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                            itemCount: _entries.length,
                            separatorBuilder: (_, __) => SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final e = _entries[i];
                              final wage = _num(e['wage']);
                              final hours = _num(e['hours']);
                              DateTime? date;
                              try {
                                date = DateTime.parse(e['date'].toString());
                              } catch (_) {}
                              return AppCard(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            e['name']?.toString() ?? '',
                                            style: AppText.bodyStrong,
                                          ),
                                        ),
                                        Text(
                                          '₹${(wage * hours).toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 5),
                                    Wrap(
                                      spacing: 5,
                                      runSpacing: 4,
                                      children: [
                                        if ((e['category']?.toString() ?? '')
                                            .isNotEmpty)
                                          InfoChip(
                                            label: e['category'].toString(),
                                            color: AppColors.expense,
                                          ),
                                        if ((e['shift']?.toString() ?? '')
                                            .isNotEmpty)
                                          InfoChip(
                                            label: e['shift'].toString(),
                                            color: AppColors.warning,
                                          ),
                                        if ((e['location']?.toString() ?? '')
                                            .isNotEmpty)
                                          InfoChip(
                                            label: e['location'].toString(),
                                            color: AppColors.textMuted,
                                          ),
                                      ],
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      [
                                        if (date != null)
                                          DateFormat('dd/MM/yyyy').format(date),
                                        '₹${wage.toStringAsFixed(0)} × ${hours.toStringAsFixed(hours == hours.roundToDouble() ? 0 : 1)}',
                                      ].join('  ·  '),
                                      style: AppText.caption,
                                    ),
                                    if ((e['narration']?.toString() ?? '')
                                        .isNotEmpty) ...[
                                      SizedBox(height: 4),
                                      Text(
                                        e['narration'].toString(),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
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
