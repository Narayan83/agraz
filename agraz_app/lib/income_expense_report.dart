import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'feedback_fab.dart';
import 'income_expense_view.dart';
import 'l10n/app_l10n.dart';

class IncomeExpenseReportPage extends StatefulWidget {
  const IncomeExpenseReportPage({super.key});

  @override
  State<IncomeExpenseReportPage> createState() =>
      _IncomeExpenseReportPageState();
}

class _IncomeExpenseReportPageState extends State<IncomeExpenseReportPage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabs;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _filterType = '';
  String _filterMobile = '';
  final _mobileCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  bool _overviewPie = true;
  bool _categoryPie = true;
  Map<String, dynamic>? _drillCategory;

  static const _chartColors = [
    Color(0xFF16A34A),
    Color(0xFF2E7CF6),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    Color(0xFFDB2777),
    Color(0xFF65A30D),
    Color(0xFFEA580C),
    Color(0xFF4F46E5),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  String _money(dynamic v) =>
      '₹${NumberFormat('#,##0').format(_num(v).round())}';

  String _pct(dynamic v) {
    final n = _num(v);
    final sign = n > 0 ? '+' : '';
    return '$sign${n.toStringAsFixed(1)}%';
  }

  List<Map<String, dynamic>> _list(dynamic key) {
    final raw = _data?[key];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, dynamic> _map(dynamic key) {
    final raw = _data?[key];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _drillCategory = null;
    });
    try {
      final data = await _api.fetchIncomeExpenseReports(
        year: _selectedMonth.year,
        month: _selectedMonth.month,
        months: 6,
        type: _filterType.isEmpty ? null : _filterType,
        mobile: _filterMobile.isEmpty ? null : _filterMobile,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
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

  void _showFilters() {
    _mobileCtrl.text = _filterMobile;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String localType = _filterType;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(tr('Report filters'), style: AppText.h3),
                  SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: localType.isEmpty ? '' : localType,
                    decoration: InputDecoration(
                      labelText: tr('Type'),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: '', child: Text(tr('All'))),
                      DropdownMenuItem(
                          value: 'Income', child: Text(tr('Income'))),
                      DropdownMenuItem(
                        value: 'Expense',
                        child: Text(tr('Expense')),
                      ),
                    ],
                    onChanged: (v) => setLocal(() => localType = v ?? ''),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _mobileCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: tr('Mobile (optional)'),
                      hintText: tr('e.g. 9999999999 for admin demo'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _filterType = '';
                              _filterMobile = '';
                              _mobileCtrl.clear();
                            });
                            Navigator.pop(ctx);
                            _load();
                          },
                          child: Text(tr('Clear')),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _filterType = localType;
                              _filterMobile = _mobileCtrl.text.trim();
                            });
                            Navigator.pop(ctx);
                            _load();
                          },
                          child: Text(tr('Apply')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
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
              title: tr('Financial Reports'),
              subtitle: tr('Income & Expense'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: withFeedbackAction(
                  context,
                  menu: 'income_expense_report',
                  actions: [
                    IconButton(
                      tooltip: tr('Filters'),
                      onPressed: _showFilters,
                      icon:
                          const Icon(Icons.tune_rounded, color: Colors.white),
                    ),
                    IconButton(
                      tooltip: tr('Refresh'),
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  Expanded(
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
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
                  if (_filterMobile.isNotEmpty || _filterType.isNotEmpty) ...[
                    SizedBox(width: 8),
                    Chip(
                      label: Text(
                        [
                          if (_filterType.isNotEmpty) _filterType,
                          if (_filterMobile.isNotEmpty) _filterMobile,
                        ].join(' · '),
                        style: const TextStyle(fontSize: 11),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () {
                        setState(() {
                          _filterType = '';
                          _filterMobile = '';
                        });
                        _load();
                      },
                    ),
                  ],
                ],
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
                Tab(text: tr('Category')),
              ],
            ),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _ErrorView(message: _error!, onRetry: _load)
                      : TabBarView(
                          controller: _tabs,
                          children: [
                            _buildOverview(),
                            _buildMonthly(),
                            _buildWeekly(),
                            _buildCategory(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chartToggle({
    required bool isPie,
    required ValueChanged<bool> onChanged,
  }) {
    return SegmentedButton<bool>(
      segments: [
        ButtonSegment(
          value: true,
          icon: Icon(Icons.pie_chart_rounded, size: 16),
          label: Text(tr('Pie')),
        ),
        ButtonSegment(
          value: false,
          icon: Icon(Icons.bar_chart_rounded, size: 16),
          label: Text(tr('Bar')),
        ),
      ],
      selected: {isPie},
      onSelectionChanged: (s) => onChanged(s.first),
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildOverview() {
    final overview = _map('overview');
    final allSum = overview.isNotEmpty ? overview : _map('summary');
    final monthSum = _map('month_summary');
    final trends = _map('trends');
    final monthly = _list('monthly');
    final rollupAll = _list('by_category_rollup_all');
    final rollup =
        rollupAll.isNotEmpty ? rollupAll : _list('by_category_rollup');
    final subAll = _list('by_sub_category_all');
    final subFallback =
        subAll.isNotEmpty ? subAll : _list('by_category_all');

    final drillSubs = _drillCategory == null
        ? <Map<String, dynamic>>[]
        : subFallback
            .where(
              (s) =>
                  s['type'] == _drillCategory!['type'] &&
                  s['category'] == _drillCategory!['category'],
            )
            .toList();

    final chartRows = _drillCategory == null ? rollup : drillSubs;
    final labelKey = _drillCategory == null ? 'category' : 'sub_category';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Text(tr('Overall summary'), style: AppText.h3),
          SizedBox(height: 4),
          Text(tr('All-time income & expense'), style: AppText.caption),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: tr('Income'),
                  value: _money(allSum['income']),
                  color: AppColors.income,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: tr('Expense'),
                  value: _money(allSum['expense']),
                  color: AppColors.expense,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          _StatTile(
            label: tr('Net balance'),
            value: _money(allSum['net']),
            color:
                _num(allSum['net']) >= 0 ? AppColors.income : AppColors.expense,
            icon: Icons.account_balance_wallet_rounded,
            wide: true,
          ),
          SizedBox(height: 8),
          AppCard(
            child: Column(
              children: [
                _kv(tr('Transactions'), '${allSum['total_count'] ?? 0}'),
                SizedBox(height: 6),
                _kv(
                  '${tr('This month')} (${_data?['month_label'] ?? DateFormat('MMMM yyyy').format(_selectedMonth)})',
                  _money(monthSum['net']),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  _drillCategory == null
                      ? tr('Category-wise')
                      : '${_drillCategory!['category']}',
                  style: AppText.h3,
                ),
              ),
              if (_drillCategory != null)
                TextButton.icon(
                  onPressed: () => setState(() => _drillCategory = null),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: Text(tr('Back')),
                ),
              _chartToggle(
                isPie: _overviewPie,
                onChanged: (v) => setState(() => _overviewPie = v),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            _drillCategory == null
                ? tr('Tap a category for subcategory breakdown')
                : tr('Subcategory breakdown'),
            style: AppText.caption,
          ),
          SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: SizedBox(
              height: 240,
              child: chartRows.isEmpty
                  ? Center(child: Text(tr('No category data')))
                  : _overviewPie
                      ? _CategoryPieChart(
                          rows: chartRows,
                          labelKey: labelKey,
                          numFn: _num,
                          colors: _chartColors,
                          onTap: _drillCategory == null
                              ? (row) => setState(() => _drillCategory = row)
                              : null,
                        )
                      : _CategoryBarChart(
                          rows: chartRows,
                          labelKey: labelKey,
                          numFn: _num,
                          colors: _chartColors,
                          onTap: _drillCategory == null
                              ? (row) => setState(() => _drillCategory = row)
                              : null,
                        ),
            ),
          ),
          SizedBox(height: 10),
          ...chartRows.map((r) {
            final label = _drillCategory == null
                ? '${r['type']} · ${r['category']}'
                : '${r['sub_category']}';
            final pct = _num(r['pct']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                onTap: _drillCategory == null
                    ? () => setState(() => _drillCategory = r)
                    : () => _openCategoryDrillDown(r),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            '${pct.toStringAsFixed(1)}% · ${r['count'] ?? 0} ${tr('transactions')}',
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _money(r['total']),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: r['type'] == 'Income'
                            ? AppColors.income
                            : AppColors.expense,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted, size: 18),
                  ],
                ),
              ),
            );
          }),
          SizedBox(height: 16),
          Text(tr('Subcategory-wise'), style: AppText.h3),
          SizedBox(height: 8),
          if (subFallback.isEmpty)
            AppCard(child: Text(tr('No subcategory data')))
          else
            ...subFallback.take(20).map(
                  (c) => _CatTile(
                    row: c,
                    money: _money,
                    numFn: _num,
                    onTap: () => _openCategoryDrillDown(c),
                  ),
                ),
          SizedBox(height: 16),
          Text(tr('Trend analysis'), style: AppText.h3),
          SizedBox(height: 4),
          Text(
            'Last ${trends['months_analyzed'] ?? 6} months',
            style: AppText.caption,
          ),
          SizedBox(height: 10),
          AppCard(
            child: Column(
              children: [
                _TrendRow(
                  label: tr('Income MoM'),
                  value: _pct(trends['income_change_pct']),
                  up: _num(trends['income_change_pct']) >= 0,
                ),
                const Divider(height: 18),
                _TrendRow(
                  label: tr('Expense MoM'),
                  value: _pct(trends['expense_change_pct']),
                  up: _num(trends['expense_change_pct']) <= 0,
                  invertColors: true,
                ),
                const Divider(height: 18),
                _TrendRow(
                  label: tr('Net MoM'),
                  value: _pct(trends['net_change_pct']),
                  up: _num(trends['net_change_pct']) >= 0,
                ),
                const Divider(height: 18),
                _kv(tr('Avg monthly income'),
                    _money(trends['avg_monthly_income'])),
                SizedBox(height: 6),
                _kv(
                  tr('Avg monthly expense'),
                  _money(trends['avg_monthly_expense']),
                ),
                SizedBox(height: 6),
                _kv(tr('Avg monthly net'), _money(trends['avg_monthly_net'])),
              ],
            ),
          ),
          SizedBox(height: 16),
          Text(tr('Income vs Expense trend'), style: AppText.h3),
          SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            child: SizedBox(
              height: 220,
              child: monthly.isEmpty
                  ? Center(child: Text(tr('No trend data')))
                  : _TrendChart(monthly: monthly, numFn: _num),
            ),
          ),
          SizedBox(height: 16),
          _TopCats(
            title: tr('Top income categories'),
            rows: (trends['top_income_categories'] as List? ?? [])
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(),
            color: AppColors.income,
            money: _money,
          ),
          SizedBox(height: 10),
          _TopCats(
            title: tr('Top expense categories'),
            rows: (trends['top_expense_categories'] as List? ?? [])
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(),
            color: AppColors.expense,
            money: _money,
          ),
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
          Text(tr('Monthly schedule'), style: AppText.h3),
          SizedBox(height: 4),
          Text(
            tr('Income and expense totals by month'),
            style: AppText.caption,
          ),
          SizedBox(height: 12),
          if (monthly.isEmpty)
            AppCard(child: Text(tr('No monthly data')))
          else ...[
            AppCard(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              child: SizedBox(
                height: 200,
                child: _MonthlyBarChart(monthly: monthly, numFn: _num),
              ),
            ),
            SizedBox(height: 12),
            ...monthly.reversed.map((m) {
              final net = _num(m['net']);
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
                            _money(net),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: net >= 0
                                  ? AppColors.income
                                  : AppColors.expense,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${tr('Income')}  ${_money(m['income'])}',
                              style: const TextStyle(
                                color: AppColors.income,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${tr('Expense')}  ${_money(m['expense'])}',
                              style: const TextStyle(
                                color: AppColors.expense,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${m['count'] ?? 0} ${tr('transactions')}',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
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
            '${tr('Weekly schedule')} · ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
            style: AppText.h3,
          ),
          SizedBox(height: 4),
          Text(
            tr('Week-wise income and expense for the selected month'),
            style: AppText.caption,
          ),
          SizedBox(height: 12),
          if (weekly.isEmpty)
            AppCard(child: Text(tr('No weekly data')))
          else ...[
            AppCard(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              child: SizedBox(
                height: 200,
                child: _WeeklyBarChart(weekly: weekly, numFn: _num),
              ),
            ),
            SizedBox(height: 12),
            ...weekly.map((w) {
              final net = _num(w['net']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w['label']?.toString() ?? 'Week ${_int(w['week'])}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          _miniPill(
                              'In', _money(w['income']), AppColors.income),
                          SizedBox(width: 6),
                          _miniPill(
                            'Out',
                            _money(w['expense']),
                            AppColors.expense,
                          ),
                          const Spacer(),
                          Text(
                            _money(net),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: net >= 0
                                  ? AppColors.income
                                  : AppColors.expense,
                            ),
                          ),
                        ],
                      ),
                      if (_int(w['count']) > 0) ...[
                        SizedBox(height: 6),
                        Text(
                          '${w['count']} ${tr('transactions')}',
                          style: AppText.caption,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildCategory() {
    final rollup = _list('by_category_rollup');
    final rollupAll = _list('by_category_rollup_all');
    final catsMonth = rollup.isNotEmpty ? rollup : _list('by_category');
    final cats = catsMonth.isNotEmpty ? catsMonth : rollupAll;
    final subs = _list('by_sub_category');
    final subList = subs.isNotEmpty ? subs : _list('by_category');
    final income = cats.where((c) => c['type'] == 'Income').toList();
    final expense = cats.where((c) => c['type'] == 'Expense').toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${tr('Category-wise')} · ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                  style: AppText.h3,
                ),
              ),
              _chartToggle(
                isPie: _categoryPie,
                onChanged: (v) => setState(() => _categoryPie = v),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            tr('Breakdown by category and sub-category'),
            style: AppText.caption,
          ),
          SizedBox(height: 12),
          if (cats.isNotEmpty)
            AppCard(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              child: SizedBox(
                height: 240,
                child: _categoryPie
                    ? _CategoryPieChart(
                        rows: cats,
                        labelKey: 'category',
                        numFn: _num,
                        colors: _chartColors,
                        onTap: (row) => _showSubcategorySheet(row, subList),
                      )
                    : _CategoryBarChart(
                        rows: cats,
                        labelKey: 'category',
                        numFn: _num,
                        colors: _chartColors,
                        onTap: (row) => _showSubcategorySheet(row, subList),
                      ),
              ),
            ),
          SizedBox(height: 14),
          Text(tr('Income'),
              style: AppText.h3.copyWith(color: AppColors.income)),
          SizedBox(height: 8),
          if (income.isEmpty)
            AppCard(child: Text(tr('No income this month')))
          else
            ...income.map(
              (c) => _CatTile(
                row: {
                  ...c,
                  if (c['sub_category'] == null) 'sub_category': c['category'],
                },
                money: _money,
                numFn: _num,
                onTap: () => _showSubcategorySheet(c, subList),
              ),
            ),
          SizedBox(height: 16),
          Text(tr('Expense'),
              style: AppText.h3.copyWith(color: AppColors.expense)),
          SizedBox(height: 8),
          if (expense.isEmpty)
            AppCard(child: Text(tr('No expense this month')))
          else
            ...expense.map(
              (c) => _CatTile(
                row: {
                  ...c,
                  if (c['sub_category'] == null) 'sub_category': c['category'],
                },
                money: _money,
                numFn: _num,
                onTap: () => _showSubcategorySheet(c, subList),
              ),
            ),
          SizedBox(height: 16),
          Text(tr('Subcategory-wise'), style: AppText.h3),
          SizedBox(height: 8),
          if (subList.isEmpty)
            AppCard(child: Text(tr('No subcategory data')))
          else
            ...subList.map(
              (c) => _CatTile(
                row: c,
                money: _money,
                numFn: _num,
                onTap: () => _openCategoryDrillDown(c),
              ),
            ),
        ],
      ),
    );
  }

  void _showSubcategorySheet(
    Map<String, dynamic> categoryRow,
    List<Map<String, dynamic>> allSubs,
  ) {
    final type = categoryRow['type']?.toString();
    final category = categoryRow['category']?.toString();
    final filtered = allSubs
        .where((s) => s['type'] == type && s['category'] == category)
        .toList();
    if (filtered.isEmpty) {
      _openCategoryDrillDown(categoryRow);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.72,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$category · ${tr('Subcategories')}',
                        style: AppText.h3,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  children: [
                    SizedBox(
                      height: 220,
                      child: _CategoryPieChart(
                        rows: filtered,
                        labelKey: 'sub_category',
                        numFn: _num,
                        colors: _chartColors,
                      ),
                    ),
                    SizedBox(height: 12),
                    ...filtered.map(
                      (c) => _CatTile(
                        row: c,
                        money: _money,
                        numFn: _num,
                        onTap: () {
                          Navigator.pop(ctx);
                          _openCategoryDrillDown(c);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openCategoryDrillDown(Map<String, dynamic> row) {
    final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncomeExpenseListScreen(
          initialType: row['type']?.toString(),
          initialCategory: row['category']?.toString(),
          initialSubCategory: row['sub_category']?.toString(),
          initialStartDate: DateFormat('yyyy-MM-dd').format(start),
          initialEndDate: DateFormat('yyyy-MM-dd').format(end),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      children: [
        Expanded(
          child: Text(k, style: TextStyle(color: AppColors.textSecondary)),
        ),
        Text(v, style: TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _miniPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String labelKey;
  final double Function(dynamic) numFn;
  final List<Color> colors;
  final void Function(Map<String, dynamic> row)? onTap;

  const _CategoryPieChart({
    required this.rows,
    required this.labelKey,
    required this.numFn,
    required this.colors,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<double>(0, (s, r) => s + numFn(r['total']));
    if (total <= 0) {
      return Center(child: Text(tr('No data')));
    }
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 36,
        pieTouchData: PieTouchData(
          touchCallback: (event, response) {
            if (onTap == null) return;
            if (event is FlTapUpEvent && response?.touchedSection != null) {
              final i = response!.touchedSection!.touchedSectionIndex;
              if (i >= 0 && i < rows.length) onTap!(rows[i]);
            }
          },
        ),
        sections: [
          for (var i = 0; i < rows.length; i++)
            PieChartSectionData(
              value: numFn(rows[i]['total']),
              title:
                  '${(numFn(rows[i]['pct']) > 0 ? numFn(rows[i]['pct']) : (numFn(rows[i]['total']) / total * 100)).toStringAsFixed(0)}%',
              color: colors[i % colors.length],
              radius: 58,
              titleStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String labelKey;
  final double Function(dynamic) numFn;
  final List<Color> colors;
  final void Function(Map<String, dynamic> row)? onTap;

  const _CategoryBarChart({
    required this.rows,
    required this.labelKey,
    required this.numFn,
    required this.colors,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    double maxY = 0;
    for (final r in rows) {
      final v = numFn(r['total']);
      if (v > maxY) maxY = v;
    }
    if (maxY <= 0) maxY = 1;

    return BarChart(
      BarChartData(
        maxY: maxY * 1.15,
        barTouchData: BarTouchData(
          touchCallback: (event, response) {
            if (onTap == null) return;
            if (event is FlTapUpEvent && response?.spot != null) {
              final i = response!.spot!.touchedBarGroupIndex;
              if (i >= 0 && i < rows.length) onTap!(rows[i]);
            }
          },
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) {
                if (v <= 0) return const SizedBox.shrink();
                final label =
                    v >= 1000 ? '${(v / 1000).round()}k' : v.toStringAsFixed(0);
                return Text(label, style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= rows.length) {
                  return const SizedBox.shrink();
                }
                final label = rows[i][labelKey]?.toString() ?? '';
                final short =
                    label.length > 8 ? '${label.substring(0, 7)}…' : label;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(short, style: const TextStyle(fontSize: 9)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < rows.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: numFn(rows[i]['total']),
                  color: colors[i % colors.length],
                  width: 14,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool wide;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.caption),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: wide ? 18 : 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  final String label;
  final String value;
  final bool up;
  final bool invertColors;

  const _TrendRow({
    required this.label,
    required this.value,
    required this.up,
    this.invertColors = false,
  });

  @override
  Widget build(BuildContext context) {
    final good = invertColors ? !up : up;
    final color = good ? AppColors.income : AppColors.expense;
    return Row(
      children: [
        Expanded(child: Text(label)),
        Icon(
          up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          size: 18,
          color: color,
        ),
        SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}

class _TopCats extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> rows;
  final Color color;
  final String Function(dynamic) money;

  const _TopCats({
    required this.title,
    required this.rows,
    required this.color,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          if (rows.isEmpty)
            Text(tr('No data'), style: TextStyle(color: AppColors.textMuted))
          else
            ...rows.map((r) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${r['category']} · ${r['sub_category']}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      money(r['total']),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _CatTile extends StatelessWidget {
  final Map<String, dynamic> row;
  final String Function(dynamic) money;
  final double Function(dynamic) numFn;
  final VoidCallback? onTap;

  const _CatTile({
    required this.row,
    required this.money,
    required this.numFn,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = row['type'] == 'Income';
    final color = isIncome ? AppColors.income : AppColors.expense;
    final pct = numFn(row['pct']).clamp(0, 100).toDouble();
    final title = row['sub_category']?.toString().isNotEmpty == true
        ? row['sub_category'].toString()
        : (row['category']?.toString() ?? '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            row['category']?.toString() ?? '',
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          money(row['total']),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: AppText.caption,
                        ),
                      ],
                    ),
                    if (onTap != null) ...[
                      SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 6,
                    backgroundColor: color.withValues(alpha: 0.12),
                    color: color,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${row['count'] ?? 0} ${tr('transactions')}',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> monthly;
  final double Function(dynamic) numFn;

  const _TrendChart({required this.monthly, required this.numFn});

  @override
  Widget build(BuildContext context) {
    double maxY = 0;
    for (final m in monthly) {
      maxY = [
        maxY,
        numFn(m['income']),
        numFn(m['expense']),
      ].reduce((a, b) => a > b ? a : b);
    }
    if (maxY <= 0) maxY = 1;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.15,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (v) => FlLine(
            color: AppColors.border,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) {
                if (v <= 0) return const SizedBox.shrink();
                final label = v >= 1000
                    ? '${(v / 1000).round()}k'
                    : v.toStringAsFixed(0);
                return Text(label, style: TextStyle(fontSize: 10));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= monthly.length) {
                  return const SizedBox.shrink();
                }
                final label = monthly[i]['label']?.toString() ?? '';
                final short = label.split(' ').first;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(short, style: TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < monthly.length; i++)
                FlSpot(i.toDouble(), numFn(monthly[i]['income'])),
            ],
            isCurved: true,
            color: AppColors.income,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.income.withValues(alpha: 0.08),
            ),
          ),
          LineChartBarData(
            spots: [
              for (var i = 0; i < monthly.length; i++)
                FlSpot(i.toDouble(), numFn(monthly[i]['expense'])),
            ],
            isCurved: true,
            color: AppColors.expense,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.expense.withValues(alpha: 0.06),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthlyBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> monthly;
  final double Function(dynamic) numFn;

  const _MonthlyBarChart({required this.monthly, required this.numFn});

  @override
  Widget build(BuildContext context) {
    double maxY = 0;
    for (final m in monthly) {
      maxY = [
        maxY,
        numFn(m['income']),
        numFn(m['expense']),
      ].reduce((a, b) => a > b ? a : b);
    }
    if (maxY <= 0) maxY = 1;

    return BarChart(
      BarChartData(
        maxY: maxY * 1.15,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) {
                if (v <= 0) return const SizedBox.shrink();
                final label =
                    v >= 1000 ? '${(v / 1000).round()}k' : v.toStringAsFixed(0);
                return Text(label, style: TextStyle(fontSize: 10));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= monthly.length) {
                  return const SizedBox.shrink();
                }
                final label = monthly[i]['label']?.toString() ?? '';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    label.split(' ').first,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < monthly.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 3,
              barRods: [
                BarChartRodData(
                  toY: numFn(monthly[i]['income']),
                  color: AppColors.income,
                  width: 8,
                  borderRadius: BorderRadius.circular(3),
                ),
                BarChartRodData(
                  toY: numFn(monthly[i]['expense']),
                  color: AppColors.expense,
                  width: 8,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> weekly;
  final double Function(dynamic) numFn;

  const _WeeklyBarChart({required this.weekly, required this.numFn});

  @override
  Widget build(BuildContext context) {
    double maxY = 0;
    for (final w in weekly) {
      maxY = [
        maxY,
        numFn(w['income']),
        numFn(w['expense']),
      ].reduce((a, b) => a > b ? a : b);
    }
    if (maxY <= 0) maxY = 1;

    return BarChart(
      BarChartData(
        maxY: maxY * 1.15,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) {
                if (v <= 0) return const SizedBox.shrink();
                final label =
                    v >= 1000 ? '${(v / 1000).round()}k' : v.toStringAsFixed(0);
                return Text(label, style: TextStyle(fontSize: 10));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= weekly.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('W${i + 1}', style: TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < weekly.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 3,
              barRods: [
                BarChartRodData(
                  toY: numFn(weekly[i]['income']),
                  color: AppColors.income,
                  width: 10,
                  borderRadius: BorderRadius.circular(3),
                ),
                BarChartRodData(
                  toY: numFn(weekly[i]['expense']),
                  color: AppColors.expense,
                  width: 10,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.expense),
            SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: Text(tr('Retry'))),
          ],
        ),
      ),
    );
  }
}
