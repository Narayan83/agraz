import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../l10n/app_l10n.dart';
import 'cm_api.dart';
import 'cm_project_workspace.dart';

final _dayFmt = DateFormat('yyyy-MM-dd');

const kProjectStatuses = ['planned', 'active', 'on_hold', 'completed', 'cancelled'];

/// Full projects list with customer mapping, dates, status, edit/delete.
class CmProjectListPage extends StatefulWidget {
  const CmProjectListPage({super.key});

  @override
  State<CmProjectListPage> createState() => _CmProjectListPageState();
}

class _CmProjectListPageState extends State<CmProjectListPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _rows = [];
  List<dynamic> _customers = [];

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
      _customers = await CmApi.list('/contract/customers');
      _rows = await CmApi.list('/contract/projects');
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _custName(dynamic id) {
    if (id == null) return tr('No customer');
    for (final c in _customers) {
      final m = Map<String, dynamic>.from(c as Map);
      if (m['id'] == id) return '${m['name']}';
    }
    return '#$id';
  }

  String _d(dynamic v) {
    if (v == null) return '—';
    final s = v.toString();
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  Future<void> _openForm({Map? edit}) async {
    final name = TextEditingController(text: edit?['name']?.toString() ?? '');
    final code = TextEditingController(text: edit?['code']?.toString() ?? '');
    final location = TextEditingController(text: edit?['location']?.toString() ?? '');
    final notes = TextEditingController(text: edit?['notes']?.toString() ?? '');
    final estimate = TextEditingController(text: edit?['estimate_amt']?.toString() ?? '0');
    final contract = TextEditingController(text: edit?['contract_amt']?.toString() ?? '0');
    final commission = TextEditingController(text: edit?['commission_pct']?.toString() ?? '0');
    var status = (edit?['status']?.toString().isNotEmpty == true) ? edit!['status'].toString() : 'active';
    int? customerId = edit?['customer_id'] is num ? (edit!['customer_id'] as num).toInt() : null;
    DateTime? start = _parseDate(edit?['start_date']);
    DateTime? end = _parseDate(edit?['end_date']);

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
                Text(edit == null ? tr('New project') : tr('Edit project'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextField(controller: name, decoration: _dec(tr('Project name'))),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  initialValue: customerId,
                  decoration: _dec(tr('Customer')),
                  items: [
                    DropdownMenuItem(value: null, child: Text(tr('Select customer'))),
                    ..._customers.map((c) {
                      final m = Map<String, dynamic>.from(c as Map);
                      return DropdownMenuItem(value: (m['id'] as num).toInt(), child: Text('${m['name']}'));
                    }),
                  ],
                  onChanged: (v) => setLocal(() => customerId = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: _dec(tr('Status')),
                  items: kProjectStatuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(tr(s))))
                      .toList(),
                  onChanged: (v) => setLocal(() => status = v ?? 'active'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: start ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setLocal(() => start = d);
                        },
                        icon: const Icon(Icons.event),
                        label: Text('${tr('Start')}: ${start == null ? '—' : _dayFmt.format(start!)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: end ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (d != null) setLocal(() => end = d);
                        },
                        icon: const Icon(Icons.event_available),
                        label: Text('${tr('End')}: ${end == null ? '—' : _dayFmt.format(end!)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(controller: code, decoration: _dec(tr('Code'))),
                const SizedBox(height: 10),
                TextField(controller: location, decoration: _dec(tr('Location'))),
                const SizedBox(height: 10),
                TextField(controller: contract, keyboardType: TextInputType.number, decoration: _dec(tr('Contract amount'))),
                const SizedBox(height: 10),
                TextField(controller: estimate, keyboardType: TextInputType.number, decoration: _dec(tr('Estimate amount'))),
                const SizedBox(height: 10),
                TextField(controller: commission, keyboardType: TextInputType.number, decoration: _dec(tr('Commission %'))),
                const SizedBox(height: 10),
                TextField(controller: notes, maxLines: 2, decoration: _dec(tr('Notes'))),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () async {
                    if (name.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(tr('Project name is required'))));
                      return;
                    }
                    if (customerId == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(tr('Select customer for this project'))));
                      return;
                    }
                    try {
                      final body = {
                        'name': name.text.trim(),
                        'code': code.text.trim(),
                        'location': location.text.trim(),
                        'status': status,
                        'customer_id': customerId,
                        'estimate_amt': double.tryParse(estimate.text) ?? 0,
                        'contract_amt': double.tryParse(contract.text) ?? 0,
                        'commission_pct': double.tryParse(commission.text) ?? 0,
                        'notes': notes.text.trim(),
                        if (start != null) 'start_date': _dayFmt.format(start!),
                        if (end != null) 'end_date': _dayFmt.format(end!),
                      };
                      if (edit == null) {
                        await CmApi.post('/contract/projects', body);
                      } else {
                        await CmApi.put('/contract/projects/${edit['id']}', body);
                      }
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
    name.dispose();
    code.dispose();
    location.dispose();
    notes.dispose();
    estimate.dispose();
    contract.dispose();
    commission.dispose();
    if (ok == true) _load();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(tr('Projects')),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: Text(tr('New project')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _rows.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          tr('Create a customer first, then create a project mapped to that customer. Open the project to send labour, record advances, stock and payments.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: _rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final r = Map<String, dynamic>.from(_rows[i] as Map);
                          return Material(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CmProjectWorkspacePage(projectId: (r['id'] as num).toInt()),
                                  ),
                                );
                                _load();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text('${r['name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.primarySoft,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(tr('${r['status'] ?? 'active'}'), style: const TextStyle(fontSize: 12)),
                                        ),
                                        PopupMenuButton<String>(
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
                                                    TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Cancel'))),
                                                    FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(tr('Delete'))),
                                                  ],
                                                ),
                                              );
                                              if (conf == true) {
                                                await CmApi.delete('/contract/projects/${r['id']}');
                                                _load();
                                              }
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            PopupMenuItem(value: 'edit', child: Text(tr('Edit'))),
                                            PopupMenuItem(value: 'delete', child: Text(tr('Delete'))),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${tr('Customer')}: ${_custName(r['customer_id'])}',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                    Text('${tr('Start')}: ${_d(r['start_date'])}  ·  ${tr('End')}: ${_d(r['end_date'])}',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                                    Text('₹${r['contract_amt'] ?? 0} · ${r['location'] ?? ''}',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text(tr('Tap to open project workspace'),
                                        style: TextStyle(color: AppColors.primary, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
