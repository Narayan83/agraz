import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'app_theme.dart';
import 'market_report_service.dart';

class RatesComparisonPage extends StatefulWidget {
  const RatesComparisonPage({super.key});

  @override
  State<RatesComparisonPage> createState() => _RatesComparisonPageState();
}

class _RatesComparisonPageState extends State<RatesComparisonPage> {
  DateTime _selectedDate = DateTime(2026, 8, 6);
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _agents = [];
  List<Map<String, dynamic>> _apmcs = [];
  List<Map<String, dynamic>> _varieties = [];
  List<String> _taluks = [];

  int? _agentId;
  int? _apmcId;
  int? _varietyId;
  String? _taluk;
  int _rangeDays = 7;

  List<Map<String, dynamic>> _dayPrices = [];
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _qty = [];

  static const List<Color> _chartPalette = [
    Color(0xFF2E7CF6),
    Color(0xFFE9A13B),
    Color(0xFF16A34A),
    Color(0xFFDC2626),
    Color(0xFF8B5CF6),
    Color(0xFF0EA5E9),
  ];

  static const Color _minColor = Color(0xFF64B5F6);
  static const Color _maxColor = Color(0xFF2E9265);
  static const Color _avgColor = Color(0xFFE9A13B);
  static const List<String> _metricLabels = ['Min', 'Max', 'Avg'];

  /* ------------------------------------------------------------------ */
  /*  Data                                                               */
  /* ------------------------------------------------------------------ */

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _money(dynamic v) {
    if (v == null) return '—';
    return '₹${NumberFormat('#,##0').format(_num(v).round())}';
  }

  String _fmtMoney(double v) => '₹${NumberFormat('#,##0').format(v.round())}';

  String _fmtQty(double v) => NumberFormat.compact().format(v.round());

  String _fmtDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

  String _fmtDay(String iso) {
    try {
      return DateFormat('d MMM').format(DateTime.parse(iso));
    } catch (_) {
      return iso.length >= 10 ? iso.substring(8) : iso;
    }
  }

  String _fmtAxis(double v) {
    if (v >= 1000) return '${(v / 1000).round()}k';
    return v.toStringAsFixed(0);
  }

  String _short(String s, [int len = 12]) =>
      s.length <= len ? s : '${s.substring(0, len - 1)}…';

  String _varietyName(Map<String, dynamic> p) {
    final v = p['variety'];
    return v is Map ? (v['name']?.toString() ?? '—') : '—';
  }

