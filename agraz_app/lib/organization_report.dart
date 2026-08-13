import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'l10n/app_l10n.dart';

class OrganizationReportPage extends StatefulWidget {
  final int? orgId;
  const OrganizationReportPage({super.key, this.orgId});

  @override
  State<OrganizationReportPage> createState() => _OrganizationReportPageState();
}

class _OrganizationReportPageState extends State<OrganizationReportPage>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabs;

  List<Map<String, dynamic>> _orgs = [];
  List<Map<String, dynamic>> _ledgers = [];
  int? _orgId;
  int? _ledgerId;
  DateTime? _from;
  DateTime? _to;

  bool _loading = true;
  Map<String, dynamic>? _data;
  bool _orgPie = true;
  bool _ledgerPie = true;

  static const _colors = [
    Color(0xFF16A34A),
    Color(0xFF2E7CF6),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    Color(0xFFDB2777),
    Color(0xFF65A30D),
  ];

  @override
  void initState() {
    super.initState();
    _orgId = widget.orgId;
    _tabs = TabController(length: 4, vsync: this);
    _bootstrap();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse('$v');
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  String _money(dynamic v) =>
      '₹${NumberFormat('#,##0.##').format(_num(v))}';

  String? _fmt(DateTime? d) =>
      d == null ? null : DateFormat('yyyy-MM-dd').format(d);

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final orgs = await _api.fetchOrganizations();
      final leds = await _api.fetchOrgLedgers();
      if (!mounted) return;
      setState(() {
        _orgs = orgs;
        _ledgers = leds;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.expense,
        ),
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.fetchOrgReports(
        organizationId: _orgId,
        ledgerId: _ledgerId,
        from: _fmt(_from),
        to: _fmt(_to),
      );
      if (!mounted) return;
      setState(() => _data = data);
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

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (d != null) setState(() => _from = d);
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (d != null) setState(() => _to = d);
  }

  @override
  Widget build(BuildContext context) {
    final overview = _data?['overview'] is Map
        ? Map<String, dynamic>.from(_data!['overview'] as Map)
        : <String, dynamic>{};

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              icon: Icons.insights_rounded,
              title: tr('Organization Reports'),
              subtitle: tr('Balances, trends & filters'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: AppCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            initialValue: _orgId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: tr('Organization'),
                              isDense: true,
                            ),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text(tr('All organizations')),
                              ),
                              ..._orgs.map((o) {
                                final id = _asInt(o['id']);
                                return DropdownMenuItem<int?>(
                                  value: id,
                                  child: Text('${o['name'] ?? ''}'),
                                );
                              }),
                            ],
                            onChanged: (v) => setState(() => _orgId = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            initialValue: _ledgerId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: tr('Ledger'),
                              isDense: true,
                            ),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text(tr('All ledgers')),
                              ),
                              ..._ledgers.map((l) {
                                final id = _asInt(l['id']);
                                return DropdownMenuItem<int?>(
                                  value: id,
                                  child: Text('${l['name'] ?? ''}'),
                                );
                              }),
                            ],
                            onChanged: (v) => setState(() => _ledgerId = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickFrom,
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              _from == null
                                  ? tr('From date')
                                  : DateFormat('dd/MM/yyyy').format(_from!),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickTo,
                            icon: const Icon(Icons.event, size: 16),
                            label: Text(
                              _to == null
                                  ? tr('To date')
                                  : DateFormat('dd/MM/yyyy').format(_to!),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _load,
                            icon: const Icon(Icons.search_rounded),
                            label: Text(tr('Apply')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _orgId = null;
                              _ledgerId = null;
                              _from = null;
                              _to = null;
                            });
                            _load();
                          },
                          child: Text(tr('Clear')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _stat(
                      tr('Income'),
                      _money(overview['income']),
                      AppColors.income,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _stat(
                      tr('Expense'),
                      _money(overview['expense']),
                      AppColors.expense,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _stat(
                      tr('Balance'),
                      _money(overview['balance']),
                      AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              labelColor: AppColors.primary,
              tabs: [
                Tab(text: tr('Org-wise')),
                Tab(text: tr('Ledger-wise')),
                Tab(text: tr('Monthly')),
                Tab(text: tr('Weekly')),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _orgTab(),
                        _ledgerTab(),
                        _monthlyTab(),
                        _weeklyTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 14)),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _list(String key) =>
      (_data?[key] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  Widget _orgTab() {
    final rows = _list('organization_balances');
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _chartToggle(pie: _orgPie, onChanged: (v) => setState(() => _orgPie = v)),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: rows.isEmpty
              ? Center(child: Text(tr('No data')))
              : _orgPie
                  ? _balancePie(rows, 'organization_name')
                  : _balanceBar(rows, 'organization_name'),
        ),
        const SizedBox(height: 12),
        ...rows.map((r) {
          final bal = _num(r['balance']);
          return Card(
            child: ListTile(
              title: Text('${r['organization_name'] ?? ''}'),
              subtitle: Text(
                '${tr('Income')} ${_money(r['income'])} · ${tr('Expense')} ${_money(r['expense'])}',
              ),
              trailing: Text(
                _money(bal),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: bal >= 0 ? AppColors.income : AppColors.expense,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _ledgerTab() {
    final rows = _list('ledger_balances');
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _chartToggle(
            pie: _ledgerPie, onChanged: (v) => setState(() => _ledgerPie = v)),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: rows.isEmpty
              ? Center(child: Text(tr('No data')))
              : _ledgerPie
                  ? _balancePie(rows, 'ledger_name')
                  : _balanceBar(rows, 'ledger_name'),
        ),
        const SizedBox(height: 12),
        ...rows.map((r) {
          final bal = _num(r['balance']);
          return Card(
            child: ListTile(
              title: Text('${r['ledger_name'] ?? ''}'),
              subtitle: Text(
                '${tr('Income')} ${_money(r['income'])} · ${tr('Expense')} ${_money(r['expense'])}',
              ),
              trailing: Text(
                _money(bal),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: bal >= 0 ? AppColors.income : AppColors.expense,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _monthlyTab() {
    final rows = _list('monthly');
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SizedBox(
          height: 240,
          child: rows.isEmpty
              ? Center(child: Text(tr('No data')))
              : _trendBars(rows, 'month'),
        ),
        const SizedBox(height: 12),
        ...rows.reversed.map((r) {
          final net = _num(r['income']) - _num(r['expense']);
          return Card(
            child: ListTile(
              title: Text('${r['month'] ?? ''}'),
              subtitle: Text(
                '${tr('Income')} ${_money(r['income'])} · ${tr('Expense')} ${_money(r['expense'])}',
              ),
              trailing: Text(
                _money(net),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: net >= 0 ? AppColors.income : AppColors.expense,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _weeklyTab() {
    final rows = _list('weekly');
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SizedBox(
          height: 240,
          child: rows.isEmpty
              ? Center(child: Text(tr('No data')))
              : _trendBars(rows, 'week'),
        ),
        const SizedBox(height: 12),
        ...rows.reversed.map((r) {
          final net = _num(r['income']) - _num(r['expense']);
          return Card(
            child: ListTile(
              title: Text('${r['week'] ?? ''}'),
              subtitle: Text(
                '${tr('Income')} ${_money(r['income'])} · ${tr('Expense')} ${_money(r['expense'])}',
              ),
              trailing: Text(
                _money(net),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: net >= 0 ? AppColors.income : AppColors.expense,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _chartToggle({required bool pie, required ValueChanged<bool> onChanged}) {
    return Row(
      children: [
        Text(tr('Chart'), style: AppText.caption),
        const Spacer(),
        ChoiceChip(
          label: Text(tr('Pie')),
          selected: pie,
          onSelected: (_) => onChanged(true),
        ),
        const SizedBox(width: 6),
        ChoiceChip(
          label: Text(tr('Bar')),
          selected: !pie,
          onSelected: (_) => onChanged(false),
        ),
      ],
    );
  }

  Widget _balancePie(List<Map<String, dynamic>> rows, String nameKey) {
    final sections = <PieChartSectionData>[];
    for (var i = 0; i < rows.length; i++) {
      final bal = _num(rows[i]['balance']).abs();
      if (bal <= 0) continue;
      sections.add(PieChartSectionData(
        value: bal,
        color: _colors[i % _colors.length],
        title: '${rows[i][nameKey] ?? ''}'.length > 8
            ? '${'${rows[i][nameKey]}'.substring(0, 8)}…'
            : '${rows[i][nameKey] ?? ''}',
        radius: 70,
        titleStyle: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
      ));
    }
    if (sections.isEmpty) {
      return Center(child: Text(tr('No balance to chart')));
    }
    return PieChart(PieChartData(sections: sections, sectionsSpace: 2));
  }

  Widget _balanceBar(List<Map<String, dynamic>> rows, String nameKey) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= rows.length) return const SizedBox.shrink();
                final name = '${rows[i][nameKey] ?? ''}';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    name.length > 6 ? '${name.substring(0, 6)}…' : name,
                    style: const TextStyle(fontSize: 9),
                  ),
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
                  toY: _num(rows[i]['income']),
                  color: AppColors.income,
                  width: 8,
                ),
                BarChartRodData(
                  toY: _num(rows[i]['expense']),
                  color: AppColors.expense,
                  width: 8,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _trendBars(List<Map<String, dynamic>> rows, String labelKey) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= rows.length) return const SizedBox.shrink();
                final label = '${rows[i][labelKey] ?? ''}';
                final short = label.length > 7 ? label.substring(label.length - 7) : label;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
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
                  toY: _num(rows[i]['income']),
                  color: AppColors.income,
                  width: 7,
                ),
                BarChartRodData(
                  toY: _num(rows[i]['expense']),
                  color: AppColors.expense,
                  width: 7,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
