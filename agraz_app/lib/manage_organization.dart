import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'auth_token.dart';
import 'feedback_fab.dart';
import 'l10n/app_l10n.dart';
import 'login.dart';
import 'organization_report.dart';

class ManageOrganizationPage extends StatefulWidget {
  const ManageOrganizationPage({super.key});

  @override
  State<ManageOrganizationPage> createState() => _ManageOrganizationPageState();
}

class _ManageOrganizationPageState extends State<ManageOrganizationPage> {
  final _api = ApiService();
  final _amountCtrl = TextEditingController();
  final _narrationCtrl = TextEditingController();

  List<Map<String, dynamic>> _orgs = [];
  List<Map<String, dynamic>> _ledgers = [];
  List<Map<String, dynamic>> _txns = [];
  int _txnTotal = 0;
  int _txnPage = 1;

  int? _orgId;
  int? _ledgerId;
  int? _transferToOrgId;
  String _type = 'Income';
  String _mode = 'Cash';
  DateTime _date = DateTime.now();
  double _income = 0;
  double _expense = 0;
  bool _loading = true;
  bool _saving = false;
  String? _pressedToggle;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _narrationCtrl.dispose();
    super.dispose();
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse('$v');
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  Future<bool> _ensureLogin() async {
    var token = await getAuthToken();
    if (token != null && token.isNotEmpty) return true;
    if (!mounted) return false;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    return ok == true;
  }