  Set<String> _dayVarietyNames() =>
      {for (final p in _dayPrices) _varietyName(p)};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        fetchMarketAgents(),
        fetchMarketApmcs(),
        fetchMarketVarieties(),
        fetchMarketTaluks(),
      ]);
      _agents = results[0] as List<Map<String, dynamic>>;
      _apmcs = results[1] as List<Map<String, dynamic>>;
      _varieties = results[2] as List<Map<String, dynamic>>;
      _taluks = results[3] as List<String>;
      await _loadData();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final date = _iso(_selectedDate);
      final from = _iso(_selectedDate.subtract(Duration(days: _rangeDays - 1)));
      final results = await Future.wait([
        fetchMarketDailyPrices(
          date: date,
          agentId: _agentId,
          apmcId: _apmcId,
          varietyId: _varietyId,
          taluk: _taluk,
        ),
        fetchMarketDailyPrices(
          from: from,
          to: date,
          agentId: _agentId,
          apmcId: _apmcId,
          varietyId: _varietyId,
          taluk: _taluk,
          limit: 500,
        ),
        fetchMarketQuantities(
          date: date,
          agentId: _agentId,
          apmcId: _apmcId,
          taluk: _taluk,
        ),
      ]);
      setState(() {
        _dayPrices = results[0];
        _history = results[1];
        _qty = results[2];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _loadData();
    }
  }

  /* ------------------------------------------------------------------ */
  /*  History helpers                                                    */
  /* ------------------------------------------------------------------ */

  List<String> _historyDates() {
    final set = <String>{};
    for (final p in _history) {
      final d = (p['date']?.toString() ?? '');
      if (d.length >= 10) set.add(d.substring(0, 10));
    }
    return set.toList()..sort();
  }

  List<FlSpot> _historySpots(String varietyName, List<String> dates) {
    final byDate = <String, double>{};
    for (final p in _history) {
      if (_varietyName(p) != varietyName) continue;
      final d = (p['date']?.toString() ?? '');
      if (d.length < 10) continue;
      byDate[d.substring(0, 10)] = _num(p['avg_price']);
    }
    final spots = <FlSpot>[];
    for (var i = 0; i < dates.length; i++) {
      final val = byDate[dates[i]];
      if (val != null) spots.add(FlSpot(i.toDouble(), val));
    }
    return spots;
  }

  List<String> _historyVarieties() {
    final counts = <String, int>{};
    for (final p in _history) {
      final n = _varietyName(p);
      if (n == '—') continue;
      counts[n] = (counts[n] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => e.key).take(4).toList();
  }

  /* ------------------------------------------------------------------ */
  /*  Build                                                              */
  /* ------------------------------------------------------------------ */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              icon: Icons.trending_up_rounded,
              title: 'Market Reports',
              subtitle: 'Commodity prices, arrivals & trends',
              trailing: _headerAction(_loadData),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.primary,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildFilters(context),
                            const SizedBox(height: 14),
                            if (_loading)
                              _buildLoadingCard(context)
                            else if (_error != null)
                              _buildErrorCard(context)
                            else ...[
                              _buildStats(context),
                              const SizedBox(height: 14),
                              _buildRatesCard(context),
                              const SizedBox(height: 14),
                              _buildComparisonCard(context),
                              const SizedBox(height: 14),
                              _buildHistoryCard(context),
                              if (_qty.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _buildQuantityCard(context),
                              ],
                            ],
                          ],
                        ),
                      ),
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

  Widget _headerAction(VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _sectionCard(BuildContext context, Widget child,
      {EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.border,
        ),
        boxShadow: isDark ? null : [AppColors.cardShadow],
      ),
      child: child,
    );
  }

  Widget _sectionHeader(BuildContext context, IconData icon, String title,
      String? subtitle,
      {Color color = AppColors.primary, Widget? trailing}) {
    final ts = Theme.of(context).colorScheme;
    return Row(
      children: [
        TintedIcon(icon: icon, color: color, boxSize: 34, size: 17, radius: 10),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: ts.onSurface,
              )),
              if (subtitle != null) ...[
                const SizedBox(height: 1),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: ts.onSurfaceVariant)),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _emptyMessage(BuildContext context, IconData icon, String title,
      [String? subtitle]) {
    final ts = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TintedIcon(icon: icon, color: ts.onSurfaceVariant,
                boxSize: 56, size: 26, radius: 18),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ts.onSurface)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: ts.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return _sectionCard(
      context,
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 56),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading market data…',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    final ts = Theme.of(context).colorScheme;
    return _sectionCard(
      context,
      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.expense, size: 34),
            const SizedBox(height: 10),
            Text('Could not load data',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ts.onSurface)),
            const SizedBox(height: 4),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: ts.onSurfaceVariant)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  /* ------------------------------------------------------------------ */
  /*  Filters                                                            */
  /* ------------------------------------------------------------------ */

  Widget _buildFilters(BuildContext context) {
    return _sectionCard(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDateField(context),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final w = (c.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(width: w, child: _buildAgentDropdown(context)),
                  SizedBox(width: w, child: _buildApmcDropdown(context)),
                  SizedBox(width: w, child: _buildTalukDropdown(context)),
                  SizedBox(width: w, child: _buildVarietyDropdown(context)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ts = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0E1612) : AppColors.field,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('REPORT DATE', style: AppText.caption),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('EEEE, d MMM yyyy').format(_selectedDate),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: ts.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded,
                color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentDropdown(BuildContext context) {
    return _filterDropdown(
      context,
      label: 'Agent',
      value: _agentId?.toString(),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('All Agents')),
        for (final a in _agents)
          DropdownMenuItem<String?>(
            value: a['id']?.toString(),
            child: Text(_short('${a['name']}', 18), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) async {
        setState(() => _agentId = v == null ? null : int.tryParse(v));
        await _loadData();
      },
    );
  }

  Widget _buildApmcDropdown(BuildContext context) {
    return _filterDropdown(
      context,
      label: 'APMC',
      value: _apmcId?.toString(),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('All APMCs')),
        for (final a in _apmcs)
          DropdownMenuItem<String?>(
            value: a['id']?.toString(),
            child: Text(_short('${a['name']}', 18), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) async {
        setState(() => _apmcId = v == null ? null : int.tryParse(v));
        await _loadData();
      },
    );
  }

  Widget _buildTalukDropdown(BuildContext context) {
    return _filterDropdown(
      context,
      label: 'Taluk',
      value: _taluk,
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('All Taluks')),
        for (final t in _taluks)
          DropdownMenuItem<String?>(value: t, child: Text(t)),
      ],
      onChanged: (v) async {
        setState(() => _taluk = v);
        await _loadData();
      },
    );
  }

  Widget _buildVarietyDropdown(BuildContext context) {
    return _filterDropdown(
      context,
      label: 'Variety',
      value: _varietyId?.toString(),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('All Varieties')),
        for (final v in _varieties)
          DropdownMenuItem<String?>(
            value: v['id']?.toString(),
            child: Text(_short('${v['name']}', 18), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) async {
        setState(() => _varietyId = v == null ? null : int.tryParse(v));
        await _loadData();
      },
    );
  }

  Widget _filterDropdown(
    BuildContext context, {
    required String label,
    required String? value,
    required List<DropdownMenuItem<String?>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ts = Theme.of(context).colorScheme;
    final hasValue = items.any((e) => e.value == value);
    return DropdownButtonFormField<String?>(
      initialValue: hasValue ? value : null,
      isExpanded: true,
      isDense: true,
      onChanged: onChanged,
      dropdownColor: ts.surface,
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: AppColors.primary),
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ts.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(fontSize: 13, color: ts.onSurfaceVariant),
        floatingLabelStyle: const TextStyle(
            color: AppColors.primary, fontWeight: FontWeight.w700),
        filled: true,
        fillColor: isDark ? const Color(0xFF0E1612) : AppColors.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
      items: items,
    );
  }

  /* ------------------------------------------------------------------ */
  /*  Stats                                                              */
  /* ------------------------------------------------------------------ */

  Widget _buildStats(BuildContext context) {
    final prices = _dayPrices;
    final avgList = prices
        .map((p) => _num(p['avg_price']))
        .where((v) => v > 0)
        .toList();
    final overallAvg =
        avgList.isEmpty ? 0.0 : avgList.reduce((a, b) => a + b) / avgList.length;
    final arrival = _qty.fold(0.0, (s, q) => s + _num(q['arrival_qty']));
    final trade = _qty.fold(0.0, (s, q) => s + _num(q['trade_qty']));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              _statTile(context, 'Varieties', '${_dayVarietyNames().length}',
                  Icons.category_rounded, AppColors.info),
              const SizedBox(height: 10),
              _statTile(context, 'Avg Rate', _fmtMoney(overallAvg),
                  Icons.currency_rupee_rounded, AppColors.primary),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: [
              _statTile(context, 'Arrival', _fmtQty(arrival),
                  Icons.local_shipping_rounded, AppColors.accent),
              const SizedBox(height: 10),
              _statTile(context, 'Traded', _fmtQty(trade),
                  Icons.shopping_cart_rounded, AppColors.expense),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statTile(BuildContext context, String label, String value,
      IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ts = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.border,
        ),
        boxShadow: isDark ? null : [AppColors.softShadow],
      ),
      child: Row(
        children: [
          TintedIcon(icon: icon, color: color, boxSize: 34, size: 17, radius: 10),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: ts.onSurface)),
                ),
                const SizedBox(height: 1),
                Text(label, style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /* ------------------------------------------------------------------ */
  /*  Rates table                                                        */
  /* ------------------------------------------------------------------ */

  Widget _buildRatesCard(BuildContext context) {
    final prices = List<Map<String, dynamic>>.from(_dayPrices)
      ..sort((a, b) => _num(b['avg_price']).compareTo(_num(a['avg_price'])));
    return _sectionCard(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(
            context,
            Icons.table_rows_rounded,
            "Today's Market Rates",
            '${_dayVarietyNames().length} varieties · ${_fmtDate(_selectedDate)}',
          ),
          const SizedBox(height: 14),
          if (prices.isEmpty)
            _emptyMessage(context, Icons.inventory_2_rounded, 'No rates found',
                'Try a different date or adjust the filters')
          else ...[
            _ratesHeader(context),
            const SizedBox(height: 4),
            for (var i = 0; i < prices.length; i++) _ratesRow(context, i, prices[i]),
          ],
        ],
      ),
    );
  }

  Widget _ratesHeader(BuildContext context) {
    final ts = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: ts.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('VARIETY', style: style)),
          Expanded(child: Text('MIN', textAlign: TextAlign.right, style: style)),
          Expanded(child: Text('MAX', textAlign: TextAlign.right, style: style)),
          Expanded(child: Text('AVG', textAlign: TextAlign.right, style: style)),
        ],
      ),
    );
  }

  Widget _ratesRow(BuildContext context, int index, Map<String, dynamic> p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ts = Theme.of(context).colorScheme;
    final color = _chartPalette[index % _chartPalette.length];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: index.isEven
            ? (isDark
                ? Colors.white.withValues(alpha: 0.04)
                : AppColors.surfaceAlt.withValues(alpha: 0.5))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_varietyName(p),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: ts.onSurface)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(_money(p['min_price']),
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12.5, color: ts.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(_money(p['max_price']),
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12.5, color: ts.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(_money(p['avg_price']),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  /* ------------------------------------------------------------------ */
  /*  Comparison bar chart                                               */
  /* ------------------------------------------------------------------ */

  Widget _buildComparisonCard(BuildContext context) {
    final prices = List<Map<String, dynamic>>.from(_dayPrices)
      ..sort((a, b) => _num(b['avg_price']).compareTo(_num(a['avg_price'])));
    final top = prices.take(6).toList();
    return _sectionCard(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(
            context,
            Icons.bar_chart_rounded,
            'Price Comparison',
            'Min · Max · Avg for ${_fmtDate(_selectedDate)}',
          ),
          const SizedBox(height: 12),
          _metricLegend(context),
          const SizedBox(height: 10),
          if (top.isEmpty)
            SizedBox(
              height: 220,
              child: _emptyMessage(context, Icons.bar_chart_rounded, 'No data',
                  'Nothing to compare for this selection'),
            )
          else ...[
            SizedBox(height: 230, child: _buildComparisonChart(context, top)),
            if (prices.length > top.length)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Showing top ${top.length} varieties by average price',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _metricLegend(BuildContext context) {
    final ts = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        _legendDot(_minColor, 'Min', ts),
        _legendDot(_maxColor, 'Max', ts),
        _legendDot(_avgColor, 'Avg', ts),
      ],
    );
  }

  Widget _legendDot(Color color, String label, ColorScheme ts) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ts.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildComparisonChart(
      BuildContext context, List<Map<String, dynamic>> prices) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ts = Theme.of(context).colorScheme;
    final gridColor =
        isDark ? Colors.white.withValues(alpha: 0.07) : AppColors.border;
    final labelColor = ts.onSurfaceVariant;

    final groups = <BarChartGroupData>[];
    var x = 0;
    for (final p in prices) {
      groups.addAll([
        BarChartGroupData(x: x++, barRods: [
          BarChartRodData(
            toY: _num(p['min_price']),
            color: _minColor,
            width: 11,
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ]),
        BarChartGroupData(x: x++, barRods: [
          BarChartRodData(
            toY: _num(p['max_price']),
            color: _maxColor,
            width: 11,
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ]),
        BarChartGroupData(x: x++, barRods: [
          BarChartRodData(
            toY: _num(p['avg_price']),
            color: _avgColor,
            width: 11,
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ]),
      ]);
    }

    final maxV = groups.fold<double>(
            0,
            (m, g) =>
                g.barRods.fold<double>(m, (mm, r) => r.toY > mm ? r.toY : mm)) *
        1.2;
    final axisInterval = (maxV / 4).ceilToDouble().clamp(1.0, double.infinity).toDouble();

    return BarChart(
      BarChartData(
        maxY: maxV,
        barGroups: groups,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) =>
                isDark ? const Color(0xFF26332C) : const Color(0xFF14281D),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final metric = _metricLabels[group.x % 3];
              final vi = group.x ~/ 3;
              final name = vi < prices.length ? _varietyName(prices[vi]) : '';
              return BarTooltipItem(
                '$name\n$metric\n${_fmtMoney(rod.toY)}',
                const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 3,
              reservedSize: 26,
              getTitlesWidget: (v, meta) {
                final xv = v.toInt();
                if (xv % 3 != 1) return const SizedBox.shrink();
                final vi = xv ~/ 3;
                if (vi < 0 || vi >= prices.length) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(_short(_varietyName(prices[vi]), 9),
                      style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          color: labelColor)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: axisInterval,
              getTitlesWidget: (v, meta) =>
                  Text(_fmtAxis(v), style: TextStyle(fontSize: 9, color: labelColor)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: gridColor, strokeWidth: 1, dashArray: [4, 4]),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  /* ------------------------------------------------------------------ */
  /*  History line chart                                                 */
  /* ------------------------------------------------------------------ */

  Widget _buildHistoryCard(BuildContext context) {
    final dates = _historyDates();
    final varieties = _historyVarieties();
    final lines = <LineChartBarData>[];
    final barNames = <String>[];
    for (var i = 0; i < varieties.length; i++) {
      final spots = _historySpots(varieties[i], dates);
      if (spots.isEmpty) continue;
      final color = _chartPalette[i % _chartPalette.length];
      lines.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.35,
        color: color,
        barWidth: 2.5,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.10)),
      ));
      barNames.add(varieties[i]);
    }
    return _sectionCard(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(
            context,
            Icons.show_chart_rounded,
            'Price Trend',
            'Average price movement',
            trailing: _rangeSelector(context),
          ),
          const SizedBox(height: 12),
          if (barNames.isEmpty)
            SizedBox(
              height: 220,
              child: _emptyMessage(context, Icons.show_chart_rounded,
                  'No trend data', 'No history for the selected date & filters'),
            )
          else ...[
            _varietyLegend(context, barNames),
            const SizedBox(height: 10),
            SizedBox(height: 240, child: _buildHistoryChart(context, dates, lines, barNames)),
          ],
        ],
      ),
    );
  }

  Widget _rangeSelector(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SegmentedButton<int>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: 7, label: Text('7D')),
        ButtonSegment(value: 14, label: Text('14D')),
        ButtonSegment(value: 30, label: Text('30D')),
      ],
      selected: {_rangeDays},
      onSelectionChanged: (s) async {
        setState(() => _rangeDays = s.first);
        await _loadData();
      },
      style: SegmentedButton.styleFrom(
        textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
        foregroundColor: primary,
        selectedForegroundColor: Theme.of(context).colorScheme.onPrimary,
        selectedBackgroundColor: primary,
        side: BorderSide(color: primary, width: 1.1),
      ),
    );
  }

  Widget _varietyLegend(BuildContext context, List<String> varieties) {
    final ts = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        for (var i = 0; i < varieties.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: _chartPalette[i % _chartPalette.length],
                    shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(varieties[i],
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ts.onSurfaceVariant)),
            ],
          ),
      ],
    );
  }

  Widget _buildHistoryChart(BuildContext context, List<String> dates,
      List<LineChartBarData> bars, List<String> barNames) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ts = Theme.of(context).colorScheme;
    final gridColor =
        isDark ? Colors.white.withValues(alpha: 0.07) : AppColors.border;
    final labelColor = ts.onSurfaceVariant;

    if (bars.isEmpty) return const SizedBox.shrink();

    final allY = [for (final b in bars) ...b.spots.map((s) => s.y)];
    var minY = allY.reduce((a, b) => a < b ? a : b) * 0.95;
    var maxY = allY.reduce((a, b) => a > b ? a : b) * 1.05;
    if (maxY - minY < 1) {
      minY -= 1;
      maxY += 1;
    }
    var axisInterval = (maxY - minY) / 4;
    if (axisInterval < 1) axisInterval = 1;
    axisInterval = axisInterval.ceilToDouble();
    final xInterval = (dates.length / 4).ceil().clamp(1, 7).toDouble();
    final maxX = (dates.length - 1).clamp(0, 1000).toDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                isDark ? const Color(0xFF26332C) : const Color(0xFF14281D),
            getTooltipItems: (spots) => spots.map((s) {
              final vi = s.barIndex;
              final name =
                  vi >= 0 && vi < barNames.length ? barNames[vi] : '';
              final di = s.x.toInt();
              final date = di >= 0 && di < dates.length ? _fmtDay(dates[di]) : '';
              return LineTooltipItem(
                '$name · $date\n${_fmtMoney(s.y)}',
                const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700),
              );
            }).toList(),
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: xInterval,
              reservedSize: 24,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= dates.length) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(_fmtDay(dates[i]),
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: labelColor)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: axisInterval,
              getTitlesWidget: (v, meta) =>
                  Text(_fmtAxis(v), style: TextStyle(fontSize: 9, color: labelColor)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: gridColor, strokeWidth: 1, dashArray: [4, 4]),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: bars,
      ),
    );
  }

  /* ------------------------------------------------------------------ */
  /*  Quantities                                                         */
  /* ------------------------------------------------------------------ */

  Widget _buildQuantityCard(BuildContext context) {
    final totalArrival = _qty.fold(0.0, (s, q) => s + _num(q['arrival_qty']));
    final totalTrade = _qty.fold(0.0, (s, q) => s + _num(q['trade_qty']));
    final totalStock = _qty.fold(0.0, (s, q) => s + _num(q['stock_qty']));
    final maxQ = _qty.fold<double>(
        0,
        (m, q) => [
          m,
          _num(q['arrival_qty']),
          _num(q['trade_qty']),
          _num(q['stock_qty']),
        ].reduce((a, b) => a > b ? a : b));

    return _sectionCard(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(
            context,
            Icons.inventory_2_rounded,
            'Arrivals & Stocks',
            '${_fmtQty(totalArrival)} arrived · ${_fmtQty(totalTrade)} traded · ${_fmtQty(totalStock)} in stock',
          ),
          const SizedBox(height: 14),
          for (final q in _qty) ...[
            _qtyRow(context, q, maxQ),
            if (q != _qty.last) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _qtyRow(BuildContext context, Map<String, dynamic> q, double maxQ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_varietyName(q),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 7),
        _miniBar(context, 'Arrival', _num(q['arrival_qty']), maxQ,
            AppColors.info, Icons.local_shipping_rounded),
        const SizedBox(height: 6),
        _miniBar(context, 'Trade', _num(q['trade_qty']), maxQ,
            AppColors.accent, Icons.swap_horiz_rounded),
        const SizedBox(height: 6),
        _miniBar(context, 'Stock', _num(q['stock_qty']), maxQ,
            AppColors.primary, Icons.inventory_2_rounded),
      ],
    );
  }

  Widget _miniBar(BuildContext context, String label, double value, double maxQ,
      Color color, IconData icon) {
    final ts = Theme.of(context).colorScheme;
    final frac = maxQ <= 0 ? 0.0 : (value / maxQ).clamp(0.0, 1.0).toDouble();
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 7),
        SizedBox(
          width: 60,
          child: Text(label,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: ts.onSurfaceVariant)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.15),
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 78,
          child: Text(_fmtQty(value),
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: ts.onSurface)),
        ),
      ],
    );
  }
}
