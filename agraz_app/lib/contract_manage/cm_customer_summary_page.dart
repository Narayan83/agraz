import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../l10n/app_l10n.dart';
import 'cm_api.dart';

class CmCustomerSummaryPage extends StatefulWidget {
  const CmCustomerSummaryPage({super.key});
  @override
  State<CmCustomerSummaryPage> createState() => _CmCustomerSummaryPageState();
}

class _CmCustomerSummaryPageState extends State<CmCustomerSummaryPage> {
  bool _loading = true;
  List<dynamic> _customers = [];
  int? _selected;
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() => _loading = true);
    try {
      _customers = await CmApi.list('/contract/customers');
      if (_customers.isNotEmpty) {
        _selected = (_customers.first['id'] as num).toInt();
        await _loadSummary();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSummary() async {
    if (_selected == null) return;
    _summary = await CmApi.get('/contract/customers/$_selected/summary');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final totals = _summary?['totals'] as Map? ?? {};
    final projects = (_summary?['projects'] as List?) ?? [];
    final payments = (_summary?['payments'] as List?) ?? [];
    final stock = (_summary?['stock_at_site'] as List?) ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(tr('Customer Summary')),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _customers.isEmpty
              ? Center(child: Text(tr('No customers yet')))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    DropdownButtonFormField<int>(
                      value: _selected,
                      decoration: InputDecoration(
                        labelText: tr('Customer'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _customers.map((c) {
                        final m = Map<String, dynamic>.from(c as Map);
                        return DropdownMenuItem(
                          value: (m['id'] as num).toInt(),
                          child: Text('${m['name']}'),
                        );
                      }).toList(),
                      onChanged: (v) async {
                        setState(() {
                          _selected = v;
                          _loading = true;
                        });
                        try {
                          await _loadSummary();
                        } finally {
                          if (mounted) setState(() => _loading = false);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _chip(tr('Projects'), '${totals['project_count'] ?? 0}'),
                        _chip(tr('Open receivable'), '₹${totals['receivable_open'] ?? 0}'),
                        _chip(tr('Received'), '₹${totals['receivable_paid'] ?? 0}'),
                        _chip(tr('Commission'), '₹${totals['commission'] ?? 0}'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(tr('Projects'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (projects.isEmpty) Text(tr('No data'), style: TextStyle(color: AppColors.textSecondary)),
                    ...projects.map((p) {
                      final m = Map<String, dynamic>.from(p as Map);
                      return _card('${m['name']}', '${m['status']} · ₹${m['contract_amt'] ?? 0}');
                    }),
                    const SizedBox(height: 16),
                    Text(tr('Payments'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (payments.isEmpty) Text(tr('No data'), style: TextStyle(color: AppColors.textSecondary)),
                    ...payments.map((p) {
                      final m = Map<String, dynamic>.from(p as Map);
                      return _card('${m['kind']} · ₹${m['amount']}', '${m['status']} · paid ₹${m['paid_amount'] ?? 0}');
                    }),
                    const SizedBox(height: 16),
                    Text(tr('Stock at customer site'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (stock.isEmpty) Text(tr('No data'), style: TextStyle(color: AppColors.textSecondary)),
                    ...stock.map((p) {
                      final m = Map<String, dynamic>.from(p as Map);
                      return _card('${m['material_name']}', '${m['quantity']} ${m['unit'] ?? ''}');
                    }),
                  ],
                ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _card(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          dense: true,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle),
        ),
      ),
    );
  }
}
