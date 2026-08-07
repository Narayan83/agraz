import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

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
  String? _taluk;

  List<Map<String, dynamic>> _dayPrices = [];
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _qty = [];

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

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
      final from = _iso(_selectedDate.subtract(const Duration(days: 6)));
      final day = await fetchMarketDailyPrices(
        date: date,
        agentId: _agentId,
        apmcId: _apmcId,
        taluk: _taluk,
      );
      final hist = await fetchMarketDailyPrices(
        from: from,
        to: date,
        agentId: _agentId,
        apmcId: _apmcId,
        taluk: _taluk,
        limit: 200,
      );
      final qty = await fetchMarketQuantities(
        date: date,
        agentId: _agentId,
        apmcId: _apmcId,
        taluk: _taluk,
      );
      setState(() {
        _dayPrices = day;
        _history = hist;
        _qty = qty;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Map<String, dynamic>? _priceFor(String name) {
    for (final p in _dayPrices) {
      final v = p['variety'];
      if (v is Map && (v['name']?.toString() ?? '') == name) return p;
    }
    return null;
  }

  List<FlSpot> _historySpots(String varietyName, List<String> dates) {
    final byDate = <String, double>{};
    for (final p in _history) {
      final v = p['variety'];
      final name = v is Map ? (v['name']?.toString() ?? '') : '';
      if (name != varietyName) continue;
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

  List<String> _historyDates() {
    final set = <String>{};
    for (final p in _history) {
      final d = (p['date']?.toString() ?? '');
      if (d.length >= 10) set.add(d.substring(0, 10));
    }
    final list = set.toList()..sort();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final rashi = _priceFor('Rashi');
    final chali = _priceFor('Chali');
    final pepper = _priceFor('Pepper');
    final histDates = _historyDates();
    final maxAvg = [
      if (rashi != null) _num(rashi['avg_price']),
      if (chali != null) _num(chali['avg_price']),
      if (pepper != null) _num(pepper['avg_price']),
      50000.0,
    ].reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Reports'),
        centerTitle: true,
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[100],
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text('Date: ', style: TextStyle(fontWeight: FontWeight.bold)),
                            TextButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setState(() => _selectedDate = picked);
                                  await _loadData();
                                }
                              },
                              child: Text(
                                '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _filterChipDropdown(
                              label: 'Agent',
                              value: _agentId?.toString(),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('All')),
                                ..._agents.map(
                                  (a) => DropdownMenuItem(
                                    value: a['id']?.toString(),
                                    child: Text('${a['name']}'),
                                  ),
                                ),
                              ],
                              onChanged: (v) async {
                                setState(() => _agentId = v == null ? null : int.tryParse(v));
                                await _loadData();
                              },
                            ),
                            _filterChipDropdown(
                              label: 'APMC',
                              value: _apmcId?.toString(),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('All')),
                                ..._apmcs.map(
                                  (a) => DropdownMenuItem(
                                    value: a['id']?.toString(),
                                    child: Text('${a['name']}'),
                                  ),
                                ),
                              ],
                              onChanged: (v) async {
                                setState(() => _apmcId = v == null ? null : int.tryParse(v));
                                await _loadData();
                              },
                            ),
                            _filterChipDropdown(
                              label: 'Taluk',
                              value: _taluk,
                              items: [
                                const DropdownMenuItem(value: null, child: Text('All')),
                                ..._taluks.map(
                                  (t) => DropdownMenuItem(value: t, child: Text(t)),
                                ),
                              ],
                              onChanged: (v) async {
                                setState(() => _taluk = v);
                                await _loadData();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  )
                else ...[
                  _buildRatesTable(rashi, chali, pepper),
                  const SizedBox(height: 20),
                  if (_qty.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Arrival / Trade / Stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ..._qty.map((q) {
                              final name = q['variety'] is Map ? q['variety']['name'] : 'Item';
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  '$name — Arrival ${_num(q['arrival_qty']).toStringAsFixed(0)}, '
                                  'Trade ${_num(q['trade_qty']).toStringAsFixed(0)}, '
                                  'Stock ${_num(q['stock_qty']).toStringAsFixed(0)}',
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Current Day Comparison', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 280,
                            child: _dayPrices.isEmpty
                                ? const Center(child: Text('No prices for this date / filters'))
                                : _buildComparisonChart(rashi, chali, pepper, maxAvg * 1.1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('7-Day History (Avg)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 280,
                            child: histDates.isEmpty
                                ? const Center(child: Text('No history data'))
                                : _buildHistoryChart(histDates),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterChipDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String?>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 150,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            isExpanded: true,
            value: value,
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildRatesTable(
    Map<String, dynamic>? rashi,
    Map<String, dynamic>? chali,
    Map<String, dynamic>? pepper,
  ) {
    final rows = <MapEntry<String, Map<String, dynamic>?>>[
      MapEntry('Rashi', rashi),
      MapEntry('Chali', chali),
      MapEntry('Pepper', pepper),
    ];

    return Card(
      elevation: 3,
      child: Table(
        border: TableBorder.all(color: Colors.grey),
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1.5),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(1.5),
        },
        children: [
          const TableRow(
            decoration: BoxDecoration(color: Colors.blueGrey),
            children: [
              _th('Items'),
              _th('Min'),
              _th('Max'),
              _th('Avg'),
            ],
          ),
          for (var i = 0; i < rows.length; i++)
            TableRow(
              decoration: BoxDecoration(
                color: i.isEven ? const Color.fromARGB(255, 85, 99, 108) : const Color.fromARGB(255, 180, 191, 196),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    rows[i].key,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: i.isEven ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                _td(rows[i].value?['min_price'], i.isEven),
                _td(rows[i].value?['max_price'], i.isEven),
                _td(rows[i].value?['avg_price'], i.isEven),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildComparisonChart(
    Map<String, dynamic>? rashi,
    Map<String, dynamic>? chali,
    Map<String, dynamic>? pepper,
    double maxY,
  ) {
    final groups = <BarChartGroupData>[];
    var x = 0;
    void addGroup(Map<String, dynamic>? row, Color color) {
      if (row == null) return;
      groups.addAll([
        BarChartGroupData(x: x++, barRods: [BarChartRodData(toY: _num(row['min_price']), color: color, width: 10, borderRadius: BorderRadius.circular(3))]),
        BarChartGroupData(x: x++, barRods: [BarChartRodData(toY: _num(row['max_price']), color: color, width: 10, borderRadius: BorderRadius.circular(3))]),
        BarChartGroupData(x: x++, barRods: [BarChartRodData(toY: _num(row['avg_price']), color: color, width: 10, borderRadius: BorderRadius.circular(3))]),
      ]);
    }

    addGroup(rashi, Colors.blue);
    addGroup(chali, Colors.red);
    addGroup(pepper, Colors.green);

    return BarChart(
      BarChartData(
        maxY: maxY,
        barGroups: groups,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, m) {
                const labels = ['Min', 'Max', 'Avg'];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(labels[v.toInt() % 3], style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: true),
      ),
    );
  }

  Widget _buildHistoryChart(List<String> dates) {
    final rashi = _historySpots('Rashi', dates);
    final chali = _historySpots('Chali', dates);
    final pepper = _historySpots('Pepper', dates);
    final allY = [...rashi, ...chali, ...pepper].map((s) => s.y);
    final minY = allY.isEmpty ? 30000.0 : allY.reduce((a, b) => a < b ? a : b) * 0.97;
    final maxY = allY.isEmpty ? 70000.0 : allY.reduce((a, b) => a > b ? a : b) * 1.03;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (dates.length - 1).clamp(0, 100).toDouble(),
        minY: minY,
        maxY: maxY,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, m) {
                final i = v.toInt();
                if (i < 0 || i >= dates.length) return const SizedBox.shrink();
                final d = dates[i];
                return Text(d.substring(8), style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, m) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10)),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          if (rashi.isNotEmpty)
            LineChartBarData(spots: rashi, isCurved: true, color: Colors.blue, barWidth: 3, dotData: const FlDotData(show: true)),
          if (chali.isNotEmpty)
            LineChartBarData(spots: chali, isCurved: true, color: Colors.red, barWidth: 3, dotData: const FlDotData(show: true)),
          if (pepper.isNotEmpty)
            LineChartBarData(spots: pepper, isCurved: true, color: Colors.green, barWidth: 3, dotData: const FlDotData(show: true)),
        ],
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: true),
      ),
    );
  }
}

class _th extends StatelessWidget {
  final String text;
  const _th(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }
}

Widget _td(dynamic value, bool lightOnDark) {
  final n = value == null ? '—' : (num.tryParse(value.toString())?.toStringAsFixed(0) ?? value.toString());
  return Padding(
    padding: const EdgeInsets.all(8),
    child: Text(n, style: TextStyle(color: lightOnDark ? Colors.white : Colors.black)),
  );
}
