import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../l10n/app_l10n.dart';
import 'cm_api.dart';

final _day = DateFormat('yyyy-MM-dd');

/// End-to-end project workspace: answers labour / money / stock questions.
class CmProjectWorkspacePage extends StatefulWidget {
  final int projectId;
  const CmProjectWorkspacePage({super.key, required this.projectId});

  @override
  State<CmProjectWorkspacePage> createState() => _CmProjectWorkspacePageState();
}

class _CmProjectWorkspacePageState extends State<CmProjectWorkspacePage> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _ledger;
  List<dynamic> _suppliers = [];
  List<dynamic> _materials = [];
  List<dynamic> _audits = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _ledger = await CmApi.get('/contract/projects/${widget.projectId}/ledger');
      _suppliers = await CmApi.list('/contract/labour-suppliers');
      _materials = await CmApi.list('/contract/materials');
      final aud = await CmApi.list('/contract/audit-logs', q: {'limit': '80'});
      _audits = aud.where((a) {
        final m = Map<String, dynamic>.from(a as Map);
        final et = '${m['entity_type']}';
        final eid = m['entity_id'];
        if (et == 'project' && eid == widget.projectId) return true;
        // show related txn audits too (loose filter by summary containing project id)
        return '${m['summary']}'.contains('#${widget.projectId}') ||
            '${m['summary']}'.contains('project #${widget.projectId}');
      }).toList();
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> get _proj => Map<String, dynamic>.from((_ledger?['project'] as Map?) ?? {});
  Map<String, dynamic> get _tot => Map<String, dynamic>.from((_ledger?['totals'] as Map?) ?? {});
  Map<String, dynamic>? get _cust {
    final c = _ledger?['customer'];
    if (c is Map) return Map<String, dynamic>.from(c);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_proj['name']?.toString() ?? tr('Project')),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            Tab(text: tr('Overview')),
            Tab(text: tr('Labour')),
            Tab(text: tr('Payments')),
            Tab(text: tr('Stock')),
            Tab(text: tr('Audit')),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _overviewTab(),
                    _labourTab(),
                    _paymentsTab(),
                    _stockTab(),
                    _auditTab(),
                  ],
                ),
    );
  }

  Widget _chip(String label, String value, {Color? color}) {
    return Container(
      width: 158,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _overviewTab() {
    final t = _tot;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${tr('Customer')}: ${_cust?['name'] ?? '—'} · ${_cust?['mobile'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        Text('${tr('Status')}: ${_proj['status']} · ${tr('Start')}: ${_d(_proj['start_date'])} · ${tr('End')}: ${_d(_proj['end_date'])}',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _chip(tr('Contract'), '₹${t['contract_amt'] ?? 0}'),
            _chip(tr('Customer advance'), '₹${t['customer_advance'] ?? 0}', color: AppColors.income),
            _chip(tr('Received from customer'), '₹${t['customer_received'] ?? 0}', color: AppColors.income),
            _chip(tr('Open receivable'), '₹${t['open_receivable'] ?? 0}', color: AppColors.warning),
            _chip(tr('Men labour days'), '${t['men_labour_days'] ?? 0}'),
            _chip(tr('Women labour days'), '${t['women_labour_days'] ?? 0}'),
            _chip(tr('Labour amount'), '₹${t['labour_amount'] ?? 0}'),
            _chip(tr('Labour paid'), '₹${t['labour_paid'] ?? 0}'),
            _chip(tr('Labour balance'), '₹${t['labour_balance'] ?? 0}', color: AppColors.expense),
            _chip(tr('Extra to labour/lead'), '₹${t['labour_extra'] ?? 0}'),
            _chip(tr('Paid to dealers'), '₹${t['dealer_paid'] ?? 0}'),
            _chip(tr('Paid to labour leads'), '₹${t['labour_lead_paid'] ?? 0}'),
            _chip(tr('Material purchase'), '₹${t['purchase_total'] ?? 0}'),
            _chip(tr('Commission'), '₹${t['commission'] ?? 0}'),
          ],
        ),
        const SizedBox(height: 20),
        Text(tr('How to run this project'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 8),
        Text(
          tr('1) Send labour to site (men/women, rates, days)\n2) Record customer advance / receipts\n3) Buy stock (own yard or customer site) and issue to site\n4) Pay dealers and labour leads; add extras if needed\n5) Check Overview totals anytime'),
          style: TextStyle(color: AppColors.textSecondary, height: 1.45),
        ),
      ],
    );
  }

  Widget _labourTab() {
    final rows = (_ledger?['labour_works'] as List?) ?? [];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(child: Text(tr('Labour sent to this site'), style: const TextStyle(fontWeight: FontWeight.w700))),
              FilledButton.icon(
                onPressed: _addLabourWork,
                icon: const Icon(Icons.add, size: 18),
                label: Text(tr('Send labour')),
              ),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? Center(child: Text(tr('No labour deployed yet')))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = Map<String, dynamic>.from(rows[i] as Map);
                    return Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        title: Text(
                          '${_d(r['work_date'])} · ♂${r['men_count']} @₹${r['men_rate']} · ♀${r['women_count']} @₹${r['women_rate']}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                        ),
                        subtitle: Text(
                          '${tr('Days')}: ${r['days_worked']} · ${tr('Amount')}: ₹${r['amount']} · ${tr('Paid')}: ₹${r['paid_amount']} · ${tr('Extra')}: ₹${r['extra_paid']}\n${tr('Lead')} #${r['supplier_id']} · ${r['status']}',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'edit') {
                              await _addLabourWork(edit: r);
                            } else if (v == 'delete') {
                              await CmApi.delete('/contract/labour-works/${r['id']}');
                              _load();
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: Text(tr('Edit'))),
                            PopupMenuItem(value: 'delete', child: Text(tr('Delete'))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _addLabourWork({Map? edit}) async {
    int? supplierId = edit?['supplier_id'] is num ? (edit!['supplier_id'] as num).toInt() : null;
    final men = TextEditingController(text: '${edit?['men_count'] ?? 0}');
    final women = TextEditingController(text: '${edit?['women_count'] ?? 0}');
    final menRate = TextEditingController(text: '${edit?['men_rate'] ?? 0}');
    final womenRate = TextEditingController(text: '${edit?['women_rate'] ?? 0}');
    final days = TextEditingController(text: '${edit?['days_worked'] ?? 1}');
    final paid = TextEditingController(text: '${edit?['paid_amount'] ?? 0}');
    final extra = TextEditingController(text: '${edit?['extra_paid'] ?? 0}');
    final notes = TextEditingController(text: edit?['notes']?.toString() ?? '');
    var status = edit?['status']?.toString() ?? 'open';
    var workDate = _parseDate(edit?['work_date']) ?? DateTime.now();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr('Send labour to site'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: supplierId,
                  decoration: _dec(tr('Labour supplier / lead')),
                  items: _suppliers.map((s) {
                    final m = Map<String, dynamic>.from(s as Map);
                    return DropdownMenuItem(value: (m['id'] as num).toInt(), child: Text('${m['name']}'));
                  }).toList(),
                  onChanged: (v) => setLocal(() => supplierId = v),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () async {
                    final d = await showDatePicker(context: ctx, initialDate: workDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (d != null) setLocal(() => workDate = d);
                  },
                  child: Text('${tr('Work date')}: ${_day.format(workDate)}'),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: men, keyboardType: TextInputType.number, decoration: _dec(tr('Men count')))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: menRate, keyboardType: TextInputType.number, decoration: _dec(tr('Men rate')))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: women, keyboardType: TextInputType.number, decoration: _dec(tr('Women count')))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: womenRate, keyboardType: TextInputType.number, decoration: _dec(tr('Women rate')))),
                ]),
                const SizedBox(height: 10),
                TextField(controller: days, keyboardType: TextInputType.number, decoration: _dec(tr('Days worked'))),
                const SizedBox(height: 10),
                TextField(controller: paid, keyboardType: TextInputType.number, decoration: _dec(tr('Paid to lead now'))),
                const SizedBox(height: 10),
                TextField(controller: extra, keyboardType: TextInputType.number, decoration: _dec(tr('Extra paid'))),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: _dec(tr('Status')),
                  items: ['open', 'partial', 'closed'].map((s) => DropdownMenuItem(value: s, child: Text(tr(s)))).toList(),
                  onChanged: (v) => setLocal(() => status = v ?? 'open'),
                ),
                const SizedBox(height: 10),
                TextField(controller: notes, decoration: _dec(tr('Notes'))),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    if (supplierId == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(tr('Select labour lead'))));
                      return;
                    }
                    try {
                      final body = {
                        'project_id': widget.projectId,
                        'supplier_id': supplierId,
                        'work_date': _day.format(workDate),
                        'men_count': int.tryParse(men.text) ?? 0,
                        'women_count': int.tryParse(women.text) ?? 0,
                        'men_rate': double.tryParse(menRate.text) ?? 0,
                        'women_rate': double.tryParse(womenRate.text) ?? 0,
                        'days_worked': double.tryParse(days.text) ?? 1,
                        'paid_amount': double.tryParse(paid.text) ?? 0,
                        'extra_paid': double.tryParse(extra.text) ?? 0,
                        'status': status,
                        'notes': notes.text.trim(),
                      };
                      if (edit == null) {
                        await CmApi.post('/contract/labour-works', body);
                      } else {
                        await CmApi.put('/contract/labour-works/${edit['id']}', body);
                      }
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
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
    men.dispose();
    women.dispose();
    menRate.dispose();
    womenRate.dispose();
    days.dispose();
    paid.dispose();
    extra.dispose();
    notes.dispose();
    if (ok == true) _load();
  }

  Widget _paymentsTab() {
    final rows = (_ledger?['payments'] as List?) ?? [];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: () => _addPayment(kind: 'customer_advance', partyType: 'customer'), child: Text(tr('Customer advance'))),
              FilledButton.tonal(onPressed: () => _addPayment(kind: 'customer_receipt', partyType: 'customer'), child: Text(tr('Customer receipt'))),
              OutlinedButton(onPressed: () => _addPayment(kind: 'labour_payment', partyType: 'labour_supplier'), child: Text(tr('Pay labour lead'))),
              OutlinedButton(onPressed: () => _addPayment(kind: 'labour_extra', partyType: 'labour_supplier'), child: Text(tr('Extra to lead'))),
              OutlinedButton(onPressed: () => _addPayment(kind: 'dealer_payment', partyType: 'dealer'), child: Text(tr('Pay dealer'))),
              OutlinedButton(onPressed: () => _addPayment(kind: 'commission', partyType: 'customer'), child: Text(tr('Commission'))),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? Center(child: Text(tr('No payments yet')))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = Map<String, dynamic>.from(rows[i] as Map);
                    return Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        title: Text('${r['kind']} · ₹${r['amount']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${_d(r['entry_date'])} · ${r['party_type']} ${r['party_name'] ?? ''} · paid ₹${r['paid_amount']} · ${r['status']}'),
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
      ],
    );
  }

  Future<void> _addPayment({required String kind, required String partyType}) async {
    final partyName = TextEditingController(text: _cust?['name']?.toString() ?? '');
    final amount = TextEditingController();
    final paid = TextEditingController();
    final notes = TextEditingController();
    var date = DateTime.now();
    DateTime? due;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${tr('Add')} $kind', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextField(controller: partyName, decoration: _dec(tr('Party name'))),
                const SizedBox(height: 10),
                TextField(controller: amount, keyboardType: TextInputType.number, decoration: _dec(tr('Amount'))),
                const SizedBox(height: 10),
                TextField(controller: paid, keyboardType: TextInputType.number, decoration: _dec(tr('Paid / received now'))),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () async {
                    final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (d != null) setLocal(() => date = d);
                  },
                  child: Text('${tr('Date')}: ${_day.format(date)}'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () async {
                    final d = await showDatePicker(context: ctx, initialDate: due ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (d != null) setLocal(() => due = d);
                  },
                  child: Text('${tr('Due date')}: ${due == null ? '—' : _day.format(due!)}'),
                ),
                const SizedBox(height: 10),
                TextField(controller: notes, decoration: _dec(tr('Notes'))),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    try {
                      final amt = double.tryParse(amount.text) ?? 0;
                      final pd = double.tryParse(paid.text) ?? amt;
                      await CmApi.post('/contract/payments', {
                        'project_id': widget.projectId,
                        'kind': kind,
                        'party_type': partyType,
                        'party_id': partyType == 'customer' ? (_cust == null ? null : _cust!['id']) : null,
                        'party_name': partyName.text.trim(),
                        'entry_date': _day.format(date),
                        if (due != null) 'due_date': _day.format(due!),
                        'amount': amt,
                        'paid_amount': pd,
                        'status': pd >= amt && amt > 0 ? 'closed' : 'open',
                        'notes': notes.text.trim(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
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
    if (ok == true) _load();
  }

  Widget _stockTab() {
    final purchases = (_ledger?['purchases'] as List?) ?? [];
    final issues = (_ledger?['stock_issues'] as List?) ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: Text(tr('Stock for this project'), style: const TextStyle(fontWeight: FontWeight.w700))),
            FilledButton(onPressed: _addPurchase, child: Text(tr('Buy stock'))),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _addIssue, child: Text(tr('Issue / use'))),
          ],
        ),
        const SizedBox(height: 12),
        Text(tr('Purchases'), style: const TextStyle(fontWeight: FontWeight.w600)),
        if (purchases.isEmpty) Text(tr('No purchases'), style: TextStyle(color: AppColors.textSecondary)),
        ...purchases.map((p) {
          final r = Map<String, dynamic>.from(p as Map);
          return ListTile(
            dense: true,
            title: Text('₹${r['total_amount']} · ${r['stock_location']} · ${_d(r['purchase_date'])}'),
            subtitle: Text('${tr('Invoice')}: ${r['invoice_no'] ?? '—'}'),
          );
        }),
        const SizedBox(height: 12),
        Text(tr('Issues / usage'), style: const TextStyle(fontWeight: FontWeight.w600)),
        if (issues.isEmpty) Text(tr('No stock issues'), style: TextStyle(color: AppColors.textSecondary)),
        ...issues.map((p) {
          final r = Map<String, dynamic>.from(p as Map);
          return ListTile(
            dense: true,
            title: Text('${tr('Material')} #${r['material_id']} · ${r['quantity']}'),
            subtitle: Text('${r['from_location']} → ${r['purpose']} · ${_d(r['issue_date'])}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () async {
                await CmApi.delete('/contract/stock-issues/${r['id']}');
                _load();
              },
            ),
          );
        }),
      ],
    );
  }

  Future<void> _addPurchase() async {
    int? materialId;
    int? dealerId;
    var loc = 'customer';
    final qty = TextEditingController(text: '1');
    final rate = TextEditingController();
    final paid = TextEditingController(text: '0');
    final invoice = TextEditingController();
    var date = DateTime.now();
    final dealers = await CmApi.list('/contract/dealers');

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr('Buy stock for project'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: materialId,
                  decoration: _dec(tr('Material')),
                  items: _materials.map((m) {
                    final x = Map<String, dynamic>.from(m as Map);
                    return DropdownMenuItem(value: (x['id'] as num).toInt(), child: Text('${x['name']}'));
                  }).toList(),
                  onChanged: (v) => setLocal(() => materialId = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: loc,
                  decoration: _dec(tr('Where stock is kept')),
                  items: [
                    DropdownMenuItem(value: 'customer', child: Text(tr('At customer site'))),
                    DropdownMenuItem(value: 'own', child: Text(tr('Contractor own yard'))),
                  ],
                  onChanged: (v) => setLocal(() => loc = v ?? 'customer'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  initialValue: dealerId,
                  decoration: _dec(tr('Dealer')),
                  items: [
                    DropdownMenuItem(value: null, child: Text(tr('None'))),
                    ...dealers.map((m) {
                      final x = Map<String, dynamic>.from(m as Map);
                      return DropdownMenuItem(value: (x['id'] as num).toInt(), child: Text('${x['name']}'));
                    }),
                  ],
                  onChanged: (v) => setLocal(() => dealerId = v),
                ),
                const SizedBox(height: 10),
                TextField(controller: qty, keyboardType: TextInputType.number, decoration: _dec(tr('Quantity'))),
                const SizedBox(height: 10),
                TextField(controller: rate, keyboardType: TextInputType.number, decoration: _dec(tr('Rate'))),
                const SizedBox(height: 10),
                TextField(controller: paid, keyboardType: TextInputType.number, decoration: _dec(tr('Paid now'))),
                const SizedBox(height: 10),
                TextField(controller: invoice, decoration: _dec(tr('Invoice no'))),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    if (materialId == null) return;
                    try {
                      final q = double.tryParse(qty.text) ?? 0;
                      final r = double.tryParse(rate.text) ?? 0;
                      await CmApi.post('/contract/purchases', {
                        'project_id': widget.projectId,
                        'customer_id': loc == 'customer' ? (_cust == null ? null : _cust!['id']) : null,
                        'dealer_id': dealerId,
                        'purchase_date': _day.format(date),
                        'invoice_no': invoice.text.trim(),
                        'stock_location': loc,
                        'paid_amount': double.tryParse(paid.text) ?? 0,
                        'items': [
                          {'material_id': materialId, 'quantity': q, 'rate': r, 'amount': q * r},
                        ],
                      });
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
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
    paid.dispose();
    invoice.dispose();
    if (ok == true) _load();
  }

  Future<void> _addIssue() async {
    int? materialId;
    var from = 'customer';
    var purpose = 'site_use';
    final qty = TextEditingController(text: '1');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('Issue / use stock'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: materialId,
                decoration: _dec(tr('Material')),
                items: _materials.map((m) {
                  final x = Map<String, dynamic>.from(m as Map);
                  return DropdownMenuItem(value: (x['id'] as num).toInt(), child: Text('${x['name']}'));
                }).toList(),
                onChanged: (v) => setLocal(() => materialId = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: from,
                decoration: _dec(tr('From')),
                items: [
                  DropdownMenuItem(value: 'customer', child: Text(tr('Customer site'))),
                  DropdownMenuItem(value: 'own', child: Text(tr('Own yard'))),
                ],
                onChanged: (v) => setLocal(() => from = v ?? 'customer'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: purpose,
                decoration: _dec(tr('Purpose')),
                items: [
                  DropdownMenuItem(value: 'site_use', child: Text(tr('Used on site'))),
                  DropdownMenuItem(value: 'transfer_to_customer', child: Text(tr('Transfer to customer site'))),
                  DropdownMenuItem(value: 'return_to_own', child: Text(tr('Return to own yard'))),
                ],
                onChanged: (v) => setLocal(() => purpose = v ?? 'site_use'),
              ),
              const SizedBox(height: 10),
              TextField(controller: qty, keyboardType: TextInputType.number, decoration: _dec(tr('Quantity'))),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  if (materialId == null) return;
                  try {
                    await CmApi.post('/contract/stock-issues', {
                      'project_id': widget.projectId,
                      'material_id': materialId,
                      'customer_id': _cust?['id'],
                      'issue_date': _day.format(DateTime.now()),
                      'quantity': double.tryParse(qty.text) ?? 0,
                      'from_location': from,
                      'purpose': purpose,
                    });
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
                  }
                },
                child: Text(tr('Save')),
              ),
            ],
          ),
        ),
      ),
    );
    qty.dispose();
    if (ok == true) _load();
  }

  Widget _auditTab() {
    if (_audits.isEmpty) {
      return Center(child: Text(tr('No audit logs yet')));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _audits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = Map<String, dynamic>.from(_audits[i] as Map);
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            title: Text('${r['action']} · ${r['entity_type']} #${r['entity_id']}', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${r['summary']}\n${_d(r['created_at'])}'),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  String _d(dynamic v) {
    if (v == null) return '—';
    final s = v.toString();
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.length < 10) return null;
    return DateTime.tryParse(s.substring(0, 10));
  }

  InputDecoration _dec(String l) => InputDecoration(
        labelText: l,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
}