  Future<void> _bootstrap() async {
    if (!await _ensureLogin()) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final orgs = await _api.fetchOrganizations();
      final ledgers = await _api.fetchOrgLedgers();
      if (!mounted) return;
      setState(() {
        _orgs = orgs;
        _ledgers = ledgers;
        if (_orgId == null || !_orgs.any((o) => _asInt(o['id']) == _orgId)) {
          _orgId = _asInt(orgs.isNotEmpty ? orgs.first['id'] : null);
        }
        if (_ledgerId == null ||
            !_ledgers.any((l) => _asInt(l['id']) == _ledgerId)) {
          _ledgerId = _asInt(ledgers.isNotEmpty ? ledgers.first['id'] : null);
        }
      });
      await Future.wait([_refreshSummary(), _refreshTxns()]);
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = '$e'.replaceFirst('Exception: ', ''));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_loadError!),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshSummary() async {
    try {
      final s = await _api.fetchOrgSummary(organizationId: _orgId);
      if (!mounted) return;
      setState(() {
        _income = _asDouble(s['income']);
        _expense = _asDouble(s['expense']);
      });
    } catch (_) {}
  }

  Future<void> _refreshTxns() async {
    try {
      final res = await _api.fetchOrgTransactions(
        page: _txnPage,
        limit: 10,
        organizationId: _orgId,
      );
      if (!mounted) return;
      final list = (res['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        _txns = list;
        _txnTotal = res['total'] is int
            ? res['total'] as int
            : int.tryParse('${res['total']}') ?? list.length;
      });
    } catch (_) {}
  }

  Future<void> _showOrgManager() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr('Organizations'), style: AppText.h3),
                  const SizedBox(height: 8),
                  ..._orgs.map((o) {
                    final id = _asInt(o['id']);
                    final name = '${o['name'] ?? ''}';
                    return ListTile(
                      title: Text(name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_rounded),
                            onPressed: () async {
                              final ctrl = TextEditingController(text: name);
                              final ok = await showDialog<bool>(
                                context: ctx,
                                builder: (d) => AlertDialog(
                                  title: Text(tr('Edit Organization')),
                                  content: TextField(
                                    controller: ctrl,
                                    decoration: InputDecoration(
                                      labelText: tr('Name'),
                                    ),
                                    textCapitalization: TextCapitalization.characters,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(d, false),
                                      child: Text(tr('Cancel')),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(d, true),
                                      child: Text(tr('Save')),
                                    ),
                                  ],
                                ),
                              );
                              final n = ctrl.text.trim();
                              ctrl.dispose();
                              if (ok != true || n.isEmpty || id == null) return;
                              try {
                                await _api.updateOrganization(id, n);
                                await _bootstrap();
                                setLocal(() {});
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$e'.replaceFirst('Exception: ', '')),
                                    backgroundColor: AppColors.expense,
                                  ),
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: AppColors.expense),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: ctx,
                                builder: (d) => AlertDialog(
                                  title: Text(tr('Delete Organization')),
                                  content: Text(
                                    tr('Delete "$name"? This cannot be undone.'),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(d, false),
                                      child: Text(tr('Cancel')),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.expense,
                                      ),
                                      onPressed: () => Navigator.pop(d, true),
                                      child: Text(tr('Delete')),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true || id == null) return;
                              try {
                                await _api.deleteOrganization(id);
                                if (_orgId == id) _orgId = null;
                                await _bootstrap();
                                setLocal(() {});
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$e'.replaceFirst('Exception: ', '')),
                                    backgroundColor: AppColors.expense,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      final ctrl = TextEditingController();
                      final ok = await showDialog<bool>(
                        context: ctx,
                        builder: (d) => AlertDialog(
                          title: Text(tr('Add Organization')),
                          content: TextField(
                            controller: ctrl,
                            autofocus: true,
                            decoration: InputDecoration(labelText: tr('Name')),
                            textCapitalization: TextCapitalization.characters,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(d, false),
                              child: Text(tr('Cancel')),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(d, true),
                              child: Text(tr('Add')),
                            ),
                          ],
                        ),
                      );
                      final n = ctrl.text.trim();
                      ctrl.dispose();
                      if (ok != true || n.isEmpty) return;
                      try {
                        await _api.createOrganization(n);
                        await _bootstrap();
                        setLocal(() {});
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$e'.replaceFirst('Exception: ', '')),
                            backgroundColor: AppColors.expense,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: Text(tr('Add Organization')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showLedgerManager() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(tr('Ledgers / Accounts'), style: AppText.h3),
                  Text(
                    tr('Shared across all organizations'),
                    style: AppText.caption,
                  ),
                  const SizedBox(height: 8),
                  ..._ledgers.map((l) {
                    final id = _asInt(l['id']);
                    final name = '${l['name'] ?? ''}';
                    final isSystem = l['is_system'] == true;
                    return ListTile(
                      title: Text(name),
                      subtitle: isSystem ? Text(tr('System')) : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_rounded),
                            onPressed: () async {
                              final ctrl = TextEditingController(text: name);
                              final ok = await showDialog<bool>(
                                context: ctx,
                                builder: (d) => AlertDialog(
                                  title: Text(tr('Edit Ledger')),
                                  content: TextField(
                                    controller: ctrl,
                                    decoration: InputDecoration(
                                      labelText: tr('Name'),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(d, false),
                                      child: Text(tr('Cancel')),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(d, true),
                                      child: Text(tr('Save')),
                                    ),
                                  ],
                                ),
                              );
                              final n = ctrl.text.trim();
                              ctrl.dispose();
                              if (ok != true || n.isEmpty || id == null) return;
                              try {
                                await _api.updateOrgLedger(id, n);
                                await _bootstrap();
                                setLocal(() {});
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$e'.replaceFirst('Exception: ', '')),
                                    backgroundColor: AppColors.expense,
                                  ),
                                );
                              }
                            },
                          ),
                          if (!isSystem)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: AppColors.expense),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: ctx,
                                  builder: (d) => AlertDialog(
                                    title: Text(tr('Delete Ledger')),
                                    content: Text(tr('Delete "$name"?')),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(d, false),
                                        child: Text(tr('Cancel')),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.expense,
                                        ),
                                        onPressed: () => Navigator.pop(d, true),
                                        child: Text(tr('Delete')),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm != true || id == null) return;
                                try {
                                  await _api.deleteOrgLedger(id);
                                  if (_ledgerId == id) _ledgerId = null;
                                  await _bootstrap();
                                  setLocal(() {});
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '$e'.replaceFirst('Exception: ', '')),
                                      backgroundColor: AppColors.expense,
                                    ),
                                  );
                                }
                              },
                            ),
                        ],
                      ),
                    );
                  }),
                  FilledButton.icon(
                    onPressed: () async {
                      final ctrl = TextEditingController();
                      final ok = await showDialog<bool>(
                        context: ctx,
                        builder: (d) => AlertDialog(
                          title: Text(tr('Add Ledger')),
                          content: TextField(
                            controller: ctrl,
                            autofocus: true,
                            decoration: InputDecoration(labelText: tr('Name')),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(d, false),
                              child: Text(tr('Cancel')),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(d, true),
                              child: Text(tr('Add')),
                            ),
                          ],
                        ),
                      );
                      final n = ctrl.text.trim();
                      ctrl.dispose();
                      if (ok != true || n.isEmpty) return;
                      try {
                        await _api.createOrgLedger(n);
                        await _bootstrap();
                        setLocal(() {});
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$e'.replaceFirst('Exception: ', '')),
                            backgroundColor: AppColors.expense,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: Text(tr('Add Ledger')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickTransferOrg() async {
    final others = _orgs.where((o) => _asInt(o['id']) != _orgId).toList();
    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Add another organization first')),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(tr('Transfer to organization')),
        children: others.map((o) {
          final id = _asInt(o['id']);
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, id),
            child: Text('${o['name'] ?? ''}'),
          );
        }).toList(),
      ),
    );
    if (selected != null) setState(() => _transferToOrgId = selected);
  }

  Future<void> _submit() async {
    if (_orgId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Select organization')),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }
    if (_ledgerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Select ledger')),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Please enter a valid amount')),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }
    if (_mode == 'Transfer' && _transferToOrgId == null) {
      await _pickTransferOrg();
      if (_transferToOrgId == null) return;
    }

    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'type': _type,
        'organization_id': _orgId,
        'ledger_id': _ledgerId,
        'transaction_mode': _mode,
        'amount': amount,
        'date': DateFormat('yyyy-MM-dd').format(_date),
        'narration': _narrationCtrl.text.trim(),
      };
      if (_mode == 'Transfer') {
        body['transfer_to_organization_id'] = _transferToOrgId;
      }
      await _api.createOrgTransaction(body);
      if (!mounted) return;
      _amountCtrl.clear();
      _narrationCtrl.clear();
      _transferToOrgId = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Transaction recorded successfully!')),
          backgroundColor: AppColors.income,
        ),
      );
      await Future.wait([_refreshSummary(), _refreshTxns()]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.expense,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _money(dynamic v) {
    final n = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return '₹${NumberFormat('#,##0.##').format(n)}';
  }

  String _orgName(int? id) {
    for (final o in _orgs) {
      if (_asInt(o['id']) == id) return '${o['name'] ?? ''}';
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              icon: Icons.business_rounded,
              title: tr('Manage Organization'),
              subtitle: tr('Org books & ledgers'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: withFeedbackAction(
                  context,
                  menu: 'manage_organization',
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.account_balance_rounded,
                          color: Colors.white),
                      tooltip: tr('Ledgers'),
                      onPressed: _showLedgerManager,
                    ),
                    IconButton(
                      icon: const Icon(Icons.insights_rounded,
                          color: Colors.white),
                      tooltip: tr('Reports'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrganizationReportPage(orgId: _orgId),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _bootstrap,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        children: [
                          if (_loadError != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: AppColors.expense.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.expense.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                _loadError!,
                                style: const TextStyle(
                                    color: AppColors.expense,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: _summaryBox(
                                  tr('Income'),
                                  _money(_income),
                                  AppColors.income,
                                  Icons.trending_up_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _summaryBox(
                                  tr('Expense'),
                                  _money(_expense),
                                  AppColors.expense,
                                  Icons.trending_down_rounded,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _summaryBox(
                                  tr('Balance'),
                                  _money(_income - _expense),
                                  AppColors.primary,
                                  Icons.account_balance_wallet_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        OrganizationReportPage(orgId: _orgId),
                                  ),
                                );
                                if (mounted) {
                                  await Future.wait([
                                    _refreshSummary(),
                                    _refreshTxns(),
                                  ]);
                                }
                              },
                              icon: const Icon(Icons.insights_rounded),
                              label: Text(tr('Organization Reports')),
                            ),
                          ),
                          const SizedBox(height: 10),
                          AppCard(
                            child: Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _orgId,
                                    decoration: InputDecoration(
                                      labelText: tr('Organization'),
                                    ),
                                    items: _orgs
                                        .map((o) {
                                          final id = _asInt(o['id']);
                                          return DropdownMenuItem(
                                            value: id,
                                            child: Text('${o['name'] ?? ''}'),
                                          );
                                        })
                                        .where((e) => e.value != null)
                                        .toList(),
                                    onChanged: (v) async {
                                      setState(() {
                                        _orgId = v;
                                        _transferToOrgId = null;
                                        _txnPage = 1;
                                      });
                                      await Future.wait([
                                        _refreshSummary(),
                                        _refreshTxns(),
                                      ]);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filled(
                                  onPressed: _showOrgManager,
                                  icon: const Icon(Icons.add_rounded),
                                  tooltip: tr('Add Organization'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SectionTitle(
                                  icon: Icons.swap_horiz_rounded,
                                  title: tr('Transaction Type'),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _typeToggle(
                                        'Income',
                                        Icons.trending_up_rounded,
                                        AppColors.income,
                                        AppColors.incomeSoft,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _typeToggle(
                                        'Expense',
                                        Icons.trending_down_rounded,
                                        AppColors.expense,
                                        AppColors.expenseSoft,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  initialValue: _ledgerId,
                                  decoration: InputDecoration(
                                    labelText: tr('Ledger'),
                                    prefixIcon: const Icon(
                                        Icons.account_balance_outlined),
                                  ),
                                  items: _ledgers
                                      .map((l) {
                                        final id = _asInt(l['id']);
                                        return DropdownMenuItem(
                                          value: id,
                                          child: Text('${l['name'] ?? ''}'),
                                        );
                                      })
                                      .where((e) => e.value != null)
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _ledgerId = v),
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  initialValue: _mode,
                                  decoration: InputDecoration(
                                    labelText: tr('Transaction Mode'),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'Cash', child: Text('Cash')),
                                    DropdownMenuItem(
                                        value: 'Transfer',
                                        child: Text('Transfer')),
                                  ],
                                  onChanged: (v) async {
                                    setState(() {
                                      _mode = v ?? 'Cash';
                                      if (_mode != 'Transfer') {
                                        _transferToOrgId = null;
                                      }
                                    });
                                    if (_mode == 'Transfer') {
                                      await _pickTransferOrg();
                                    }
                                  },
                                ),
                                if (_mode == 'Transfer') ...[
                                  const SizedBox(height: 8),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.swap_horiz),
                                    title: Text(
                                      _transferToOrgId == null
                                          ? tr('Select destination organization')
                                          : '${tr('To')}: ${_orgName(_transferToOrgId)}',
                                    ),
                                    trailing: TextButton(
                                      onPressed: _pickTransferOrg,
                                      child: Text(tr('Change')),
                                    ),
                                  ),
                                  Text(
                                    tr('Credit goes to destination Saving Bank'),
                                    style: AppText.caption,
                                  ),
                                ],
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _amountCtrl,
                                  decoration: InputDecoration(
                                    labelText: tr('Amount'),
                                    prefixIcon: const Icon(
                                        Icons.currency_rupee_rounded),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]')),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                      Icons.calendar_today_rounded,
                                      color: AppColors.primary),
                                  title: Text(
                                      DateFormat('dd/MM/yyyy').format(_date)),
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _date,
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2101),
                                    );
                                    if (picked != null) {
                                      setState(() => _date = picked);
                                    }
                                  },
                                ),
                                TextFormField(
                                  controller: _narrationCtrl,
                                  decoration: InputDecoration(
                                    labelText: tr('Narration (optional)'),
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _saving ? null : _submit,
                                    child: _saving
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(tr('Save Transaction')),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(tr('Recent Entries'), style: AppText.h3),
                          const SizedBox(height: 6),
                          ..._txns.map(_txnTile),
                          if (_txnTotal > 10)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: _txnPage <= 1
                                      ? null
                                      : () async {
                                          setState(() => _txnPage--);
                                          await _refreshTxns();
                                        },
                                  icon: const Icon(Icons.chevron_left),
                                ),
                                Text('$_txnPage / ${((_txnTotal + 9) ~/ 10)}'),
                                IconButton(
                                  onPressed: _txnPage * 10 >= _txnTotal
                                      ? null
                                      : () async {
                                          setState(() => _txnPage++);
                                          await _refreshTxns();
                                        },
                                  icon: const Icon(Icons.chevron_right),
                                ),
                              ],
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

  Widget _summaryBox(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _typeToggle(String type, IconData icon, Color color, Color soft) {
    final selected = _type == type;
    final pressed = _pressedToggle == type;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressedToggle = type),
      onTapUp: (_) => setState(() => _pressedToggle = null),
      onTapCancel: () => setState(() => _pressedToggle = null),
      onTap: () => setState(() => _type = type),
      child: AnimatedScale(
        scale: pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? color : soft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? Colors.white : color),
              const SizedBox(width: 8),
              Text(
                type,
                style: TextStyle(
                  color: selected ? Colors.white : color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _txnTile(Map<String, dynamic> t) {
    final type = '${t['type'] ?? ''}';
    final amount = _asDouble(t['amount']);
    final mode = '${t['transaction_mode'] ?? ''}';
    final led = t['ledger'] is Map ? '${t['ledger']['name'] ?? ''}' : '';
    final date = '${t['date'] ?? ''}'.length >= 10
        ? '${t['date']}'.substring(0, 10)
        : '${t['date'] ?? ''}';
    final id = _asInt(t['id']);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('$type · $led'),
        subtitle: Text('$date · $mode'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _money(amount),
              style: TextStyle(
                color: type == 'Income' ? AppColors.income : AppColors.expense,
                fontWeight: FontWeight.w700,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.expense),
              onPressed: id == null
                  ? null
                  : () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (d) => AlertDialog(
                          title: Text(tr('Delete')),
                          content: Text(tr('Delete this transaction?')),
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
                      if (ok != true) return;
                      try {
                        await _api.deleteOrgTransaction(id);
                        await Future.wait([_refreshSummary(), _refreshTxns()]);
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$e'.replaceFirst('Exception: ', '')),
                            backgroundColor: AppColors.expense,
                          ),
                        );
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
