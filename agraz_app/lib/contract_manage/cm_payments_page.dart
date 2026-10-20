import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../l10n/app_l10n.dart';
import 'cm_api.dart';

final _day = DateFormat('yyyy-MM-dd');

class CmPaymentsPage extends StatefulWidget {
  const CmPaymentsPage({super.key});
  @override
  State<CmPaymentsPage> createState() => _CmPaymentsPageState();
}

class _CmPaymentsPageState extends State<CmPaymentsPage> {
  bool _loading = true;
  List<dynamic> _rows = [];
  List<dynamic> _projects = [];
  String _kindFilter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final q = <String, String>{};
      if (_kindFilter.isNotEmpty) q['kind'] = _kindFilter;
      _rows = await CmApi.list('/contract/payments', q: q.isEmpty ? null : q);
      _projects = await CmApi.list('/contract/projects');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    var kind = 'receivable';
    var partyType = 'customer';
    int? projectId;
    final partyName = TextEditingController();
    final amount = TextEditingController();
    final paid = TextEditingController(text: '0');
    final notes = TextEditingController();
    final date = TextEditingController(text: _day.format(DateTime.now()));
    final due = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr('Add payment'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: kind,
                  decoration: _d('Kind'),
                  items: [
                    DropdownMenuItem(value: 'customer_advance', child: Text(tr('Customer advance'))),
                    DropdownMenuItem(value: 'customer_receipt', child: Text(tr('Customer receipt'))),
                    DropdownMenuItem(value: 'receivable', child: Text(tr('Receivable (from customer)'))),
                    DropdownMenuItem(value: 'labour_payment', child: Text(tr('Pay labour lead'))),
                    DropdownMenuItem(value: 'labour_extra', child: Text(tr('Extra to lead'))),
                    DropdownMenuItem(value: 'dealer_payment', child: Text(tr('Pay dealer'))),
                    DropdownMenuItem(value: 'payable', child: Text(tr('Payable (to supplier/lead)'))),
                    DropdownMenuItem(value: 'commission', child: Text(tr('Commission'))),
                  ],
                  onChanged: (v) => setLocal(() {
                    kind = v ?? 'customer_advance';
                    if (kind.startsWith('customer') || kind == 'receivable' || kind == 'commission') {
                      partyType = 'customer';
                    } else if (kind.startsWith('labour')) {
                      partyType = 'labour_supplier';
                    } else {
                      partyType = 'dealer';
                    }
                  }),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: partyType,
                  decoration: _d('Party type'),
                  items: const [
                    DropdownMenuItem(value: 'customer', child: Text('customer')),
                    DropdownMenuItem(value: 'dealer', child: Text('dealer')),
                    DropdownMenuItem(value: 'labour_supplier', child: Text('labour_supplier')),
                  ],
                  onChanged: (v) => setLocal(() => partyType = v ?? 'customer'),
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
                TextField(controller: partyName, decoration: _d('Party name')),
                const SizedBox(height: 10),
                TextField(controller: amount, keyboardType: TextInputType.number, decoration: _d('Amount')),
                const SizedBox(height: 10),
                TextField(controller: paid, keyboardType: TextInputType.number, decoration: _d('Paid amount')),
                const SizedBox(height: 10),
                TextField(controller: date, decoration: _d('Entry date')),
                const SizedBox(height: 10),
                TextField(controller: due, decoration: _d('Due date (future)')),
                const SizedBox(height: 10),
                TextField(controller: notes, decoration: _d('Notes')),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    try {
                      final amt = double.tryParse(amount.text) ?? 0;
                      final pd = double.tryParse(paid.text) ?? 0;
                      await CmApi.post('/contract/payments', {
                        'kind': kind,
                        'party_type': partyType,
                        'party_name': partyName.text.trim(),
                        'project_id': projectId,
                        'entry_date': date.text.trim(),
                        if (due.text.trim().isNotEmpty) 'due_date': due.text.trim(),
                        'amount': amt,
                        'paid_amount': pd,
                        'status': pd >= amt && amt > 0 ? 'closed' : 'open',
                        'notes': notes.text.trim(),
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
    partyName.dispose();
    amount.dispose();
    paid.dispose();
    notes.dispose();
    date.dispose();
    due.dispose();
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
      appBar: AppBar(
        title: Text(tr('Payments')),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                for (final e in [
                  ('', tr('All')),
                  ('customer_advance', tr('Customer advance')),
                  ('customer_receipt', tr('Customer receipt')),
                  ('labour_payment', tr('Pay labour lead')),
                  ('labour_extra', tr('Extra to lead')),
                  ('dealer_payment', tr('Pay dealer')),
                  ('commission', tr('Commission')),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.$2),
                      selected: _kindFilter == e.$1,
                      onSelected: (_) {
                        setState(() => _kindFilter = e.$1);
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
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                          itemCount: _rows.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final r = Map<String, dynamic>.from(_rows[i] as Map);
                            return Material(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              child: ListTile(
                                title: Text(
                                  '${r['kind']} · ₹${r['amount']} (${r['status']})',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${r['party_type'] ?? ''} ${r['party_name'] ?? ''} · paid ₹${r['paid_amount'] ?? 0}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    await CmApi.delete('/contract/payments/${r['id']}');
                                    _load();
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
