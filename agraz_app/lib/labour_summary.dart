import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'feedback_fab.dart';
import 'labor_categories.dart';
import 'labour_export.dart';
import 'l10n/app_l10n.dart';

String laborNumberOfLabourText(dynamic n) =>
    '${n ?? 0} ${tr('number of labour')}';

String formatLaborHours(double n) => n == n.roundToDouble()
    ? n.toStringAsFixed(0)
    : n.toStringAsFixed(1);

class LaborTotals {
  final double work;
  final double paid;
  final double hours;
  const LaborTotals({this.work = 0, this.paid = 0, this.hours = 0});
  double get net => work - paid;
}

double _asLaborNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

DateTime? _laborDay(dynamic v) {
  try {
    final d = DateTime.parse(v.toString());
    return DateTime(d.year, d.month, d.day);
  } catch (_) {
    return null;
  }
}

/// Work credit minus lump-sum payments. Hours count labour only, not payments.
/// When [applyAccountReset] is true, the latest tally/opening row on or before
/// [to] becomes the new starting balance and earlier rows are ignored.
LaborTotals summarizeLaborEntries(
  Iterable<Map<String, dynamic>> entries, {
  DateTime? from,
  DateTime? to,
  bool applyAccountReset = false,
}) {
  final list = entries.toList();
  final fromD =
      from == null ? null : DateTime(from.year, from.month, from.day);
  final toD = to == null ? null : DateTime(to.year, to.month, to.day);

  DateTime? resetDay;
  var resetId = 0;
  var seedWork = 0.0, seedPaid = 0.0;
  if (applyAccountReset) {
    for (final e in list) {
      if (!laborIsResetKind(e['entry_kind']?.toString())) continue;
      final d = _laborDay(e['date']);
      if (d == null) continue;
      // Never apply an opening/tally that is after the summary end date.
      if (toD != null && d.isAfter(toD)) continue;
      final id = _laborId(e);
      if (resetDay == null ||
          d.isAfter(resetDay) ||
          (d == resetDay && id >= resetId)) {
        resetDay = d;
        resetId = id;
        final amt = _asLaborNum(e['wage']) * _asLaborNum(e['hours']);
        if ((e['entry_kind']?.toString() ?? '').toLowerCase() == 'opening') {
          if (amt >= 0) {
            seedWork = amt;
            seedPaid = 0;
          } else {
            seedWork = 0;
            seedPaid = -amt;
          }
        } else {
          seedWork = 0;
          seedPaid = 0;
        }
      }
    }
  }

  var work = applyAccountReset ? seedWork : 0.0;
  var paid = applyAccountReset ? seedPaid : 0.0;
  var hours = 0.0;
  for (final e in list) {
    final d = _laborDay(e['date']);
    if (fromD != null && (d == null || d.isBefore(fromD))) continue;
    if (toD != null && (d == null || d.isAfter(toD))) continue;
    if (applyAccountReset && resetDay != null) {
      final id = _laborId(e);
      if (d == null ||
          d.isBefore(resetDay) ||
          (d == resetDay && id <= resetId)) {
        continue;
      }
    }
    final amt = _asLaborNum(e['wage']) * _asLaborNum(e['hours']);
    final kind = e['entry_kind']?.toString();
    if (laborIsWorkKind(kind)) {
      work += amt;
      hours += _asLaborNum(e['hours']);
    } else if (laborIsPaymentKind(kind)) {
      paid += amt;
    } else if (!applyAccountReset && laborIsOpeningKind(kind)) {
      if (amt >= 0) {
        work += amt;
      } else {
        paid += -amt;
      }
    }
  }
  return LaborTotals(work: work, paid: paid, hours: hours);
}

