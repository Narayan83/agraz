import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../l10n/app_l10n.dart';
import 'cm_api.dart';

class CmStockReportPage extends StatefulWidget {
  const CmStockReportPage({super.key});
  @override
  State<CmStockReportPage> createState() => _CmStockReportPageState();
}

class _CmStockReportPageState extends State<CmStockReportPage> {
  bool _loading = true;
  List<dynamic> _rows = [];
  String _loc = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final q = <String, String>{};
      if (_loc.isNotEmpty) q['location_type'] = _loc;
      _rows = await CmApi.list('/contract/stock-report', q: q.isEmpty ? null : q);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(tr('Stock Report')),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                for (final e in [
                  ('', tr('All')),
                  ('own', tr('Own stock')),
                  ('customer', tr('Customer site')),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.$2),
                      selected: _loc == e.$1,
                      onSelected: (_) {
                        setState(() => _loc = e.$1);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                    ? Center(child: Text(tr('No data')))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final r = Map<String, dynamic>.from(_rows[i] as Map);
                          final loc = r['location_type'] == 'customer'
                              ? '${tr('Customer')}: ${r['customer_name'] ?? '-'}'
                              : tr('Own stock');
                          return Material(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            child: ListTile(
                              title: Text(
                                '${r['material_name'] ?? ''} · ${r['quantity']} ${r['unit'] ?? ''}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text('$loc${r['project_name'] != null && '${r['project_name']}'.isNotEmpty ? ' · ${r['project_name']}' : ''}'),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
