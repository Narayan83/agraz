import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class RatesComparisonPage extends StatefulWidget {
  const RatesComparisonPage({super.key});

  @override
  State<RatesComparisonPage> createState() => _RatesComparisonPageState();
}

class _RatesComparisonPageState extends State<RatesComparisonPage> {
  DateTime _selectedDate = DateTime.now();

  final List<RateData> rashiRates = [
    RateData('Day 1', 41808, 46699, 44449),
    RateData('Day 2', 41900, 46750, 44325),
    RateData('Day 3', 41750, 46580, 44165),
    RateData('Day 4', 42000, 46800, 44400),
    RateData('Day 5', 41850, 46650, 44250),
    RateData('Day 6', 41950, 46720, 44335),
    RateData('Day 7', 41820, 46680, 44250),
  ];

  final List<RateData> chaliRates = [
    RateData('Day 1', 34999, 42099, 38137),
    RateData('Day 2', 35100, 42150, 38225),
    RateData('Day 3', 35050, 42080, 38165),
    RateData('Day 4', 35200, 42200, 38300),
    RateData('Day 5', 35050, 42150, 38200),
    RateData('Day 6', 35150, 42120, 38235),
    RateData('Day 7', 35020, 42080, 38200),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Reports'),
        centerTitle: true,
        backgroundColor: Colors.blueGrey,
      ),
      body: Container(
        color: Colors.grey[100],
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date Picker
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Text(
                        'Selected Date: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2025),
                          );
                          if (picked != null && picked != _selectedDate) {
                            setState(() {
                              _selectedDate = picked;
                            });
                          }
                        },
                        child: Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Rates Table
              _buildRatesTable(),
              const SizedBox(height: 30),

              // Current Day Comparison Chart
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Current Day Comparison',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 300,
                        child: _buildComparisonChart(
                          rashiData: rashiRates.first,
                          chaliData: chaliRates.first,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // 7-Day History Chart
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '7-Day History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(height: 300, child: _buildHistoryChart()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatesTable() {
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
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Items',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Min',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Max',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Avg',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          TableRow(
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 85, 99, 108),
            ),
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Rashi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  rashiRates.first.min.toString(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  rashiRates.first.max.toString(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  rashiRates.first.avg.toString(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          TableRow(
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 180, 191, 196),
            ),
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Chali',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(chaliRates.first.min.toString()),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(chaliRates.first.max.toString()),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(chaliRates.first.avg.toString()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonChart({
    required RateData rashiData,
    required RateData chaliData,
  }) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 50000,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            // REMOVED problematic parameters - using defaults
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String type = '';
              if (group.x == 0 || group.x == 3) {
                type = 'Min';
              } else if (group.x == 1 || group.x == 4) {
                type = 'Max';
              } else {
                type = 'Avg';
              }
              String name = group.x < 3 ? 'Rashi' : 'Chali';
              return BarTooltipItem(
                '$name - $type\n${rod.toY.toInt()}',
                const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                String text = '';
                final val = value.toInt();
                if (val == 0 || val == 3) {
                  text = 'Min';
                } else if (val == 1 || val == 4) {
                  text = 'Max';
                } else {
                  text = 'Avg';
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(text, style: const TextStyle(fontSize: 12)),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 10000,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(value.toInt().toString());
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine:
              (value) =>
                  FlLine(color: Colors.grey.withValues(alpha: 0.3), strokeWidth: 1),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey),
        ),
        barGroups: [
          // Rashi Min
          BarChartGroupData(
            x: 0,
            barRods: [
              BarChartRodData(
                toY: rashiData.min.toDouble(),
                color: Colors.blue,
                width: 12,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
          // Rashi Max
          BarChartGroupData(
            x: 1,
            barRods: [
              BarChartRodData(
                toY: rashiData.max.toDouble(),
                color: Colors.blue,
                width: 12,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
          // Rashi Avg
          BarChartGroupData(
            x: 2,
            barRods: [
              BarChartRodData(
                toY: rashiData.avg.toDouble(),
                color: Colors.blue,
                width: 12,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
          // Chali Min
          BarChartGroupData(
            x: 3,
            barRods: [
              BarChartRodData(
                toY: chaliData.min.toDouble(),
                color: Colors.red,
                width: 12,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
          // Chali Max
          BarChartGroupData(
            x: 4,
            barRods: [
              BarChartRodData(
                toY: chaliData.max.toDouble(),
                color: Colors.red,
                width: 12,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
          // Chali Avg
          BarChartGroupData(
            x: 5,
            barRods: [
              BarChartRodData(
                toY: chaliData.avg.toDouble(),
                color: Colors.red,
                width: 12,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryChart() {
    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          enabled: true,
          // REMOVED problematic parameters - using defaults
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine:
              (value) =>
                  FlLine(color: Colors.grey.withValues(alpha: 0.3), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(rashiRates[value.toInt()].day);
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 10000,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(value.toInt().toString());
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey),
        ),
        minX: 0,
        maxX: (rashiRates.length - 1).toDouble(),
        minY: 30000,
        maxY: 50000,
        lineBarsData: [
          // Rashi line
          LineChartBarData(
            spots:
                rashiRates.asMap().entries.map((entry) {
                  return FlSpot(
                    entry.key.toDouble(),
                    entry.value.avg.toDouble(),
                  );
                }).toList(),
            isCurved: true,
            color: Colors.blue,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
          // Chali line
          LineChartBarData(
            spots:
                chaliRates.asMap().entries.map((entry) {
                  return FlSpot(
                    entry.key.toDouble(),
                    entry.value.avg.toDouble(),
                  );
                }).toList(),
            isCurved: true,
            color: Colors.red,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}

class RateData {
  final String day;
  final int min;
  final int max;
  final int avg;

  RateData(this.day, this.min, this.max, this.avg);
}
