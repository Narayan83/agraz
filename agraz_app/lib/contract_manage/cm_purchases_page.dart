import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../l10n/app_l10n.dart';
import 'cm_api.dart';

final _day = DateFormat('yyyy-MM-dd');

class CmPurchasesPage extends StatefulWidget {
  const CmPurchasesPage({super.key});
  @override
  State<CmPurchasesPage> createState() => _CmPurchasesPageState();
}

class _CmPurchasesPageState extends State<CmPurchasesPage> {
  bool _loading = true;
  List<dynamic> _rows = [];
  List<dynamic> _dealers = [];
  List<dynamic> _projects = [];
  List<dynamic> _customers = [];
  List<dynamic> _materials = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _rows = await CmApi.list('/contract/purchases');
      _dealers = await CmApi.list('/contract/dealers');
      _projects = await CmApi.list('/contract/projects');
      _customers = await CmApi.list('/contract/customers');
      _materials = await CmApi.list('/contract/materials');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    int? dealerId;
    int? projectId;
    int? customerId;
    int? materialId;
    var stockLoc = 'own';
    final qty = TextEditingController(text: '1');
    final rate = TextEditingController();
    final invoice = TextEditingController();
    final paid = TextEditingController(text: '0');
    final notes = TextEditingController();
    final date = TextEditingController(text: _day.format(DateTime.now()));

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr('Add purchase'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: materialId,
                  decoration: _d('Material'),
                  items: _materials.map((m) {
                    final x = Map<String, dynamic>.from(m as Map);
                    return DropdownMenuItem(value: (x['id'] as num).toInt(), child: Text('${x['name']}'));
                  }).toList(),
                  onChanged: (v) => setLocal(() => materialId = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  value: dealerId,
                  decoration: _d('Dealer'),
                  items: [
                    DropdownMenuItem(value: null, child: Text(tr('None'))),
                    ..._dealers.map((m) {
                      final x = Map<String, dynamic>.from(m as Map);
                      return DropdownMenuItem(value: (x['id'] as num).toInt(), child: Text('${x['name']}'));
                    }),
                  ],
                  onChanged: (v) => setLocal(() => dealerId = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  value: projectId,
                  decoration: _d('Project'),
                  items: [
                    DropdownMenuItem(value: null, child: Text(tr('None'))),
                    ..._projects.map((m) {
                      final x = Map<String, dynamic>.from(m as Map);
                      return DropdownMenuItem(value: (x['id'] as num).toInt(), child: Text('${x['name']}'));
                    }),
                  ],
                  onChanged: (v) => setLocal(() => projectId = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: stockLoc,
                  decoration: _d('Stock location'),
                  items: [
                    DropdownMenuItem(value: 'own', child: Text(tr('Contractor own stock'))),
                    DropdownMenuItem(value: 'customer', child: Text(tr('Customer site stock'))),
                  ],
                  onChanged: (v) => setLocal(() => stockLoc = v ?? 'own'),
                ),
                if (stockLoc == 'customer') ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    value: customerId,
                    decoration: _d('Customer'),
                    items: _customers.map((m) {
                      final x = Map<String, dynamic>.from(m as Map);
                      return DropdownMenuItem(value: (x['id'] as num).toInt(), child: Text('${x['name']}'));
                    }).toList(),
                    onChanged: (v) => setLocal(() => customerId = v),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(controller: qty, keyboardType: TextInputType.number, decoration: _d('Quantity')),
                const SizedBox(height: 10),
                TextField(controller: rate, keyboardType: TextInputType.number, decoration: _d('Rate')),
                const SizedBox(height: 10),
                TextField(controller: paid, keyboardType: TextInputType.number, decoration: _d('Paid amount')),
                const SizedBox(height: 10),
                TextField(controller: invoice, decoration: _d('Invoice no')),
                const SizedBox(height: 10),
                TextField(controller: date, decoration: _d('Purchase date')),
                const SizedBox(height: 10),
                TextField(controller: notes, decoration: _d('Notes')),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    if (materialId == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(tr('Select material'))));
                      return;
                    }
                    try {
                      final q = double.tryParse(qty.text) ?? 0;
                      final r = double.tryParse(rate.text) ?? 0;
                      await CmApi.post('/contract/purchases', {
                        'dealer_id': dealerId,
                        'project_id': projectId,
                        'customer_id': stockLoc == 'customer' ? customerId : null,
                        'purchase_date': date.text.trim(),
                        'invoice_no': invoice.text.trim(),
                        'stock_location': stockLoc,
                        'paid_amount': double.tryParse(paid.text) ?? 0,
                        'notes': notes.text.trim(),
                        'items': [
                          {'material_id': materialId, 'quantity': q, 'rate': r, 'amount': q * r},
                        ],
                      });
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                  child: Text(tr('Save')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    qty.dispose();
    rate.dispose();
    invoice.dispose();
    paid.dispose();
    notes.dispose();
    date.dispose();
    if (ok == true) _load();
  }

  InputDecoration _d(String l) => InputDecoration(
        labelText: tr(l),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(tr('Purchases / Stock')), backgroundColor: AppColors.surface, foregroundColor: AppColors.textPrimary, elevation: 0),
      floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? Center(child: Text(tr('No data')))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                    itemCount: _rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final r = Map<String, dynamic>.from(_rows[i] as Map);
                      final items = (r['items'] as List?) ?? [];
                      return Material(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          title: Text('₹${r['total_amount'] ?? 0} · ${r['stock_location'] ?? ''}',
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${(r['purchase_date'] ?? '').toString().substring(0, (r['purchase_date']?.toString().length ?? 0).clamp(0, 10))} · ${items.length} item(s) · inv ${r['invoice_no'] ?? '-'}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await CmApi.delete('/contract/purchases/${r['id']}');
                              _load();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
