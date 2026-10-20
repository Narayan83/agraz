import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../l10n/app_l10n.dart';
import 'cm_api.dart';

class CmEntityPage extends StatefulWidget {
  final String title;
  final String path;
  final List<String> fields;
  final String Function(Map row) subtitleOf;
  final Map<String, dynamic> Function(
    Map<String, TextEditingController> ctrls,
    Map<String, dynamic> extras,
  )? toBody;
  final List<Widget> Function(
    BuildContext context,
    Map<String, TextEditingController> ctrls,
    void Function(void Function()) setLocal,
    Map<String, dynamic> extras,
  )? extraFields;
  final Future<void> Function(Map<String, dynamic> extras)? loadExtras;

  const CmEntityPage({
    super.key,
    required this.title,
    required this.path,
    required this.fields,
    required this.subtitleOf,
    this.toBody,
    this.extraFields,
    this.loadExtras,
  });

  @override
  State<CmEntityPage> createState() => _CmEntityPageState();
}

class _CmEntityPageState extends State<CmEntityPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _rows = [];
  final Map<String, dynamic> _extras = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.loadExtras != null) await widget.loadExtras!(_extras);
      _rows = await CmApi.list(widget.path);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _label(String f) {
    return f.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
  }

  Future<void> _openForm({Map? edit}) async {
    final ctrls = <String, TextEditingController>{
      for (final f in widget.fields)
        f: TextEditingController(text: edit?[f]?.toString() ?? ''),
    };
    final extras = Map<String, dynamic>.from(_extras);
    if (edit != null) {
      for (final e in edit.entries) {
        extras['edit_${e.key}'] = e.value;
      }
      if (edit['customer_id'] != null) {
        extras['customer_id'] = edit['customer_id'] is num
            ? (edit['customer_id'] as num).toInt()
            : edit['customer_id'];
      }
      if (edit['supplier_id'] != null) {
        extras['supplier_id'] = edit['supplier_id'] is num
            ? (edit['supplier_id'] as num).toInt()
            : edit['supplier_id'];
      }
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      edit == null ? tr('Add') : tr('Edit'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    ...widget.fields.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextField(
                            controller: ctrls[f],
                            decoration: InputDecoration(
                              labelText: tr(_label(f)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        )),
                    if (widget.extraFields != null)
                      ...widget.extraFields!(ctx, ctrls, setLocal, extras),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () async {
                        try {
                          final body = widget.toBody?.call(ctrls, extras) ??
                              {
                                for (final f in widget.fields)
                                  f: ctrls[f]!.text.trim(),
                              };
                          if (edit == null) {
                            await CmApi.post(widget.path, body);
                          } else {
                            await CmApi.put('${widget.path}/${edit['id']}', body);
                          }
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('$e')),
                            );
                          }
                        }
                      },
                      child: Text(tr('Save')),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    for (final c in ctrls.values) {
      c.dispose();
    }
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(tr(widget.title)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
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
                          return Material(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            child: ListTile(
                              title: Text(
                                r['name']?.toString() ?? '#${r['id']}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(widget.subtitleOf(r)),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'edit') {
                                    await _openForm(edit: r);
                                  } else if (v == 'delete') {
                                    final conf = await showDialog<bool>(
                                      context: context,
                                      builder: (d) => AlertDialog(
                                        title: Text(tr('Delete')),
                                        content: Text(tr('Are you sure?')),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(d, false),
                                            child: Text(tr('Cancel')),
                                          ),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(d, true),
                                            child: Text(tr('Delete')),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (conf == true) {
                                      await CmApi.delete('${widget.path}/${r['id']}');
                                      _load();
                                    }
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
    );
  }
}

InputDecoration _dec(String label) => InputDecoration(
      labelText: tr(label),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );

double _num(TextEditingController? c) =>
    double.tryParse((c?.text ?? '').replaceAll(',', '').trim()) ?? 0;

class CmProjectsPage extends StatelessWidget {
  const CmProjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CmEntityPage(
      title: 'Projects',
      path: '/contract/projects',
      fields: const ['name', 'code', 'location', 'status', 'notes'],
      subtitleOf: (r) =>
          '${r['location'] ?? ''} · ${r['status'] ?? ''} · ₹${r['contract_amt'] ?? 0}',
      loadExtras: (extras) async {
        extras['customers'] = await CmApi.list('/contract/customers');
      },
      extraFields: (ctx, ctrls, setLocal, extras) {
        ctrls.putIfAbsent(
          'estimate_amt',
          () => TextEditingController(text: extras['edit_estimate_amt']?.toString() ?? ''),
        );
        ctrls.putIfAbsent(
          'contract_amt',
          () => TextEditingController(text: extras['edit_contract_amt']?.toString() ?? ''),
        );
        ctrls.putIfAbsent(
          'commission_pct',
          () => TextEditingController(text: extras['edit_commission_pct']?.toString() ?? ''),
        );
        final customers = (extras['customers'] as List?) ?? [];
        final selected = extras['customer_id'] as int?;
        return [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<int?>(
              value: selected,
              decoration: _dec('Customer'),
              items: [
                DropdownMenuItem(value: null, child: Text(tr('None'))),
                ...customers.map((c) {
                  final m = Map<String, dynamic>.from(c as Map);
                  return DropdownMenuItem(
                    value: (m['id'] as num?)?.toInt(),
                    child: Text('${m['name']}'),
                  );
                }),
              ],
              onChanged: (v) => setLocal(() => extras['customer_id'] = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(controller: ctrls['estimate_amt'], keyboardType: TextInputType.number, decoration: _dec('Estimate amount')),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(controller: ctrls['contract_amt'], keyboardType: TextInputType.number, decoration: _dec('Contract amount')),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(controller: ctrls['commission_pct'], keyboardType: TextInputType.number, decoration: _dec('Commission %')),
          ),
        ];
      },
      toBody: (c, extras) => {
        'name': c['name']!.text.trim(),
        'code': c['code']!.text.trim(),
        'location': c['location']!.text.trim(),
        'status': c['status']!.text.trim().isEmpty ? 'active' : c['status']!.text.trim(),
        'notes': c['notes']!.text.trim(),
        'customer_id': extras['customer_id'],
        'estimate_amt': _num(c['estimate_amt']),
        'contract_amt': _num(c['contract_amt']),
        'commission_pct': _num(c['commission_pct']),
      },
    );
  }
}

class CmCustomersPage extends StatelessWidget {
  const CmCustomersPage({super.key});
  @override
  Widget build(BuildContext context) {
    return CmEntityPage(
      title: 'Customers',
      path: '/contract/customers',
      fields: const ['name', 'mobile', 'village', 'address', 'notes'],
      subtitleOf: (r) => '${r['mobile'] ?? ''} · ${r['village'] ?? ''}',
    );
  }
}

class CmDealersPage extends StatelessWidget {
  const CmDealersPage({super.key});
  @override
  Widget build(BuildContext context) {
    return CmEntityPage(
      title: 'Dealers',
      path: '/contract/dealers',
      fields: const ['name', 'mobile', 'material', 'address', 'notes'],
      subtitleOf: (r) => '${r['material'] ?? ''} · ${r['mobile'] ?? ''}',
    );
  }
}

class CmLabourSuppliersPage extends StatelessWidget {
  const CmLabourSuppliersPage({super.key});
  @override
  Widget build(BuildContext context) {
    return CmEntityPage(
      title: 'Labour Suppliers',
      path: '/contract/labour-suppliers',
      fields: const ['name', 'mobile', 'address', 'notes'],
      subtitleOf: (r) => '${r['mobile'] ?? ''}',
    );
  }
}

class CmLaboursPage extends StatelessWidget {
  const CmLaboursPage({super.key});
  @override
  Widget build(BuildContext context) {
    return CmEntityPage(
      title: 'Labours',
      path: '/contract/labours',
      fields: const ['name', 'mobile', 'skill', 'notes'],
      subtitleOf: (r) => '${r['skill'] ?? ''} · ₹${r['daily_wage'] ?? 0}/day · lead #${r['supplier_id'] ?? ''}',
      loadExtras: (extras) async {
        extras['suppliers'] = await CmApi.list('/contract/labour-suppliers');
      },
      extraFields: (ctx, ctrls, setLocal, extras) {
        ctrls.putIfAbsent(
          'daily_wage',
          () => TextEditingController(text: extras['edit_daily_wage']?.toString() ?? ''),
        );
        final suppliers = (extras['suppliers'] as List?) ?? [];
        final selected = extras['supplier_id'] as int? ??
            (extras['edit_supplier_id'] is num
                ? (extras['edit_supplier_id'] as num).toInt()
                : null);
        return [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<int?>(
              value: selected,
              decoration: _dec('Labour supplier'),
              items: suppliers.map((c) {
                final m = Map<String, dynamic>.from(c as Map);
                return DropdownMenuItem(
                  value: (m['id'] as num?)?.toInt(),
                  child: Text('${m['name']}'),
                );
              }).toList(),
              onChanged: (v) => setLocal(() => extras['supplier_id'] = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: ctrls['daily_wage'],
              keyboardType: TextInputType.number,
              decoration: _dec('Daily wage'),
            ),
          ),
        ];
      },
      toBody: (c, extras) => {
        'name': c['name']!.text.trim(),
        'mobile': c['mobile']!.text.trim(),
        'skill': c['skill']!.text.trim(),
        'notes': c['notes']!.text.trim(),
        'supplier_id': extras['supplier_id'] ?? 0,
        'daily_wage': _num(c['daily_wage']),
      },
    );
  }
}

class CmMaterialsPage extends StatelessWidget {
  const CmMaterialsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return CmEntityPage(
      title: 'Materials',
      path: '/contract/materials',
      fields: const ['name', 'unit', 'category', 'notes'],
      subtitleOf: (r) => '${r['category'] ?? ''} · ${r['unit'] ?? ''}',
    );
  }
}