int _laborId(Map<String, dynamic> e) {
  final v = e['id'];
  if (v is int) return v;
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

/// Prefer payable − paid so old APIs that stuffed payments into total_cost still net correctly.
double laborNetFromSummary(Map<String, dynamic> sum) {
  if (sum.containsKey('total_payable') || sum.containsKey('total_paid')) {
    return _asLaborNum(sum['total_payable']) - _asLaborNum(sum['total_paid']);
  }
  if (sum['balance'] != null) return _asLaborNum(sum['balance']);
  return _asLaborNum(sum['total_cost']);
}

bool laborIsPaymentKind(String? kind) =>
    (kind ?? '').toLowerCase() == 'payment';

bool laborIsOpeningKind(String? kind) =>
    (kind ?? '').toLowerCase() == 'opening';

bool laborIsResetKind(String? kind) {
  switch ((kind ?? '').toLowerCase()) {
    case 'tally':
    case 'opening':
      return true;
    default:
      return false;
  }
}

bool laborIsWorkKind(String? kind) {
  switch ((kind ?? 'payable').toLowerCase()) {
    case '':
    case 'payable':
      return true;
    default:
      return false;
  }
}

/// Work rows show rate × days/hrs. Payments are a lump sum, not labour units.
String laborRateHoursCaption(String? kind, double wage, double hours) {
  String money(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  if (laborIsPaymentKind(kind) || laborIsOpeningKind(kind)) {
    return '₹${money(wage * hours)}';
  }
  final h = hours == hours.roundToDouble()
      ? hours.toStringAsFixed(0)
      : hours.toStringAsFixed(1);
  return '₹${money(wage)} × $h';
}

(double payable, double receivable) _outstandingFromTotals(
  dynamic totalPayable,
  dynamic totalPaid, {
  dynamic balance,
}) {
  double n(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  final bal = balance != null ? n(balance) : n(totalPayable) - n(totalPaid);
  return (bal > 0 ? bal : 0, bal < 0 ? -bal : 0);
}

/// Payable / credit work → green. Payment / debit → red. Reset rows → info.
Color laborEntryAmountColor(String? kind, [double amount = 0]) {
  final k = (kind ?? 'payable').toLowerCase();
  if (k == 'payment' || (k == 'opening' && amount < 0)) {
    return AppColors.expense;
  }
  if (k == 'tally' || k == 'opening') return AppColors.info;
  return AppColors.income;
}

/// Debit balance (we owe them) → red. Credit balance (they owe us) → green.
Color get laborPayableBalanceColor => AppColors.expense;
Color get laborReceivableBalanceColor => AppColors.income;

/// Positive / zero payable → green. Negative (overpaid) → red.
Color laborSignedBalanceColor(double amount) =>
    amount < 0 ? AppColors.expense : AppColors.income;

bool laborEntryBelongsToPerson(
  Map<String, dynamic> e, {
  required String name,
  String? mobile,
}) {
  final m = mobile?.trim();
  final em = e['mobile']?.toString().trim() ?? '';
  if (m != null && m.isNotEmpty) {
    if (em.isNotEmpty) return em == m;
  }
  final en = (e['name']?.toString() ?? '').trim().toLowerCase();
  return en == name.trim().toLowerCase();
}

/// Directory search: match labourer name or mobile (partial, case-insensitive).
bool laborPersonMatchesQuery(Map<String, dynamic> person, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final name = (person['name']?.toString() ?? '').toLowerCase();
  final mobile = (person['mobile']?.toString() ?? '').toLowerCase();
  return name.contains(q) || mobile.contains(q);
}

List<Map<String, dynamic>> laborPeopleMatchingQuery(
  Iterable<Map<String, dynamic>> people,
  String query,
) {
  final q = query.trim();
  if (q.isEmpty) return people.toList();
  final seen = <String>{};
  final out = <Map<String, dynamic>>[];
  for (final p in people) {
    if (!laborPersonMatchesQuery(p, q)) continue;
    final key =
        '${p['mobile']?.toString().trim() ?? ''}|${p['name']?.toString().trim() ?? ''}'
            .toLowerCase();
    if (seen.add(key)) out.add(p);
  }
  return out;
}

/// Opening / period activity / closing for a date range.
class LaborPeriodStatement {
  final double opening;
  final double work;
  final double paid;
  final double hours;
  final double closing;
  final bool openingFromEntry;
  final int entryCount;

  const LaborPeriodStatement({
    this.opening = 0,
    this.work = 0,
    this.paid = 0,
    this.hours = 0,
    this.closing = 0,
    this.openingFromEntry = false,
    this.entryCount = 0,
  });

  double get periodNet => work - paid;

  /// Month with only an opening/tally row — still a real transaction.
  bool get onlyOpeningEntry =>
      openingFromEntry && work == 0 && paid == 0 && entryCount > 0;

  /// Amount shown on monthly/weekly cards (opening when that is the only row).
  double get summaryAmount => onlyOpeningEntry ? opening : periodNet;
}

double _laborOpeningAmount(Map<String, dynamic> e) {
  final amt = _asLaborNum(e['wage']) * _asLaborNum(e['hours']);
  if ((e['entry_kind']?.toString() ?? '').toLowerCase() == 'tally') return 0;
  return amt;
}

/// Opening = explicit opening/tally in the period when that seeds the month;
/// otherwise carried balance before [from]. Closing = balance through [to].
LaborPeriodStatement laborPeriodStatement(
  Iterable<Map<String, dynamic>> entries, {
  required DateTime from,
  required DateTime to,
}) {
  final list = entries.toList();
  final fromD = DateTime(from.year, from.month, from.day);
  final toD = DateTime(to.year, to.month, to.day);

  final inPeriod = <Map<String, dynamic>>[];
  for (final e in list) {
    final d = _laborDay(e['date']);
    if (d == null || d.isBefore(fromD) || d.isAfter(toD)) continue;
    inPeriod.add(e);
  }

  Map<String, dynamic>? periodOpening;
  DateTime? periodOpeningDay;
  var periodOpeningId = 0;
  for (final e in inPeriod) {
    if (!laborIsResetKind(e['entry_kind']?.toString())) continue;
    final d = _laborDay(e['date'])!;
    final id = _laborId(e);
    if (periodOpening == null ||
        d.isBefore(periodOpeningDay!) ||
        (d == periodOpeningDay && id < periodOpeningId)) {
      periodOpening = e;
      periodOpeningDay = d;
      periodOpeningId = id;
    }
  }

  final carried = summarizeLaborEntries(
    list,
    to: fromD.subtract(const Duration(days: 1)),
    applyAccountReset: true,
  ).net;

  late final double opening;
  var openingFromEntry = false;
  Map<String, dynamic>? excludedOpening;

  if (periodOpening != null && periodOpeningDay != null) {
    final onlyResets = inPeriod.every(
      (e) => laborIsResetKind(e['entry_kind']?.toString()),
    );
    final onStart = periodOpeningDay == fromD;
    // Opening on month start, or month contains only opening/tally row(s).
    if (onStart || onlyResets) {
      openingFromEntry = true;
      opening = _laborOpeningAmount(periodOpening);
      excludedOpening = periodOpening;
    } else {
      opening = carried;
    }
  } else {
    opening = carried;
  }

  var work = 0.0, paid = 0.0, hours = 0.0;
  for (final e in inPeriod) {
    if (excludedOpening != null &&
        _laborId(e) == _laborId(excludedOpening) &&
        _laborDay(e['date']) == _laborDay(excludedOpening['date'])) {
      continue;
    }
    final amt = _asLaborNum(e['wage']) * _asLaborNum(e['hours']);
    final kind = e['entry_kind']?.toString();
    if (laborIsWorkKind(kind)) {
      work += amt;
      hours += _asLaborNum(e['hours']);
    } else if (laborIsPaymentKind(kind)) {
      paid += amt;
    } else if (laborIsOpeningKind(kind)) {
      if (amt >= 0) {
        work += amt;
      } else {
        paid += -amt;
      }
    }
  }

  final closing =
      summarizeLaborEntries(list, to: toD, applyAccountReset: true).net;
  return LaborPeriodStatement(
    opening: opening,
    work: work,
    paid: paid,
    hours: hours,
    closing: closing,
    openingFromEntry: openingFromEntry,
    entryCount: inPeriod.length,
  );
}

List<Map<String, dynamic>> laborEntriesInRange(
  Iterable<Map<String, dynamic>> entries, {
  required DateTime from,
  required DateTime to,
}) {
  final fromD = DateTime(from.year, from.month, from.day);
  final toD = DateTime(to.year, to.month, to.day);
  final out = entries.where((e) {
    final d = _laborDay(e['date']);
    if (d == null) return false;
    return !d.isBefore(fromD) && !d.isAfter(toD);
  }).toList();
  out.sort((a, b) {
    final da = _laborDay(a['date']) ?? DateTime(2000);
    final db = _laborDay(b['date']) ?? DateTime(2000);
    final c = db.compareTo(da);
    if (c != 0) return c;
    return _laborId(b).compareTo(_laborId(a));
  });
  return out;
}

String _laborWorkTypeOf(Map<String, dynamic> e) {
  final v = (e['work_type']?.toString() ?? '').trim();
  return v.isEmpty ? 'Daily Wages' : v;
}

double _laborWageKey(double wage) => (wage * 100).round() / 100;

/// One Work Details row: type of work + wage rate, with labour units summed.
class LaborWorkLine {
  final String workType;
  final double wage;
  final double labour;
  final double total;
  final List<Map<String, dynamic>> entries;

  const LaborWorkLine({
    required this.workType,
    required this.wage,
    required this.labour,
    required this.total,
    required this.entries,
  });
}

bool _laborInRange(
  Map<String, dynamic> e, {
  required DateTime from,
  required DateTime to,
}) {
  final d = _laborDay(e['date']);
  if (d == null) return false;
  final fromD = DateTime(from.year, from.month, from.day);
  final toD = DateTime(to.year, to.month, to.day);
  return !d.isBefore(fromD) && !d.isAfter(toD);
}

/// Group payable work in [from]–[to] by work type and wage, matching the
/// individual labour statement (Daily wage 12 × 550, Contract 150 × 1.5, …).
List<LaborWorkLine> laborWorkLines(
  Iterable<Map<String, dynamic>> entries, {
  required DateTime from,
  required DateTime to,
}) {
  final grouped = <String, LaborWorkLine>{};
  for (final e in entries) {
    if (!_laborInRange(e, from: from, to: to)) continue;
    if (!laborIsWorkKind(e['entry_kind']?.toString())) continue;
    final workType = _laborWorkTypeOf(e);
    final wage = _laborWageKey(_asLaborNum(e['wage']));
    final hours = _asLaborNum(e['hours']);
    final key = '$workType|${wage.toStringAsFixed(2)}';
    final prev = grouped[key];
    grouped[key] = LaborWorkLine(
      workType: workType,
      wage: wage,
      labour: (prev?.labour ?? 0) + hours,
      total: (prev?.total ?? 0) + wage * hours,
      entries: [...?prev?.entries, e],
    );
  }
  return grouped.values.toList();
}

List<Map<String, dynamic>> laborPeriodPaymentEntries(
  Iterable<Map<String, dynamic>> entries, {
  required DateTime from,
  required DateTime to,
}) {
  final out = entries
      .where(
        (e) =>
            _laborInRange(e, from: from, to: to) &&
            laborIsPaymentKind(e['entry_kind']?.toString()),
      )
      .toList();
  out.sort((a, b) {
    final da = _laborDay(a['date']) ?? DateTime(2000);
    final db = _laborDay(b['date']) ?? DateTime(2000);
    final c = da.compareTo(db);
    if (c != 0) return c;
    return _laborId(a).compareTo(_laborId(b));
  });
  return out;
}

String laborMoneyText(num n) {
  final v = n.toDouble();
  if (v == v.roundToDouble()) {
    return '₹${NumberFormat('#,##0').format(v.round())}';
  }
  return '₹${NumberFormat('#,##0.##').format(v)}';
}

/// Searchable labourer directory + per-labour schedule summary.
class LabourSummaryPage extends StatefulWidget {
  const LabourSummaryPage({super.key});

  @override
  State<LabourSummaryPage> createState() => _LabourSummaryPageState();
}

class _LabourSummaryPageState extends State<LabourSummaryPage> {
  final ApiService _api = ApiService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  bool _searchingPeople = false;
  String? _error;
  List<Map<String, dynamic>> _allPeople = [];
  List<Map<String, dynamic>> _people = [];
  List<Map<String, dynamic>> _peopleSuggestions = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchText);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchText);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchText() {
    if (mounted) setState(() {});
  }

  List<Map<String, dynamic>> get _visiblePeople {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      return _allPeople.isNotEmpty ? _allPeople : _people;
    }
    return laborPeopleMatchingQuery([..._allPeople, ..._people], q);
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _money(dynamic v) =>
      '₹${NumberFormat('#,##0').format(_num(v).round())}';

  String _fmtDate(dynamic v) {
    if (v == null) return '—';
    try {
      return DateFormat('d MMM yyyy').format(DateTime.parse(v.toString()));
    } catch (_) {
      return v.toString();
    }
  }

  Future<void> _load({String? q, bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final people = await _api.fetchLaborPeople(q: q);
      if (!mounted) return;
      setState(() {
        _people = people;
        if (q == null || q.trim().isEmpty) {
          _allPeople = people;
          _peopleSuggestions = [];
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _searchPeople(String q) async {
    if (q.isEmpty) {
      if (!mounted) return;
      setState(() {
        _people = _allPeople;
        _peopleSuggestions = [];
        _searchingPeople = false;
      });
      return;
    }
    setState(() => _searchingPeople = true);
    try {
      final rows = await _api.fetchLaborPeople(q: q);
      if (!mounted) return;
      if (_searchCtrl.text.trim() != q) {
        setState(() => _searchingPeople = false);
        return;
      }
      setState(() {
        _people = rows;
        _peopleSuggestions = rows.take(8).toList();
        _searchingPeople = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _peopleSuggestions = [];
        _searchingPeople = false;
      });
    }
  }

  void _onSearchChanged(String v) {
    final q = v.trim();
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchPeople(q),
    );
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _people = _allPeople;
      _peopleSuggestions = [];
      _searchingPeople = false;
    });
    if (_allPeople.isEmpty) _load();
  }

  void _openDetail(Map<String, dynamic> person) {
    setState(() => _peopleSuggestions = []);
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LabourerDetailPage(
          name: person['name']?.toString() ?? '',
          mobile: person['mobile']?.toString(),
        ),
      ),
    );
  }

  Widget _buildPeopleSuggestions() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppColors.softShadow],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _peopleSuggestions.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: AppColors.border),
        itemBuilder: (_, i) {
          final p = _peopleSuggestions[i];
          final name = p['name']?.toString() ?? '';
          final mobile = p['mobile']?.toString() ?? '';
          return InkWell(
            onTap: () {
              _searchCtrl.text = name;
              _searchCtrl.selection =
                  TextSelection.collapsed(offset: name.length);
              _openDetail(p);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: AppText.bodyStrong),
                        if (mobile.isNotEmpty)
                          Text(
                            mobile,
                            style: AppText.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.primary.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: tr('Labour Summary'),
              subtitle: tr('Search & schedule by labourer'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: withFeedbackAction(
                  context,
                  menu: 'labour_summary',
                  actions: [
                    IconButton(
                      tooltip: tr('Refresh'),
                      onPressed: () => _load(q: _searchCtrl.text.trim()),
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: tr('Search by name or mobile…'),
                      prefixIcon: const Icon(Icons.person_search_rounded),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: _clearSearch,
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  if (_searchingPeople)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (_peopleSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildPeopleSuggestions(),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _loading
                      ? 'Loading…'
                      : '${_visiblePeople.length} labourer${_visiblePeople.length == 1 ? '' : 's'}',
                  style: AppText.caption,
                ),
              ),
            ),
            if (!_loading && _visiblePeople.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Builder(builder: (_) {
                  double sumPay = 0, sumRec = 0;
                  for (final p in _visiblePeople) {
                    final o = _outstandingFromTotals(
                      p['total_payable'],
                      p['total_paid'],
                      balance: p['balance'],
                    );
                    sumPay += o.$1;
                    sumRec += o.$2;
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${tr('Total Payable')}: ${_money(sumPay)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: laborPayableBalanceColor,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${tr('Total Receivable')}: ${_money(sumRec)}',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: laborReceivableBalanceColor,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            SizedBox(height: 6),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () =>
                                      _load(q: _searchCtrl.text.trim()),
                                  child: Text(tr('Retry')),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _visiblePeople.isEmpty
                          ? AppCard(
                              margin: EdgeInsets.all(12),
                              child: EmptyState(
                                icon: Icons.person_search_rounded,
                                title: tr('No labourers found'),
                                subtitle: _searchCtrl.text.trim().isEmpty
                                    ? tr('Add labour entries first, then search here')
                                    : tr('Try a different name or mobile'),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () =>
                                  _load(q: _searchCtrl.text.trim()),
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  4,
                                  12,
                                  24,
                                ),
                                itemCount: _visiblePeople.length,
                                separatorBuilder: (_, _) =>
                                    SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final p = _visiblePeople[i];
                                  final name = p['name']?.toString() ?? '—';
                                  final mobile = p['mobile']?.toString();
                                  final gender = p['gender']?.toString() ?? '';
                                  return AppCard(
                                    onTap: () => _openDetail(p),
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: AppColors.primarySoft,
                                          child: Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                [
                                                  if (mobile != null &&
                                                      mobile.isNotEmpty)
                                                    mobile,
                                                  if (gender.isNotEmpty) gender,
                                                  laborNumberOfLabourText(
                                                      p['entry_count']),
                                                ].join(' · '),
                                                style: AppText.caption,
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Last: ${_fmtDate(p['last_date'])}'
                                                '${(p['last_category']?.toString().isNotEmpty ?? false) ? ' · ${p['last_category']}' : ''}',
                                                style: AppText.caption,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Builder(builder: (_) {
                                              final o = _outstandingFromTotals(
                                                p['total_payable'],
                                                p['total_paid'],
                                                balance: p['balance'],
                                              );
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '${tr('Payable')} ${_money(o.$1)}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 12,
                                                      color: laborPayableBalanceColor,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${tr('Receivable')} ${_money(o.$2)}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 12,
                                                      color: laborReceivableBalanceColor,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            }),
                                            const Icon(
                                              Icons.chevron_right_rounded,
                                              color: AppColors.textMuted,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Selected labourer: profile + monthly/weekly schedule + entries.
class LabourerDetailPage extends StatefulWidget {
  final String name;
  final String? mobile;

  const LabourerDetailPage({
    super.key,
    required this.name,
    this.mobile,
  });

  @override
  State<LabourerDetailPage> createState() => _LabourerDetailPageState();
}

class _LabourerDetailPageState extends State<LabourerDetailPage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabs;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _fromDate;
  DateTime? _toDate;
  String _period = 'Monthly'; // Monthly | Weekly | Custom
  String? _filterCategory;
  List<String> _categories = List<String>.from(kLaborWorkCategories);

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _report;
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _rates = [];
  double _totalPayable = 0;
  double _totalReceivable = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _applyPeriod('Monthly');
    loadLaborCategories().then((cats) {
      if (mounted) setState(() => _categories = cats);
    });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String? get _mobile {
    final m = widget.mobile?.trim();
    if (m != null && m.isNotEmpty) return m;
    return null;
  }

  Future<void> _showOpeningBalance() async {
    final amountCtrl = TextEditingController();
    DateTime date = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(tr('Opening Balance')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if ((_mobile ?? '').isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_mobile!, style: AppText.caption),
                    ),
                  SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: tr('Opening amount'),
                      prefixIcon: const Icon(Icons.currency_rupee_rounded),
                      helperText: tr(
                        'Resets the account from this date. Positive = payable.',
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_rounded),
                    title: Text(DateFormat('dd/MM/yyyy').format(date)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null) setLocal(() => date = picked);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.pop(ctx, false);
                  },
                  child: Text(tr('Cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.pop(ctx, true);
                  },
                  child: Text(tr('Save')),
                ),
              ],
            );
          },
        );
      },
    );
    final amount = double.tryParse(amountCtrl.text.trim());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      amountCtrl.dispose();
    });
    if (ok != true) return;
    if (!mounted) return;
    if (amount == null || amount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Enter valid amount'))),
      );
      return;
    }
    final result = await _api.createLabor({
      'name': widget.name,
      if (_mobile != null) 'mobile': _mobile,
      'wage': amount.abs(),
      'hours': 1,
      'number_of_labours': 1,
      'entry_kind': 'opening',
      'category': 'Opening Balance',
      'shift': 'fullday',
      'gender': 'Male',
      'work_type': 'Daily Wages',
      'location': 'Farm',
      'date': DateFormat('yyyy-MM-dd').format(date),
      'narration': tr('Opening Balance'),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? tr('Opening balance saved')
              : (result['message']?.toString() ??
                  tr('Failed to save opening balance')),
        ),
      ),
    );
    if (result['success'] == true) await _load();
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _money(dynamic v) =>
      '₹${NumberFormat('#,##0').format(_num(v).round())}';

  String _hours(dynamic v) {
    final n = _num(v);
    return n == n.roundToDouble()
        ? n.toStringAsFixed(0)
        : n.toStringAsFixed(1);
  }

  List<Map<String, dynamic>> _list(String key) {
    final raw = _report?[key];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, dynamic> _map(String key) {
    final raw = _report?[key];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  DateTime get _monthStart =>
      DateTime(_selectedMonth.year, _selectedMonth.month, 1);
  DateTime get _monthEnd =>
      DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

  bool _belongsToLabourer(Map<String, dynamic> e) => laborEntryBelongsToPerson(
        e,
        name: widget.name,
        mobile: _mobile,
      );

  bool _entryInPeriod(Map<String, dynamic> e) {
    final d = _laborDay(e['date']);
    if (d == null) return false;
    if (_fromDate != null) {
      final f = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
      if (d.isBefore(f)) return false;
    }
    if (_toDate != null) {
      final t = DateTime(_toDate!.year, _toDate!.month, _toDate!.day);
      if (d.isAfter(t)) return false;
    }
    return true;
  }

  List<Map<String, dynamic>> get _personEntries =>
      _entries.where(_belongsToLabourer).toList();

  List<Map<String, dynamic>> get _periodEntries =>
      _personEntries.where(_entryInPeriod).toList();

  DateTime get _stmtFrom => _fromDate ?? _monthStart;
  DateTime get _stmtTo => _toDate ?? _monthEnd;

  LaborPeriodStatement get _periodStmt => laborPeriodStatement(
        _personEntries,
        from: _stmtFrom,
        to: _stmtTo,
      );

  List<LaborWorkLine> get _periodWorkLines => laborWorkLines(
        _personEntries,
        from: _stmtFrom,
        to: _stmtTo,
      );

  void _syncSelectedMonthFromRange() {
    final anchor = _fromDate ?? _toDate;
    if (anchor != null) {
      _selectedMonth = DateTime(anchor.year, anchor.month);
    }
  }

  void _applyPeriod(String period) {
    final now = DateTime.now();
    _period = period;
    if (period == 'Monthly') {
      final base = _selectedMonth;
      _fromDate = DateTime(base.year, base.month, 1);
      _toDate = DateTime(base.year, base.month + 1, 0);
    } else if (period == 'Weekly') {
      final weekday = now.weekday; // Mon=1
      _fromDate = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: weekday - 1));
      _toDate = _fromDate!.add(const Duration(days: 6));
      _syncSelectedMonthFromRange();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.fetchLaborReports(
          year: _selectedMonth.year,
          month: _selectedMonth.month,
          months: 6,
          mobile: _mobile,
          name: _mobile == null ? widget.name : null,
          category: _filterCategory,
        ),
        _api.fetchLabors(
          mobile: _mobile,
          name: _mobile == null ? widget.name : null,
          category: _filterCategory,
          limit: 500,
        ),
        _api.fetchLaborBalance(
          mobile: _mobile,
          name: _mobile == null ? widget.name : widget.name,
        ),
        if (_mobile != null) _api.fetchLaborRates(mobile: _mobile),
      ]);
      if (!mounted) return;
      final bal = results[2] as Map<String, dynamic>?;
      setState(() {
        _report = results[0] as Map<String, dynamic>;
        _entries = results[1] as List<Map<String, dynamic>>;
        if (bal != null) {
          _totalPayable = _num(bal['payable']);
          _totalReceivable = _num(bal['receivable']);
        } else {
          final allSum = _map('summary');
          final o = _outstandingFromTotals(
            allSum['total_payable'],
            allSum['total_paid'],
            balance: allSum['balance'],
          );
          _totalPayable = o.$1;
          _totalReceivable = o.$2;
        }
        if (results.length > 3) {
          _rates = results[3] as List<Map<String, dynamic>>;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked == null) return;
    setState(() {
      _period = 'Custom';
      _fromDate = picked;
      if (_toDate != null && _toDate!.isBefore(picked)) {
        _toDate = picked;
      }
      _syncSelectedMonthFromRange();
    });
    _load();
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked == null) return;
    setState(() {
      _period = 'Custom';
      _toDate = picked;
      if (_fromDate != null && _fromDate!.isAfter(picked)) {
        _fromDate = picked;
      }
      _syncSelectedMonthFromRange();
    });
    _load();
  }

  Future<void> _exportExcel() async {
    await shareLabourExcel(
      _periodEntries,
      fileName: 'labour_${widget.name.replaceAll(' ', '_')}.xlsx',
    );
  }

  Future<void> _exportPdf() async {
    await shareLabourStatementPdf(
      title: '${tr('Labour Statement')} — ${widget.name}',
      subtitle: _mobile,
      totalPayable: _totalPayable,
      totalReceivable: _totalReceivable,
      entries: _periodEntries,
      fileName: 'labour_${widget.name.replaceAll(' ', '_')}.pdf',
    );
  }

  Future<void> _editEntry(Map<String, dynamic> entry) async {
    final changed = await showLaborEntryEditDialog(context, entry, _api);
    if (changed == true) _load();
  }

  Future<void> _deleteEntry(Map<String, dynamic> entry) async {
    final id = entry['id'];
    final intId = id is int ? id : int.tryParse('$id');
    if (intId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Delete labour entry?')),
        content: Text(tr('This cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final deleted = await _api.deleteLabor(intId);
    if (!mounted) return;
    if (deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Labour entry deleted'))),
      );
      _load();
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: 'Select month',
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
        // Keep Entries date range aligned with the month shown in reports.
        if (_period != 'Weekly') {
          _period = 'Monthly';
          _fromDate = DateTime(picked.year, picked.month, 1);
          _toDate = DateTime(picked.year, picked.month + 1, 0);
        }
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _map('profile');
    final displayName =
        profile['name']?.toString().isNotEmpty == true
            ? profile['name'].toString()
            : widget.name;
    final displayMobile =
        profile['mobile']?.toString() ?? widget.mobile ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: displayName,
              subtitle: displayMobile.isNotEmpty
                  ? displayMobile
                  : 'Labour schedule',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: withFeedbackAction(
                  context,
                  menu: 'labour_summary',
                  actions: [
                    IconButton(
                      tooltip: tr('Opening Balance'),
                      onPressed: _showOpeningBalance,
                      icon: const Icon(Icons.add_card_rounded,
                          color: Colors.white),
                    ),
                    IconButton(
                      tooltip: tr('Export Excel'),
                      onPressed: _periodEntries.isEmpty ? null : _exportExcel,
                      icon: const Icon(Icons.table_chart_rounded,
                          color: Colors.white),
                    ),
                    IconButton(
                      tooltip: tr('Statement PDF'),
                      onPressed: _periodEntries.isEmpty ? null : _exportPdf,
                      icon: const Icon(Icons.picture_as_pdf_rounded,
                          color: Colors.white),
                    ),
                    IconButton(
                      tooltip: tr('Refresh'),
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${tr('Total Payable')}: ${_money(_totalPayable)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: laborPayableBalanceColor,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${tr('Total Receivable')}: ${_money(_totalReceivable)}',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: laborReceivableBalanceColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: Text(tr('Monthly')),
                        selected: _period == 'Monthly',
                        onSelected: (_) {
                          setState(() => _applyPeriod('Monthly'));
                          _load();
                        },
                      ),
                      ChoiceChip(
                        label: Text(tr('Weekly')),
                        selected: _period == 'Weekly',
                        onSelected: (_) {
                          setState(() => _applyPeriod('Weekly'));
                          _load();
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.date_range_rounded, size: 16),
                        label: Text(
                          _fromDate == null
                              ? tr('From')
                              : DateFormat('d MMM').format(_fromDate!),
                        ),
                        onPressed: _pickFrom,
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.event_rounded, size: 16),
                        label: Text(
                          _toDate == null
                              ? tr('To')
                              : DateFormat('d MMM').format(_toDate!),
                        ),
                        onPressed: _pickTo,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: _filterCategory,
                    decoration: InputDecoration(
                      labelText: tr('Category'),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(tr('All categories')),
                      ),
                      ..._categories.map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _filterCategory = v);
                      _load();
                    },
                  ),
                  SizedBox(height: 8),
                  InkWell(
                    onTap: _pickMonth,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            DateFormat('MMMM yyyy').format(_selectedMonth),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.expand_more_rounded,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              isScrollable: true,
              tabs: [
                Tab(text: tr('Statement')),
                Tab(text: tr('Monthly')),
                Tab(text: tr('Weekly')),
                Tab(text: tr('Entries')),
              ],
            ),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!),
                              TextButton(onPressed: _load, child: Text(tr('Retry'))),
                            ],
                          ),
                        )
                      : TabBarView(
                          controller: _tabs,
                          children: [
                            _buildOverview(profile),
                            _buildMonthly(),
                            _buildWeekly(),
                            _buildEntries(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(Map<String, dynamic> profile) {
    final displayName =
        profile['name']?.toString().isNotEmpty == true
            ? profile['name'].toString()
            : widget.name;
    final stmt = _periodStmt;
    final lines = _periodWorkLines;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          _LabourPeriodStatementCard(
            name: displayName,
            from: _stmtFrom,
            to: _stmtTo,
            stmt: stmt,
            workLines: lines,
            onPickFrom: _pickFrom,
            onPickTo: _pickTo,
            onWorkLineTap: (line) => _openWorkLineDetail(line),
            onPaidTap: _openPaymentsDetail,
          ),
          if (_rates.isNotEmpty) ...[
            SizedBox(height: 14),
            Text(tr('Saved rates'), style: AppText.h3),
            SizedBox(height: 8),
            AppCard(
              child: Column(
                children: _rates
                    .map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(r['category']?.toString() ?? '')),
                            Text(
                              _money(r['rate']),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openWorkLineDetail(LaborWorkLine line) async {
    final from = _stmtFrom;
    final to = _stmtTo;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _LaborEntriesDetailPage(
          title: '${tr(line.workType)} · ${laborMoneyText(line.wage)}',
          subtitle:
              '${widget.name} · ${DateFormat('d MMM').format(from)} – ${DateFormat('d MMM yyyy').format(to)}',
          labourerName: widget.name,
          mobile: _mobile,
          initialEntries: line.entries,
          groupByDay: true,
          keep: (e) {
            if (!laborIsWorkKind(e['entry_kind']?.toString())) return false;
            if (!_laborInRange(e, from: from, to: to)) return false;
            return _laborWorkTypeOf(e) == line.workType &&
                _laborWageKey(_asLaborNum(e['wage'])) == line.wage;
          },
        ),
      ),
    );
    if (changed == true && mounted) _load();
  }

  Future<void> _openPaymentsDetail() async {
    final from = _stmtFrom;
    final to = _stmtTo;
    final payments = laborPeriodPaymentEntries(
      _personEntries,
      from: from,
      to: to,
    );
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _LaborEntriesDetailPage(
          title: tr('Payment details'),
          subtitle:
              '${widget.name} · ${DateFormat('d MMM').format(from)} – ${DateFormat('d MMM yyyy').format(to)}',
          labourerName: widget.name,
          mobile: _mobile,
          initialEntries: payments,
          groupByDay: true,
          keep: (e) =>
              laborIsPaymentKind(e['entry_kind']?.toString()) &&
              _laborInRange(e, from: from, to: to),
        ),
      ),
    );
    if (changed == true && mounted) _load();
  }

  Future<void> _openPeriodDetail({
    required String title,
    required DateTime from,
    required DateTime to,
  }) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _LaborPeriodDetailPage(
          title: title,
          labourerName: widget.name,
          mobile: _mobile,
          from: from,
          to: to,
          initialEntries: _personEntries,
        ),
      ),
    );
    if (changed == true && mounted) _load();
  }

  Widget _buildMonthly() {
    final monthly = _list('monthly');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Text(tr('Monthly schedule'), style: AppText.h3),
          SizedBox(height: 4),
          Text(tr('Cost & days by month for this labourer'), style: AppText.caption),
          SizedBox(height: 12),
          if (monthly.isEmpty)
            AppCard(child: Text(tr('No monthly data')))
          else
            ...monthly.reversed.map((m) {
              final year = _num(m['year']).toInt();
              final month = _num(m['month']).toInt();
              if (year <= 0 || month <= 0) {
                return const SizedBox.shrink();
              }
              final from = DateTime(year, month, 1);
              final to = DateTime(year, month + 1, 0);
              final stmt = laborPeriodStatement(
                _personEntries,
                from: from,
                to: to,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  onTap: () => _openPeriodDetail(
                    title: m['label']?.toString() ??
                        DateFormat('MMM yyyy').format(from),
                    from: from,
                    to: to,
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              m['label']?.toString() ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Text(
                            _money(stmt.summaryAmount),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: laborSignedBalanceColor(stmt.summaryAmount),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        '${tr('Opening Balance')}: ${_money(stmt.opening)}'
                        ' · ${tr('Closing Balance')}: ${_money(stmt.closing)}',
                        style: AppText.caption,
                      ),
                      SizedBox(height: 4),
                      Text(
                        stmt.onlyOpeningEntry
                            ? tr('Opening Balance')
                            : laborNumberOfLabourText(_hours(stmt.hours)),
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildWeekly() {
    final weekly = _list('weekly');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Text(
            'Weekly schedule · ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
            style: AppText.h3,
          ),
          SizedBox(height: 4),
          Text(tr('Week-wise work for selected month'), style: AppText.caption),
          SizedBox(height: 12),
          if (weekly.isEmpty)
            AppCard(child: Text(tr('No weekly data')))
          else
            ...weekly.map((w) {
              DateTime? ws;
              DateTime? we;
              try {
                ws = DateTime.parse(w['week_start'].toString());
                we = DateTime.parse(w['week_end'].toString());
              } catch (_) {}
              if (ws == null || we == null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Text(w['label']?.toString() ?? 'Week'),
                  ),
                );
              }
              final stmt = laborPeriodStatement(
                _personEntries,
                from: ws,
                to: we,
              );
              final from = ws;
              final to = we;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  onTap: () => _openPeriodDetail(
                    title: w['label']?.toString() ?? 'Week',
                    from: from,
                    to: to,
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w['label']?.toString() ?? 'Week',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            _money(stmt.summaryAmount),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: laborSignedBalanceColor(stmt.summaryAmount),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            stmt.onlyOpeningEntry
                                ? tr('Opening Balance')
                                : laborNumberOfLabourText(_hours(stmt.hours)),
                            style: AppText.caption,
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${tr('Opening Balance')}: ${_money(stmt.opening)}'
                        ' · ${tr('Closing Balance')}: ${_money(stmt.closing)}',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEntries() {
    return RefreshIndicator(
      onRefresh: _load,
      child: _periodEntries.isEmpty
          ? ListView(
              children: [
                SizedBox(height: 40),
                Center(child: Text(tr('No entries for this labourer'))),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: _periodEntries.length,
              separatorBuilder: (_, _) => SizedBox(height: 8),
              itemBuilder: (context, i) {
                final e = _periodEntries[i];
                final wage = _num(e['wage']);
                final hours = _num(e['hours']);
                final kind = e['entry_kind']?.toString();
                final amount = wage * hours;
                final amountColor = laborEntryAmountColor(kind, amount);
                DateTime? date;
                try {
                  date = DateTime.parse(e['date'].toString());
                } catch (_) {}
                return AppCard(
                  onTap: () => _editEntry(e),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              e['category']?.toString() ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            _money(amount.abs()),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: amountColor,
                            ),
                          ),
                          IconButton(
                            tooltip: tr('Delete'),
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: AppColors.expense, size: 20),
                            onPressed: () => _deleteEntry(e),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        [
                          if (date != null)
                            DateFormat('d MMM yyyy').format(date),
                          e['shift']?.toString() ?? '',
                          e['location']?.toString() ?? '',
                          e['entry_kind']?.toString() ?? '',
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: AppText.caption,
                      ),
                      SizedBox(height: 4),
                      Text(
                        laborIsPaymentKind(kind)
                            ? laborRateHoursCaption(kind, wage, hours)
                            : '${tr('Rate')} ${laborRateHoursCaption(kind, wage, hours)} · ${e['work_type'] ?? ''}',
                        style: AppText.caption,
                      ),
                      if ((e['narration']?.toString() ?? '').isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          e['narration'].toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

}

class _LabourPeriodStatementCard extends StatelessWidget {
  final String name;
  final DateTime from;
  final DateTime to;
  final LaborPeriodStatement stmt;
  final List<LaborWorkLine> workLines;
  final ValueChanged<LaborWorkLine> onWorkLineTap;
  final VoidCallback onPaidTap;
  final VoidCallback? onPickFrom;
  final VoidCallback? onPickTo;

  const _LabourPeriodStatementCard({
    required this.name,
    required this.from,
    required this.to,
    required this.stmt,
    required this.workLines,
    required this.onWorkLineTap,
    required this.onPaidTap,
    this.onPickFrom,
    this.onPickTo,
  });

  TextStyle get _head => const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12,
        color: AppColors.textSecondary,
      );

  Widget _kvRow(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }

  Widget _workHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(tr('Type of work'), style: _head)),
          Expanded(
            flex: 2,
            child: Text(tr('Labour'), textAlign: TextAlign.end, style: _head),
          ),
          Expanded(
            flex: 2,
            child: Text(tr('Wage'), textAlign: TextAlign.end, style: _head),
          ),
          Expanded(
            flex: 2,
            child: Text(tr('Total'), textAlign: TextAlign.end, style: _head),
          ),
          const SizedBox(width: 18),
        ],
      ),
    );
  }

  Widget _workRow(LaborWorkLine line) {
    return InkWell(
      onTap: () => onWorkLineTap(line),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                tr(line.workType),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                formatLaborHours(line.labour),
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                laborMoneyText(line.wage),
                textAlign: TextAlign.end,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                laborMoneyText(line.total),
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideAmount(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppText.caption),
          ),
          Text(
            amount == 0 ? '—' : laborMoneyText(amount),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: amount == 0 ? AppColors.textMuted : color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final openingPay = stmt.opening > 0 ? stmt.opening : 0.0;
    final openingRec = stmt.opening < 0 ? -stmt.opening : 0.0;
    final netPay = stmt.closing > 0 ? stmt.closing : 0.0;
    final netRec = stmt.closing < 0 ? -stmt.closing : 0.0;
    final workTotal = workLines.fold<double>(0, (s, l) => s + l.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kvRow(
                tr('Name'),
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              _kvRow(
                tr('Period'),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onPickFrom,
                        child: Text(
                          '${tr('From')}  ${DateFormat('d MMM yyyy').format(from)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: onPickFrom == null
                                ? AppColors.textPrimary
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: onPickTo,
                        child: Text(
                          '${tr('To')}  ${DateFormat('d MMM yyyy').format(to)}',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: onPickTo == null
                                ? AppColors.textPrimary
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('Work Details'), style: AppText.h3),
              SizedBox(height: 10),
              _workHeader(),
              const Divider(height: 1),
              if (workLines.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(tr('No work in this period'), style: AppText.caption),
                )
              else
                ...workLines.map(_workRow),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        tr('Total'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const Expanded(flex: 2, child: SizedBox.shrink()),
                    const Expanded(flex: 2, child: SizedBox.shrink()),
                    Expanded(
                      flex: 2,
                      child: Text(
                        laborMoneyText(workTotal),
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 18),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Text(
                tr('Tap a work row for day-wise details'),
                style: AppText.caption,
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('Receipts and Payments'), style: AppText.h3),
              SizedBox(height: 10),
              Text(
                tr('Opening Balance'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              _sideAmount(
                tr('Payable'),
                openingPay,
                laborPayableBalanceColor,
              ),
              _sideAmount(
                tr('Receivable'),
                openingRec,
                laborReceivableBalanceColor,
              ),
              SizedBox(height: 8),
              InkWell(
                onTap: onPaidTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr('Amount Paid for the period'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Text(
                        laborMoneyText(stmt.paid),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 8),
              Text(
                tr('Net Balance'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              _sideAmount(
                tr('Payable'),
                netPay,
                laborPayableBalanceColor,
              ),
              _sideAmount(
                tr('Receivable'),
                netRec,
                laborReceivableBalanceColor,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Day-wise / work-wise (or payment) entries for a tapped statement row.
class _LaborEntriesDetailPage extends StatefulWidget {
  final String title;
  final String subtitle;
  final String labourerName;
  final String? mobile;
  final List<Map<String, dynamic>> initialEntries;
  final bool groupByDay;
  final bool Function(Map<String, dynamic> e)? keep;

  const _LaborEntriesDetailPage({
    required this.title,
    required this.subtitle,
    required this.labourerName,
    required this.mobile,
    required this.initialEntries,
    this.groupByDay = true,
    this.keep,
  });

  @override
  State<_LaborEntriesDetailPage> createState() =>
      _LaborEntriesDetailPageState();
}

class _LaborEntriesDetailPageState extends State<_LaborEntriesDetailPage> {
  final ApiService _api = ApiService();
  late List<Map<String, dynamic>> _entries;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _entries = List<Map<String, dynamic>>.from(widget.initialEntries);
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  Future<void> _reloadEntries() async {
    final rows = await _api.fetchLabors(
      mobile: widget.mobile,
      name: widget.mobile == null ? widget.labourerName : null,
      limit: 500,
    );
    if (!mounted) return;
    setState(() {
      _entries = rows.where((e) {
        if (!laborEntryBelongsToPerson(
          e,
          name: widget.labourerName,
          mobile: widget.mobile,
        )) {
          return false;
        }
        if (widget.keep != null) return widget.keep!(e);
        final ids = widget.initialEntries.map(_laborId).toSet();
        return ids.contains(_laborId(e));
      }).toList();
    });
  }

  Future<void> _editEntry(Map<String, dynamic> entry) async {
    final changed = await showLaborEntryEditDialog(context, entry, _api);
    if (changed == true) {
      _changed = true;
      await _reloadEntries();
    }
  }

  Future<void> _deleteEntry(Map<String, dynamic> entry) async {
    final id = entry['id'];
    final intId = id is int ? id : int.tryParse('$id');
    if (intId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Delete labour entry?')),
        content: Text(tr('This cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final deleted = await _api.deleteLabor(intId);
    if (!mounted) return;
    if (deleted) {
      _changed = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Labour entry deleted'))),
      );
      await _reloadEntries();
    }
  }

  List<MapEntry<DateTime, List<Map<String, dynamic>>>> get _grouped {
    final rows = List<Map<String, dynamic>>.from(_entries);
    rows.sort((a, b) {
      final da = _laborDay(a['date']) ?? DateTime(2000);
      final db = _laborDay(b['date']) ?? DateTime(2000);
      final c = da.compareTo(db);
      if (c != 0) return c;
      return _laborId(a).compareTo(_laborId(b));
    });
    final map = <DateTime, List<Map<String, dynamic>>>{};
    for (final e in rows) {
      final d = _laborDay(e['date']) ?? DateTime(2000);
      map.putIfAbsent(d, () => []).add(e);
    }
    return map.entries.toList();
  }

  Widget _entryCard(Map<String, dynamic> e) {
    final wage = _num(e['wage']);
    final hours = _num(e['hours']);
    final kind = e['entry_kind']?.toString();
    final amount = wage * hours;
    final amountColor = laborEntryAmountColor(kind, amount);
    return AppCard(
      onTap: () => _editEntry(e),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  e['category']?.toString().isNotEmpty == true
                      ? e['category'].toString()
                      : (e['work_type']?.toString() ?? tr('Work type')),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                laborMoneyText(amount.abs()),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: amountColor,
                ),
              ),
              IconButton(
                tooltip: tr('Delete'),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.expense,
                  size: 20,
                ),
                onPressed: () => _deleteEntry(e),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            [
              e['shift']?.toString() ?? '',
              e['location']?.toString() ?? '',
              if (laborIsWorkKind(kind))
                '${tr('Labour')} ${formatLaborHours(hours)}',
              laborRateHoursCaption(kind, wage, hours),
            ].where((s) => s.isNotEmpty).join(' · '),
            style: AppText.caption,
          ),
          if ((e['narration']?.toString() ?? '').isNotEmpty) ...[
            SizedBox(height: 4),
            Text(e['narration'].toString(), style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = _grouped;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: widget.title,
                subtitle: widget.subtitle,
                onBack: () => Navigator.pop(context, _changed),
              ),
              Expanded(
                child: groups.isEmpty
                    ? Center(child: Text(tr('No entries for this labourer')))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                        itemCount: groups.length,
                        itemBuilder: (context, i) {
                          final day = groups[i].key;
                          final rows = groups[i].value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.groupByDay)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 4,
                                      bottom: 8,
                                    ),
                                    child: Text(
                                      DateFormat('d MMM yyyy').format(day),
                                      style: AppText.h3,
                                    ),
                                  ),
                                ...rows.map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _entryCard(e),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Month / week ledger: opening balance, entries in range, closing balance.
class _LaborPeriodDetailPage extends StatefulWidget {
  final String title;
  final String labourerName;
  final String? mobile;
  final DateTime from;
  final DateTime to;
  final List<Map<String, dynamic>> initialEntries;

  const _LaborPeriodDetailPage({
    required this.title,
    required this.labourerName,
    required this.mobile,
    required this.from,
    required this.to,
    required this.initialEntries,
  });

  @override
  State<_LaborPeriodDetailPage> createState() => _LaborPeriodDetailPageState();
}

class _LaborPeriodDetailPageState extends State<_LaborPeriodDetailPage> {
  final ApiService _api = ApiService();
  late List<Map<String, dynamic>> _entries;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _entries = List<Map<String, dynamic>>.from(widget.initialEntries);
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _money(dynamic v) =>
      '₹${NumberFormat('#,##0').format(_num(v).round())}';

  LaborPeriodStatement get _stmt => laborPeriodStatement(
        _entries,
        from: widget.from,
        to: widget.to,
      );

  List<Map<String, dynamic>> get _periodRows => laborEntriesInRange(
        _entries,
        from: widget.from,
        to: widget.to,
      );

  Future<void> _reloadEntries() async {
    final rows = await _api.fetchLabors(
      mobile: widget.mobile,
      name: widget.mobile == null ? widget.labourerName : null,
      limit: 500,
    );
    if (!mounted) return;
    setState(() {
      _entries = rows
          .where(
            (e) => laborEntryBelongsToPerson(
              e,
              name: widget.labourerName,
              mobile: widget.mobile,
            ),
          )
          .toList();
    });
  }

  Future<void> _editEntry(Map<String, dynamic> entry) async {
    final changed = await showLaborEntryEditDialog(context, entry, _api);
    if (changed == true) {
      _changed = true;
      await _reloadEntries();
    }
  }

  Future<void> _deleteEntry(Map<String, dynamic> entry) async {
    final id = entry['id'];
    final intId = id is int ? id : int.tryParse('$id');
    if (intId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Delete labour entry?')),
        content: Text(tr('This cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final deleted = await _api.deleteLabor(intId);
    if (!mounted) return;
    if (deleted) {
      _changed = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Labour entry deleted'))),
      );
      await _reloadEntries();
    }
  }

  Widget _balanceTile(String label, double amount) {
    final color = laborSignedBalanceColor(amount);
    final hint = amount < 0 ? tr('Receivable') : tr('Payable');
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text(hint, style: AppText.caption),
              ],
            ),
          ),
          Text(
            _money(amount),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWorkLineDetail(LaborWorkLine line) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _LaborEntriesDetailPage(
          title: '${tr(line.workType)} · ${laborMoneyText(line.wage)}',
          subtitle: '${widget.labourerName} · ${DateFormat('d MMM').format(widget.from)} – ${DateFormat('d MMM yyyy').format(widget.to)}',
          labourerName: widget.labourerName,
          mobile: widget.mobile,
          initialEntries: line.entries,
          groupByDay: true,
          keep: (e) {
            if (!laborIsWorkKind(e['entry_kind']?.toString())) return false;
            if (!_laborInRange(e, from: widget.from, to: widget.to)) {
              return false;
            }
            return _laborWorkTypeOf(e) == line.workType &&
                _laborWageKey(_asLaborNum(e['wage'])) == line.wage;
          },
        ),
      ),
    );
    if (changed == true) {
      _changed = true;
      await _reloadEntries();
    }
  }

  Future<void> _openPaymentsDetail() async {
    final payments = laborPeriodPaymentEntries(
      _entries,
      from: widget.from,
      to: widget.to,
    );
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _LaborEntriesDetailPage(
          title: tr('Payment details'),
          subtitle: '${widget.labourerName} · ${DateFormat('d MMM').format(widget.from)} – ${DateFormat('d MMM yyyy').format(widget.to)}',
          labourerName: widget.labourerName,
          mobile: widget.mobile,
          initialEntries: payments,
          groupByDay: true,
          keep: (e) =>
              laborIsPaymentKind(e['entry_kind']?.toString()) &&
              _laborInRange(e, from: widget.from, to: widget.to),
        ),
      ),
    );
    if (changed == true) {
      _changed = true;
      await _reloadEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stmt = _stmt;
    final rows = _periodRows;
    final rangeLabel =
        '${DateFormat('d MMM').format(widget.from)} – ${DateFormat('d MMM yyyy').format(widget.to)}';
    final lines = laborWorkLines(
      _entries,
      from: widget.from,
      to: widget.to,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: widget.title,
                subtitle: '${widget.labourerName} · $rangeLabel',
                onBack: () => Navigator.pop(context, _changed),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  children: [
                    _LabourPeriodStatementCard(
                      name: widget.labourerName,
                      from: widget.from,
                      to: widget.to,
                      stmt: stmt,
                      workLines: lines,
                      onWorkLineTap: _openWorkLineDetail,
                      onPaidTap: _openPaymentsDetail,
                    ),
                    SizedBox(height: 16),
                    Text(tr('Entries'), style: AppText.h3),
                    SizedBox(height: 8),
                    if (rows.isEmpty)
                      AppCard(child: Text(tr('No entries for this labourer')))
                    else
                      ...rows.map((e) {
                        final wage = _num(e['wage']);
                        final hours = _num(e['hours']);
                        final kind = e['entry_kind']?.toString();
                        final amount = wage * hours;
                        final amountColor = laborEntryAmountColor(kind, amount);
                        DateTime? date;
                        try {
                          date = DateTime.parse(e['date'].toString());
                        } catch (_) {}
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            onTap: () => _editEntry(e),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        e['category']?.toString() ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _money(amount.abs()),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: amountColor,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: tr('Delete'),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppColors.expense,
                                        size: 20,
                                      ),
                                      onPressed: () => _deleteEntry(e),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  [
                                    if (date != null)
                                      DateFormat('d MMM yyyy').format(date),
                                    e['shift']?.toString() ?? '',
                                    e['location']?.toString() ?? '',
                                    e['entry_kind']?.toString() ?? '',
                                  ].where((s) => s.isNotEmpty).join(' · '),
                                  style: AppText.caption,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  laborIsPaymentKind(kind)
                                      ? laborRateHoursCaption(
                                          kind, wage, hours)
                                      : '${tr('Rate')} ${laborRateHoursCaption(kind, wage, hours)} · ${e['work_type'] ?? ''}',
                                  style: AppText.caption,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    SizedBox(height: 8),
                    _balanceTile(tr('Closing Balance'), stmt.closing),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full labour entry history across all labourers — searchable, with an
/// alphabetical (by name) / newest-first (by date) sort toggle. Unlike the
/// entry page (which only shows the latest 5 entries), this page loads the
/// complete history.
class LaborHistoryPage extends StatefulWidget {
  const LaborHistoryPage({super.key});

  @override
  State<LaborHistoryPage> createState() => _LaborHistoryPageState();
}

class _LaborHistoryPageState extends State<LaborHistoryPage> {
  final ApiService _api = ApiService();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  bool _sortByName = false;
  bool _searchingPeople = false;
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _peopleSuggestions = [];
  Map<String, dynamic>? _selectedPerson;
  DateTime? _fromDate;
  DateTime? _toDate;
  String _period = 'All';
  String? _filterCategory;
  List<String> _categories = List<String>.from(kLaborWorkCategories);

  @override
  void initState() {
    super.initState();
    loadLaborCategories().then((cats) {
      if (mounted) setState(() => _categories = cats);
    });
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  void _applyPeriod(String period) {
    final now = DateTime.now();
    _period = period;
    if (period == 'Monthly') {
      _fromDate = DateTime(now.year, now.month, 1);
      _toDate = DateTime(now.year, now.month + 1, 0);
    } else if (period == 'Weekly') {
      final weekday = now.weekday;
      _fromDate = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: weekday - 1));
      _toDate = _fromDate!.add(const Duration(days: 6));
    } else {
      _fromDate = null;
      _toDate = null;
    }
  }

  void _sortEntries() {
    if (_sortByName) {
      _entries.sort((a, b) => (a['name']?.toString() ?? '')
          .toLowerCase()
          .compareTo((b['name']?.toString() ?? '').toLowerCase()));
    } else {
      _entries.sort((a, b) {
        final da =
            DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime(2000);
        final db =
            DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final selected = _selectedPerson;
    final name = selected?['name']?.toString().trim();
    final mobile = selected?['mobile']?.toString().trim();
    final rows = await _api.fetchLabors(
      name: (name != null && name.isNotEmpty) ? name : null,
      mobile: (mobile != null && mobile.isNotEmpty) ? mobile : null,
      exactName: selected != null,
      from: _fromDate == null
          ? null
          : DateFormat('yyyy-MM-dd').format(_fromDate!),
      to: _toDate == null ? null : DateFormat('yyyy-MM-dd').format(_toDate!),
      category: _filterCategory,
      limit: 300,
    );
    if (!mounted) return;
    setState(() {
      _entries = rows;
      _sortEntries();
      _loading = false;
    });
  }

  Future<void> _searchPeople(String q) async {
    if (q.isEmpty) {
      if (!mounted) return;
      setState(() {
        _peopleSuggestions = [];
        _searchingPeople = false;
      });
      return;
    }
    setState(() => _searchingPeople = true);
    try {
      final rows = await _api.fetchLaborPeople(q: q);
      if (!mounted) return;
      // Ignore stale results if the field changed or a person was selected.
      if (_searchCtrl.text.trim() != q || _selectedPerson != null) {
        setState(() => _searchingPeople = false);
        return;
      }
      setState(() {
        _peopleSuggestions = rows.take(8).toList();
        _searchingPeople = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _peopleSuggestions = [];
        _searchingPeople = false;
      });
    }
  }

  void _onSearchChanged(String v) {
    final q = v.trim();
    final selectedName = _selectedPerson?['name']?.toString().trim() ?? '';
    if (_selectedPerson != null && q != selectedName) {
      setState(() {
        _selectedPerson = null;
        _peopleSuggestions = [];
      });
      _load();
    }
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchPeople(q),
    );
  }

  void _selectPerson(Map<String, dynamic> person) {
    final name = person['name']?.toString() ?? '';
    setState(() {
      _selectedPerson = person;
      _peopleSuggestions = [];
      _searchingPeople = false;
      _searchCtrl.text = name;
      _searchCtrl.selection = TextSelection.collapsed(offset: name.length);
    });
    FocusScope.of(context).unfocus();
    _load();
  }

  void _clearPersonFilter() {
    _debounce?.cancel();
    setState(() {
      _selectedPerson = null;
      _peopleSuggestions = [];
      _searchingPeople = false;
      _searchCtrl.clear();
    });
    _load();
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked == null) return;
    setState(() {
      _period = 'Custom';
      _fromDate = picked;
    });
    _load();
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked == null) return;
    setState(() {
      _period = 'Custom';
      _toDate = picked;
    });
    _load();
  }

  Future<void> _editEntry(Map<String, dynamic> entry) async {
    final changed = await showLaborEntryEditDialog(context, entry, _api);
    if (changed == true) _load();
  }

  Future<void> _exportExcel() async {
    await shareLabourExcel(_entries, fileName: 'labour_history.xlsx');
  }

  Future<void> _exportPdf() async {
    await shareLabourStatementPdf(
      title: tr('Labour History Statement'),
      entries: _entries,
      fileName: 'labour_history.pdf',
    );
  }

  double get _totalCredit {
    var sum = 0.0;
    for (final e in _entries) {
      final kind = (e['entry_kind']?.toString() ?? 'payable').toLowerCase();
      final amt = _num(e['wage']) * _num(e['hours']);
      if (kind == 'payment' || kind == 'tally') continue;
      if (kind == 'opening' && amt < 0) continue;
      sum += amt;
    }
    return sum;
  }

  double get _totalDebit {
    var sum = 0.0;
    for (final e in _entries) {
      final kind = (e['entry_kind']?.toString() ?? 'payable').toLowerCase();
      final amt = _num(e['wage']) * _num(e['hours']);
      if (kind == 'payment' || (kind == 'opening' && amt < 0)) {
        sum += amt.abs();
      }
    }
    return sum;
  }

  String _money(double v) => '₹${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)}';

  String _entryKindLabel(String? kind, [double amount = 0]) {
    final k = (kind ?? 'payable').toLowerCase();
    if (k == 'payment' || (k == 'opening' && amount < 0)) return tr('Payment');
    if (k == 'tally') return tr('Tally');
    if (k == 'opening') return tr('Payable');
    return tr('Payable');
  }

  Color _entryKindColor(String? kind, [double amount = 0]) =>
      laborEntryAmountColor(kind, amount);

  Map<String, double> _extrasFrom(Map e) {
    final extra = e['extra'];
    double toD(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }
    if (extra is Map) {
      return {
        'rent': toD(extra['rent']),
        'food': toD(extra['food']),
        'bonus': toD(extra['bonus']),
      };
    }
    return {'rent': 0.0, 'food': 0.0, 'bonus': 0.0};
  }

  void _showOthersDetail(Map e) {
    final x = _extrasFrom(e);
    final sum = x['rent']! + x['food']! + x['bonus']!;
    if (sum <= 0) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Others')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${tr('Rent')}: ${_money(x['rent']!)}'),
            const SizedBox(height: 6),
            Text('${tr('Food')}: ${_money(x['food']!)}'),
            const SizedBox(height: 6),
            Text('${tr('Bonus')}: ${_money(x['bonus']!)}'),
            const Divider(),
            Text(
              '${tr('Total')}: ${_money(sum)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Close'))),
        ],
      ),
    );
  }

  Widget _summaryBox(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: tr('History'),
              subtitle: tr('All labour entries'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: withFeedbackAction(
                  context,
                  menu: 'labour_summary',
                  actions: [
                    IconButton(
                      tooltip: tr('Export Excel'),
                      onPressed: _entries.isEmpty ? null : _exportExcel,
                      icon: const Icon(Icons.table_chart_rounded,
                          color: Colors.white),
                    ),
                    IconButton(
                      tooltip: tr('Statement PDF'),
                      onPressed: _entries.isEmpty ? null : _exportPdf,
                      icon: const Icon(Icons.picture_as_pdf_rounded,
                          color: Colors.white),
                    ),
                    IconButton(
                      tooltip: _sortByName
                          ? tr('Sort by date')
                          : tr('Sort by name'),
                      onPressed: () {
                        setState(() {
                          _sortByName = !_sortByName;
                          _sortEntries();
                        });
                      },
                      icon: Icon(
                        _sortByName
                            ? Icons.sort_by_alpha_rounded
                            : Icons.calendar_today_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: tr('Search labourer, then select one'),
                      prefixIcon: const Icon(Icons.person_search_rounded),
                      suffixIcon: _searchCtrl.text.isEmpty &&
                              _selectedPerson == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: _clearPersonFilter,
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  if (_searchingPeople)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (_peopleSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [AppColors.softShadow],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _peopleSuggestions.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: AppColors.border),
                        itemBuilder: (_, i) {
                          final p = _peopleSuggestions[i];
                          final name = p['name']?.toString() ?? '';
                          final mobile = p['mobile']?.toString() ?? '';
                          return InkWell(
                            onTap: () => _selectPerson(p),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySoft,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: const Icon(
                                      Icons.person_outline_rounded,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: AppText.bodyStrong),
                                        if (mobile.isNotEmpty)
                                          Text(
                                            mobile,
                                            style: AppText.caption.copyWith(
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 18,
                                    color: AppColors.primary.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  if (_selectedPerson != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.filter_alt_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${tr('Selected')}: ${_selectedPerson!['name']}'
                              '${(_selectedPerson!['mobile']?.toString() ?? '').isNotEmpty ? ' · ${_selectedPerson!['mobile']}' : ''}',
                              style: AppText.bodyStrong.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: _clearPersonFilter,
                            child: Text(
                              tr('Clear'),
                              style: AppText.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: Text(tr('All')),
                        selected: _period == 'All',
                        onSelected: (_) {
                          setState(() => _applyPeriod('All'));
                          _load();
                        },
                      ),
                      ChoiceChip(
                        label: Text(tr('Monthly')),
                        selected: _period == 'Monthly',
                        onSelected: (_) {
                          setState(() => _applyPeriod('Monthly'));
                          _load();
                        },
                      ),
                      ChoiceChip(
                        label: Text(tr('Weekly')),
                        selected: _period == 'Weekly',
                        onSelected: (_) {
                          setState(() => _applyPeriod('Weekly'));
                          _load();
                        },
                      ),
                      ActionChip(
                        label: Text(
                          _fromDate == null
                              ? tr('From')
                              : DateFormat('d MMM').format(_fromDate!),
                        ),
                        onPressed: _pickFrom,
                      ),
                      ActionChip(
                        label: Text(
                          _toDate == null
                              ? tr('To')
                              : DateFormat('d MMM').format(_toDate!),
                        ),
                        onPressed: _pickTo,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: _filterCategory,
                    decoration: InputDecoration(
                      labelText: tr('Category'),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(tr('All categories')),
                      ),
                      ..._categories.map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _filterCategory = v);
                      _load();
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _summaryBox(
                      tr('Payable'),
                      _loading ? '…' : _money(_totalCredit),
                      AppColors.income,
                      Icons.trending_up_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _summaryBox(
                      tr('Payment'),
                      _loading ? '…' : _money(_totalDebit),
                      AppColors.expense,
                      Icons.trending_down_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _summaryBox(
                      tr('Balance'),
                      _loading ? '…' : _money(_totalCredit - _totalDebit),
                      AppColors.primary,
                      Icons.account_balance_wallet_rounded,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _loading
                      ? tr('Loading…')
                      : laborNumberOfLabourText(
                          formatLaborHours(
                              summarizeLaborEntries(_entries).hours)),
                  style: AppText.caption,
                ),
              ),
            ),
            SizedBox(height: 6),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _entries.isEmpty
                      ? AppCard(
                          margin: const EdgeInsets.all(12),
                          child: EmptyState(
                            icon: Icons.history_rounded,
                            title: tr('No labour entries found'),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                            itemCount: _entries.length,
                            separatorBuilder: (_, _) => SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final e = _entries[i];
                              final wage = _num(e['wage']);
                              final hours = _num(e['hours']);
                              final kind = e['entry_kind']?.toString();
                              final isTally = (kind ?? '').toLowerCase() == 'tally';
                              final isOpening =
                                  (kind ?? '').toLowerCase() == 'opening';
                              final isReset = isTally || isOpening;
                              final signed = wage * hours;
                              final amount = isTally ? 0.0 : signed.abs();
                              final kindColor = _entryKindColor(kind, signed);
                              final extras = _extrasFrom(e);
                              final others =
                                  extras['rent']! + extras['food']! + extras['bonus']!;
                              DateTime? date;
                              try {
                                date = DateTime.parse(e['date'].toString());
                              } catch (_) {}
                              return AppCard(
                                onTap: () => _editEntry(e),
                                padding: const EdgeInsets.all(14),
                                color: isReset
                                    ? kindColor.withValues(alpha: 0.08)
                                    : AppColors.surface,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            e['name']?.toString() ?? '',
                                            style: AppText.bodyStrong.copyWith(
                                              color: isReset ? kindColor : null,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          isTally ? tr('Tally') : _money(amount),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: kindColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 5),
                                    Wrap(
                                      spacing: 5,
                                      runSpacing: 4,
                                      children: [
                                        if ((e['category']?.toString() ?? '')
                                            .isNotEmpty)
                                          InfoChip(
                                            label: e['category'].toString(),
                                            color: isReset
                                                ? kindColor
                                                : AppColors.expense,
                                          ),
                                        InfoChip(
                                          label: _entryKindLabel(kind, signed),
                                          color: kindColor,
                                        ),
                                        if (!isReset &&
                                            (e['shift']?.toString() ?? '')
                                                .isNotEmpty)
                                          InfoChip(
                                            label: e['shift'].toString(),
                                            color: AppColors.warning,
                                          ),
                                        if ((e['location']?.toString() ?? '')
                                            .isNotEmpty)
                                          InfoChip(
                                            label: e['location'].toString(),
                                            color: AppColors.textMuted,
                                          ),
                                        if (others > 0)
                                          GestureDetector(
                                            onTap: () => _showOthersDetail(e),
                                            child: InfoChip(
                                              label:
                                                  '${tr('Others')} ${_money(others)}',
                                              color: AppColors.accent,
                                            ),
                                          ),
                                      ],
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      [
                                        if (date != null)
                                          DateFormat('dd/MM/yyyy').format(date),
                                        if (!isReset)
                                          laborRateHoursCaption(kind, wage, hours),
                                        if (isReset &&
                                            (e['narration']?.toString() ?? '')
                                                .isNotEmpty)
                                          e['narration'].toString(),
                                      ].join('  ·  '),
                                      style: AppText.caption.copyWith(
                                        color: isReset ? kindColor : null,
                                      ),
                                    ),
                                    if ((e['narration']?.toString() ?? '')
                                        .isNotEmpty) ...[
                                      SizedBox(height: 4),
                                      Text(
                                        e['narration'].toString(),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

double _laborNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

String _laborNumText(dynamic v, {String empty = ''}) {
  if (v == null) return empty;
  if (v is String && v.trim().isEmpty) return empty;
  final n = _laborNum(v);
  return n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toString();
}

String _laborEditKindLabel(String? kind) {
  switch ((kind ?? 'payable').toLowerCase()) {
    case 'payment':
      return 'Payment';
    case 'tally':
      return 'Tally';
    case 'opening':
      return 'Opening Balance';
    default:
      return 'Payable';
  }
}

String _laborEditKindValue(String label) {
  switch (label) {
    case 'Payment':
      return 'payment';
    case 'Tally':
      return 'tally';
    case 'Opening Balance':
      return 'opening';
    default:
      return 'payable';
  }
}

Map<String, double> _laborExtrasMap(Map e) {
  final extra = e['extra'];
  if (extra is Map) {
    return {
      'rent': _laborNum(extra['rent']),
      'food': _laborNum(extra['food']),
      'bonus': _laborNum(extra['bonus']),
    };
  }
  return {'rent': 0, 'food': 0, 'bonus': 0};
}

/// Shared edit dialog for a labour entry map (history / detail).
Future<bool?> showLaborEntryEditDialog(
  BuildContext context,
  Map<String, dynamic> entry,
  ApiService api,
) async {
  final idRaw = entry['id'];
  final id = idRaw is int ? idRaw : int.tryParse('$idRaw');
  if (id == null) return false;

  var categories = List<String>.from(kLaborWorkCategories);
  try {
    categories = [...await loadLaborCategories()];
  } catch (_) {}
  if (!context.mounted) return false;

  final payload = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => _LaborEntryEditDialog(
      entry: entry,
      categories: categories,
    ),
  );
  if (payload == null) return false;

  final result = await api.updateLabor(id, payload);
  if (result['success'] == true) return true;
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? tr('Update failed')),
        backgroundColor: AppColors.expense,
      ),
    );
  }
  return false;
}

class _LaborEntryEditDialog extends StatefulWidget {
  final Map<String, dynamic> entry;
  final List<String> categories;

  const _LaborEntryEditDialog({
    required this.entry,
    required this.categories,
  });

  @override
  State<_LaborEntryEditDialog> createState() => _LaborEntryEditDialogState();
}

class _LaborEntryEditDialogState extends State<_LaborEntryEditDialog> {
  static const _shifts = ['fullday', 'morning', 'evening', 'night'];
  static const _genders = ['Male', 'Female'];
  static const _workTypes = ['Daily Wages', 'Contract'];
  static const _kindLabels = ['Payable', 'Payment', 'Tally', 'Opening Balance'];
  static const _defaultLocations = [
    'Farm',
    'Warehouse',
    'Processing Unit',
    'Field',
  ];

  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _wageCtrl;
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _labourHeadCtrl;
  late final TextEditingController _narrationCtrl;
  late final TextEditingController _rentCtrl;
  late final TextEditingController _foodCtrl;
  late final TextEditingController _bonusCtrl;
  late DateTime _date;
  late String _shift;
  late String _gender;
  late String _category;
  late String _location;
  late String _workType;
  late String _kindLabel;
  late List<String> _categories;
  late List<String> _locations;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    final extras = _laborExtrasMap(e);
    _nameCtrl = TextEditingController(text: e['name']?.toString() ?? '');
    _mobileCtrl = TextEditingController(text: e['mobile']?.toString() ?? '');
    _wageCtrl = TextEditingController(text: _laborNumText(e['wage']));
    _hoursCtrl = TextEditingController(
      text: _laborNumText(e['hours'], empty: '1'),
    );
    _labourHeadCtrl =
        TextEditingController(text: e['labour_head']?.toString() ?? '');
    _narrationCtrl =
        TextEditingController(text: e['narration']?.toString() ?? '');
    _rentCtrl = TextEditingController(text: _laborNumText(extras['rent']));
    _foodCtrl = TextEditingController(text: _laborNumText(extras['food']));
    _bonusCtrl = TextEditingController(text: _laborNumText(extras['bonus']));
    _date = DateTime.tryParse(e['date']?.toString() ?? '') ?? DateTime.now();

    final shift = (e['shift']?.toString() ?? 'fullday').trim();
    _shift = shift.isEmpty ? 'fullday' : shift;
    final gender = (e['gender']?.toString() ?? 'Male').trim();
    _gender = _genders.contains(gender) ? gender : 'Male';
    _category = (e['category']?.toString() ?? '').trim();
    final location = (e['location']?.toString() ?? 'Farm').trim();
    _location = location.isEmpty ? 'Farm' : location;
    final workType = (e['work_type']?.toString() ?? 'Daily Wages').trim();
    _workType = _workTypes.contains(workType) ? workType : 'Daily Wages';
    _kindLabel = _laborEditKindLabel(e['entry_kind']?.toString());

    _categories = [...widget.categories];
    if (_category.isNotEmpty && !_categories.contains(_category)) {
      _categories = [..._categories, _category];
    }
    _locations = [..._defaultLocations];
    if (!_locations.contains(_location)) {
      _locations = [..._locations, _location];
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _wageCtrl.dispose();
    _hoursCtrl.dispose();
    _labourHeadCtrl.dispose();
    _narrationCtrl.dispose();
    _rentCtrl.dispose();
    _foodCtrl.dispose();
    _bonusCtrl.dispose();
    super.dispose();
  }

  bool get _isContract => _workType == 'Contract';
  bool get _isTally => _kindLabel == 'Tally';
  bool get _isOpening => _kindLabel == 'Opening Balance';

  void _save() {
    final name = _nameCtrl.text.trim();
    final wage = double.tryParse(_wageCtrl.text.trim()) ?? 0;
    final hours = double.tryParse(_hoursCtrl.text.trim()) ?? 0;
    final category = _category.trim();
    final narration = _narrationCtrl.text.trim();
    final labourHead = _labourHeadCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();
    final rent = double.tryParse(_rentCtrl.text.trim()) ?? 0;
    final food = double.tryParse(_foodCtrl.text.trim()) ?? 0;
    final bonus = double.tryParse(_bonusCtrl.text.trim()) ?? 0;
    final kind = _laborEditKindValue(_kindLabel);

    if (name.isEmpty) {
      setState(() => _error = tr('Name is required'));
      return;
    }
    if (mobile.isNotEmpty && mobile.length != 10) {
      setState(() => _error = tr('Mobile must be 10 digits'));
      return;
    }
    if (_isTally || _isOpening) {
      if (narration.isEmpty) {
        setState(() => _error = tr('Narration is required'));
        return;
      }
      if (_isOpening && wage == 0) {
        setState(() => _error = tr('Enter payable or payment amount'));
        return;
      }
    } else {
      if (wage <= 0) {
        setState(() => _error = tr('Enter valid rate'));
        return;
      }
      if (hours <= 0) {
        setState(() => _error = tr('Enter valid days/hour'));
        return;
      }
    }
    if (category.isEmpty) {
      setState(() => _error = tr('Category is required'));
      return;
    }
    if (_isContract && labourHead.isEmpty) {
      setState(() => _error = tr('Labour head is required for Contract'));
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    final e = widget.entry;
    Navigator.pop(context, <String, dynamic>{
      'name': name,
      'wage': _isTally ? 0 : wage,
      'hours': hours > 0 ? hours : 1,
      'category': category,
      'narration': narration,
      'date': DateFormat('yyyy-MM-dd').format(_date),
      'shift': _shift,
      'gender': _gender,
      'work_type': _workType,
      'labour_head': _isContract ? labourHead : '',
      'location': _location,
      'number_of_labours': e['number_of_labours'] ?? 1,
      'entry_kind': kind,
      'rent': rent,
      'food': food,
      'bonus': bonus,
      if (mobile.isNotEmpty) 'mobile': mobile,
    });
  }

  @override
  Widget build(BuildContext context) {
    final shiftItems = _shifts.contains(_shift) ? _shifts : [..._shifts, _shift];
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('Edit labour entry'), style: AppText.h3),
              SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(labelText: tr('Name')),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _mobileCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(labelText: tr('Mobile')),
                      ),
                      SizedBox(height: 8),
                      AppDropdown(
                        label: 'Type',
                        value: _kindLabel,
                        items: _kindLabels,
                        icon: Icons.swap_vert_rounded,
                        onChanged: (v) =>
                            setState(() => _kindLabel = v ?? _kindLabel),
                      ),
                      SizedBox(height: 8),
                      AppDropdown(
                        label: 'Work Type',
                        value: _workType,
                        items: _workTypes,
                        icon: Icons.work_outline_rounded,
                        onChanged: (v) =>
                            setState(() => _workType = v ?? 'Daily Wages'),
                      ),
                      if (_isContract) ...[
                        SizedBox(height: 8),
                        TextField(
                          controller: _labourHeadCtrl,
                          decoration:
                              InputDecoration(labelText: tr('Labour Head')),
                        ),
                      ],
                      SizedBox(height: 8),
                      AppDropdown(
                        label: 'Category',
                        value: _categories.contains(_category) ? _category : null,
                        items: _categories,
                        icon: Icons.category_rounded,
                        onChanged: (v) {
                          if (v != null) setState(() => _category = v);
                        },
                      ),
                      SizedBox(height: 8),
                      AppDropdown(
                        label: 'Shift',
                        value: shiftItems.contains(_shift) ? _shift : null,
                        items: shiftItems,
                        icon: Icons.wb_sunny_rounded,
                        onChanged: (v) =>
                            setState(() => _shift = v ?? 'fullday'),
                      ),
                      SizedBox(height: 8),
                      AppDropdown(
                        label: 'Location',
                        value: _locations.contains(_location) ? _location : null,
                        items: _locations,
                        icon: Icons.location_on_rounded,
                        onChanged: (v) =>
                            setState(() => _location = v ?? _location),
                      ),
                      SizedBox(height: 8),
                      AppDropdown(
                        label: 'Gender',
                        value: _gender,
                        items: _genders,
                        icon: Icons.wc_rounded,
                        onChanged: (v) =>
                            setState(() => _gender = v ?? 'Male'),
                      ),
                      if (!_isTally) ...[
                        SizedBox(height: 8),
                        if (_isOpening)
                          TextField(
                            controller: _wageCtrl,
                            decoration: InputDecoration(
                              labelText: tr('Amount'),
                              helperText: tr(
                                'Positive = payable, negative = payment',
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _wageCtrl,
                                  decoration:
                                      InputDecoration(labelText: tr('Wage')),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _hoursCtrl,
                                  decoration: InputDecoration(
                                      labelText: tr('Days / Hour')),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                ),
                              ),
                            ],
                          ),
                        if (!_isOpening) ...[
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _rentCtrl,
                                  decoration:
                                      InputDecoration(labelText: tr('Rent')),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _foodCtrl,
                                  decoration:
                                      InputDecoration(labelText: tr('Food')),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _bonusCtrl,
                                  decoration:
                                      InputDecoration(labelText: tr('Bonus')),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                      SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today_rounded,
                            color: AppColors.primary),
                        title: Text(DateFormat('dd/MM/yyyy').format(_date)),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                          );
                          if (picked != null) setState(() => _date = picked);
                        },
                      ),
                      TextField(
                        controller: _narrationCtrl,
                        decoration: InputDecoration(
                          labelText: (_isTally || _isOpening)
                              ? tr('Narration')
                              : tr('Narration (optional)'),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.expense,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.pop(context);
                    },
                    child: Text(tr('Cancel')),
                  ),
                  FilledButton(
                    onPressed: _save,
                    child: Text(tr('Save')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
