import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'auth_token.dart';
import 'feedback_fab.dart';
import 'labor_categories.dart';
import 'labour_summary.dart';
import 'l10n/app_l10n.dart';
import 'login.dart';
import 'voice_dictation.dart';

const double _fieldHeight = 48;

class _PendingLabour {
  final String name;
  final String? mobile;
  final String shift;
  final double daysHour;
  final String gender;
  final double rate;
  final String category;

  const _PendingLabour({
    required this.name,
    this.mobile,
    required this.shift,
    required this.daysHour,
    required this.gender,
    required this.rate,
    required this.category,
  });

  double get totalCost => rate * daysHour;
}

class LaborManagementPage extends StatefulWidget {
  const LaborManagementPage({super.key});

  @override
  _LaborManagementPageState createState() => _LaborManagementPageState();
}

class _LaborManagementPageState extends State<LaborManagementPage>
    with SingleTickerProviderStateMixin {
  final List<Laborer> _laborers = [];
  final List<_PendingLabour> _pending = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _daysHourController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _labourHeadController = TextEditingController();
  final TextEditingController _narrationController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _paymentAmountController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedWorkType = 'Daily Wages';
  String? _selectedLocation = 'Farm';
  String _selectedShift = 'fullday';
  String _selectedGender = 'Male';
  String _selectedCategory = 'Plucking';
  /// Top mode: Payable (work accrual) or Payment (settlement).
  String _entryMode = 'Payable';
  /// Before save in Payable mode: mark entire total as paid.
  bool _settleAsPaid = false;
  /// Outstanding balance for selected labourer (green chip).
  double? _labourBalance;
  double? _labourPayable;
  double? _labourReceivable;
  /// True when selected labourer has no opening balance yet.
  bool _labourNeedsOpening = false;

  final List<String> _workTypes = ['Daily Wages', 'Contract'];
  final List<String> _shifts = ['fullday', 'morning', 'evening', 'hour'];
  final List<String> _genders = ['Male', 'Female'];
  List<String> _categories = List<String>.from(kLaborWorkCategories);
  final List<String> _locations = [
    'Farm',
    'Warehouse',
    'Processing Unit',
    'Field',
  ];

  late AnimationController _animController;
  late CurvedAnimation _fadeAnim;
  String _searchQuery = '';
  bool _loading = true;
  bool _submitting = false;
  final ApiService _api = ApiService();
  /// Settings rate per category for the current labourer (takes priority).
  Map<String, double> _ratesForLabourer = {};
  /// Latest historically entered rate per category, used as a fallback
  /// when no settings rate exists for that category.
  Map<String, double> _latestRatesForLabourer = {};
  /// Name suggestions shown below the Name field while typing.
  List<String> _nameSuggestions = [];
  bool _suppressSuggestions = false;
  Timer? _rateLookupDebounce;
  bool _suppressIdentityListener = false;
  bool _identityRebuildScheduled = false;

  bool get _isContract => _selectedWorkType == 'Contract';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _nameController.addListener(_onLabourerIdentityChanged);
    _mobileController.addListener(_onLabourerIdentityChanged);
    _loadLabors();
    _loadCategories();
  }

  @override
  void dispose() {
    _rateLookupDebounce?.cancel();
    _nameController.removeListener(_onLabourerIdentityChanged);
    _mobileController.removeListener(_onLabourerIdentityChanged);
    _fadeAnim.dispose();
    _animController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _daysHourController.dispose();
    _rateController.dispose();
    _labourHeadController.dispose();
    _narrationController.dispose();
    _paidAmountController.dispose();
    _paymentAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cats = await loadLaborCategories();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      if (!_categories.contains(_selectedCategory) && _categories.isNotEmpty) {
        _selectedCategory = _categories.first;
      }
    });
  }

  void _onLabourerIdentityChanged() {
    if (_suppressIdentityListener || !mounted) return;

    // Avoid nested setState while Add/Save is already rebuilding the tree.
    if (!_identityRebuildScheduled) {
      _identityRebuildScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _identityRebuildScheduled = false;
        if (mounted) setState(() {});
      });
    }

    _suppressSuggestions = false;
    _rateLookupDebounce?.cancel();
    final mobile = _mobileController.text.trim();
    final name = _nameController.text.trim();
    if (mobile.length == 10) {
      _rateLookupDebounce = Timer(const Duration(milliseconds: 350), () {
        _loadRatesForLabourer(mobile: mobile, name: name);
      });
      return;
    }
    if (name.length < 2) {
      _ratesForLabourer = {};
      _latestRatesForLabourer = {};
      _nameSuggestions = [];
      _labourBalance = null;
      _labourPayable = null;
      _labourReceivable = null;
      return;
    }
    _rateLookupDebounce = Timer(const Duration(milliseconds: 400), () {
      _loadRatesForLabourer(name: name);
    });
  }

  void _clearLabourerIdentityFields() {
    _suppressIdentityListener = true;
    _nameController.clear();
    _mobileController.clear();
    _suppressIdentityListener = false;
    _addressController.clear();
    _ratesForLabourer = {};
    _latestRatesForLabourer = {};
    _nameSuggestions = [];
    _suppressSuggestions = false;
    _labourBalance = null;
    _labourPayable = null;
    _labourReceivable = null;
    _labourNeedsOpening = false;
  }

  Future<void> _refreshLabourBalance({String? mobile, String? name}) async {
    final m = (mobile ?? _mobileController.text).trim();
    final n = (name ?? _nameController.text).trim();
    if (m.isEmpty && n.length < 2) {
      if (mounted) {
        setState(() {
          _labourBalance = null;
          _labourPayable = null;
          _labourReceivable = null;
        });
      }
      return;
    }
    final bal = await _api.fetchLaborBalance(
      mobile: m.isNotEmpty ? m : null,
      name: m.isEmpty ? n : null,
    );
    if (!mounted) return;
    setState(() {
      if (bal == null) {
        _labourBalance = null;
        _labourPayable = null;
        _labourReceivable = null;
      } else {
        _labourBalance = (bal['balance'] is num)
            ? (bal['balance'] as num).toDouble()
            : double.tryParse('${bal['balance']}');
        _labourPayable = (bal['payable'] is num)
            ? (bal['payable'] as num).toDouble()
            : double.tryParse('${bal['payable']}');
        _labourReceivable = (bal['receivable'] is num)
            ? (bal['receivable'] as num).toDouble()
            : double.tryParse('${bal['receivable']}');
      }
    });
  }

  /// Loads both the "settings" rate (explicit per-labourer rate, set via the
  /// rate popup) and the "latest" historically entered rate per category for
  /// the labourer identified by [mobile] and/or [name]. Settings rates take
  /// priority; latest entered rate is the fallback (requirement: settings
  /// rate OR latest entered rate). Also refreshes name suggestions.
  Future<void> _loadRatesForLabourer({String? mobile, String? name}) async {
    final byMobile = mobile != null && mobile.isNotEmpty;
    final results = await Future.wait([
      _api.fetchLaborRates(mobile: mobile, name: byMobile ? null : name),
      _api.fetchLabors(
        mobile: mobile,
        name: byMobile ? null : name,
        limit: 30,
      ),
    ]);
    if (!mounted) return;

    final settingsRows = results[0];
    final historyRows = results[1];

    final settingsMap = <String, double>{};
    for (final r in settingsRows) {
      final cat = r['category']?.toString() ?? '';
      final rate = r['rate'];
      final value = rate is num
          ? rate.toDouble()
          : double.tryParse(rate?.toString() ?? '');
      if (cat.isNotEmpty && value != null && value > 0) {
        settingsMap[cat] = value;
      }
    }

    final latestMap = <String, double>{};
    final suggestions = <String>{};
    final query = (name ?? '').trim().toLowerCase();
    for (final r in historyRows) {
      final cat = r['category']?.toString() ?? '';
      if (cat.isNotEmpty && !latestMap.containsKey(cat)) {
        final wage = r['wage'];
        final value = wage is num
            ? wage.toDouble()
            : double.tryParse(wage?.toString() ?? '');
        if (value != null && value > 0) latestMap[cat] = value;
      }
      if (!byMobile) {
        final n = r['name']?.toString().trim() ?? '';
        if (n.isNotEmpty && n.toLowerCase() != query) suggestions.add(n);
      }
    }

    setState(() {
      _ratesForLabourer = settingsMap;
      _latestRatesForLabourer = latestMap;
      if (!_suppressSuggestions) {
        final list = suggestions.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _nameSuggestions = list.take(5).toList();
      }
    });
    _applyRateForSelectedCategory();
    await _refreshLabourBalance(mobile: mobile, name: name);
  }

  void _applyRateForSelectedCategory() {
    final rate =
        _ratesForLabourer[_selectedCategory] ?? _latestRatesForLabourer[_selectedCategory];
    if (rate == null || rate <= 0) return;
    _rateController.text = rate.toStringAsFixed(0);
  }

  /// Fills the name field with a picked suggestion, then restores any saved
  /// mobile/address and loads rates for that labourer.
  Future<void> _selectNameSuggestion(String name) async {
    _suppressIdentityListener = true;
    _nameController.text = name;
    _nameController.selection = TextSelection.collapsed(offset: name.length);
    _suppressIdentityListener = false;
    setState(() {
      _nameSuggestions = [];
      _suppressSuggestions = true;
    });
    FocusManager.instance.primaryFocus?.unfocus();

    final savedMobile = await loadLaborMobile(name);
    final savedAddress = await loadLaborAddress(name);
    if (!mounted) return;
    _suppressIdentityListener = true;
    _mobileController.text = savedMobile ?? '';
    _suppressIdentityListener = false;
    setState(() => _addressController.text = savedAddress ?? '');

    await _loadRatesForLabourer(
      mobile: (savedMobile != null && savedMobile.length == 10)
          ? savedMobile
          : null,
      name: name,
    );
    await _ensureLabourOpeningBalance(
      mobile: (savedMobile != null && savedMobile.length == 10)
          ? savedMobile
          : null,
      name: name,
    );
  }

  /// Returns true if this labourer already has an opening entry, or one was just saved.
  Future<bool> _ensureLabourOpeningBalance({
    String? mobile,
    String? name,
    bool forcePrompt = false,
  }) async {
    final m = (mobile ?? _mobileController.text).trim();
    final n = (name ?? _nameController.text).trim();
    if (n.length < 2 && m.isEmpty) return true;

    final openings = await _api.fetchLabors(
      mobile: m.isNotEmpty ? m : null,
      name: m.isEmpty ? n : null,
      entryKind: 'opening',
      limit: 1,
    );
    if (!mounted) return false;
    if (openings.isNotEmpty && !forcePrompt) {
      setState(() => _labourNeedsOpening = false);
      return true;
    }

    final saved = await _showOpeningBalanceDialog(
      requiredEntry: true,
      prefName: n,
      prefMobile: m,
    );
    if (!mounted) return false;
    setState(() => _labourNeedsOpening = saved != true);
    return saved == true;
  }

  Future<bool?> _showOpeningBalanceDialog({
    bool requiredEntry = false,
    String? prefName,
    String? prefMobile,
  }) async {
    final nameCtrl = TextEditingController(
      text: (prefName ?? _nameController.text).trim(),
    );
    final mobileCtrl = TextEditingController(
      text: (prefMobile ?? _mobileController.text).trim(),
    );
    final amountCtrl = TextEditingController();
    DateTime date = _selectedDate;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: !requiredEntry,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      requiredEntry
                          ? tr('Opening Balance Required')
                          : tr('Opening Balance'),
                      style: AppText.h3,
                    ),
                    if (requiredEntry) ...[
                      SizedBox(height: 6),
                      Text(
                        tr('Enter opening amount for this labourer before continuing.'),
                        style: AppText.caption,
                      ),
                    ],
                    SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      readOnly: requiredEntry && nameCtrl.text.trim().isNotEmpty,
                      decoration: InputDecoration(
                        labelText: tr('Name'),
                        prefixIcon: const Icon(Icons.person_rounded),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: mobileCtrl,
                      decoration: InputDecoration(
                        labelText: tr('Mobile (optional)'),
                        prefixIcon: const Icon(Icons.phone_rounded),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: amountCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: tr('Opening amount'),
                        prefixIcon: const Icon(Icons.currency_rupee_rounded),
                        helperText: tr('Positive = payable opening'),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_rounded,
                          color: AppColors.primary),
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
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!requiredEntry)
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(tr('Cancel')),
                          )
                        else
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(tr('Later')),
                          ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(tr('Save')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    final name = nameCtrl.text.trim();
    final mobile = mobileCtrl.text.trim();
    final amount = double.tryParse(amountCtrl.text.trim());
    nameCtrl.dispose();
    mobileCtrl.dispose();
    amountCtrl.dispose();

    if (ok != true) return false;
    if (name.isEmpty) {
      _showSnack(tr('Enter labourer name'), error: true);
      return false;
    }
    if (amount == null || amount == 0) {
      _showSnack(tr('Enter valid amount'), error: true);
      return false;
    }
    if (mobile.isNotEmpty && mobile.length != 10) {
      _showSnack(tr('Mobile must be 10 digits'), error: true);
      return false;
    }

    var token = await getAuthToken();
    if (token == null || token.isEmpty) {
      final loggedIn = await _promptLoginForSave();
      if (loggedIn != true) return false;
    }

    setState(() => _submitting = true);
    final result = await _api.createLabor({
      'name': name,
      if (mobile.isNotEmpty) 'mobile': mobile,
      'wage': amount.abs(),
      'hours': 1,
      'number_of_labours': 1,
      'entry_kind': 'opening',
      'category': 'Opening Balance',
      'shift': 'fullday',
      'gender': _selectedGender,
      'work_type': 'Daily Wages',
      'location': _selectedLocation ?? 'Farm',
      'date': DateFormat('yyyy-MM-dd').format(date),
      'narration': tr('Opening Balance'),
    });
    if (!mounted) return false;
    setState(() => _submitting = false);
    if (result['success'] == true) {
      _showSnack(tr('Opening balance saved'));
      setState(() => _labourNeedsOpening = false);
      await _refreshLabourBalance(
        mobile: mobile.isNotEmpty ? mobile : null,
        name: name,
      );
      await _loadLabors();
      return true;
    }
    _showSnack(
      result['message']?.toString() ?? tr('Failed to save opening balance'),
      error: true,
    );
    return false;
  }

  Future<void> _loadLabors() async {
    setState(() => _loading = true);
    // Only the latest entries are shown below the entry form; use History
    // for the full list.
    final rows = await _api.fetchLabors(limit: 5);
    if (!mounted) return;
    setState(() {
      _laborers
        ..clear()
        ..addAll(rows.map(Laborer.fromJson));
      for (final labor in _laborers) {
        if (labor.location.isNotEmpty && !_locations.contains(labor.location)) {
          _locations.add(labor.location);
        }
      }
      _loading = false;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
          child: child!,
        );
      },
    );
    if (!mounted) return;
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.expense : AppColors.primary,
      ),
    );
  }

  Future<void> _showLaborRatesPopup() async {
    final mobile = _mobileController.text.trim();
    final name = _nameController.text.trim();
    if (mobile.isEmpty && name.isEmpty) {
      _showSnack('Enter labourer name or mobile first', error: true);
      return;
    }

    final existing = await _api.fetchLaborRates(
      mobile: mobile.isEmpty ? null : mobile,
      name: mobile.isEmpty ? name : null,
    );
    if (!mounted) return;

    final controllers = <String, TextEditingController>{};
    for (final cat in _categories) {
      String rateVal = '';
      for (final r in existing) {
        if (r['category']?.toString() == cat) {
          final raw = r['rate'];
          rateVal = raw is num
              ? raw.toStringAsFixed(0)
              : (raw?.toString() ?? '');
          break;
        }
      }
      if (rateVal.isEmpty && _ratesForLabourer[cat] != null) {
        rateVal = _ratesForLabourer[cat]!.toStringAsFixed(0);
      }
      controllers[cat] = TextEditingController(text: rateVal);
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
          contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Labour Rates',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDeep,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit rates for this labourer. Tap category to apply to Rate field.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.55,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.field,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () {
                              final rate = double.tryParse(
                                  controllers[cat]!.text.trim());
                              setState(() => _selectedCategory = cat);
                              if (rate != null && rate > 0) {
                                _rateController.text = rate.toStringAsFixed(0);
                              }
                              Navigator.pop(ctx);
                            },
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    cat,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDeep,
                                    ),
                                  ),
                                ),
                                Icon(Icons.check_circle_outline,
                                    size: 14, color: Colors.green.shade700),
                              ],
                            ),
                          ),
                          const Spacer(),
                          TextField(
                            controller: controllers[cat],
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              prefixText: '₹ ',
                              hintText: tr('Rate'),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('Cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final rates = <String, double>{};
                for (final cat in _categories) {
                  final v = double.tryParse(controllers[cat]!.text.trim());
                  if (v != null && v >= 0) rates[cat] = v;
                }
                if (rates.isEmpty) {
                  Navigator.pop(ctx);
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                final ok = await _api.saveLaborRates(
                  mobile: mobile.isEmpty ? null : mobile,
                  name: name.isEmpty ? null : name,
                  rates: rates,
                );
                if (ok) {
                  setState(() => _ratesForLabourer = rates);
                  _applyRateForSelectedCategory();
                }
                if (ctx.mounted) Navigator.pop(ctx);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                        ok ? 'Labour rates saved' : 'Failed to save rates'),
                    backgroundColor: ok ? AppColors.primary : Colors.red,
                  ),
                );
              },
              child: Text(tr('Save Rates')),
            ),
          ],
        );
      },
    );

    // Dispose after the dialog route finishes removing (avoids TextField
    // using a disposed controller during the close animation).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in controllers.values) {
        c.dispose();
      }
    });
  }

  Future<void> _addLocation() async {
    // Unfocus form fields so the soft keyboard does not sit on top of
    // dialog actions (common cause of "Cancel/Add do nothing" on phones).
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _AddLocationDialog(),
    );
    if (!mounted || result == null) return;
    if (result.isEmpty) {
      _showSnack('Enter a location name', error: true);
      return;
    }
    setState(() {
      if (!_locations.contains(result)) {
        _locations.add(result);
      }
      _selectedLocation = result;
    });
    _showSnack('Location "$result" added');
  }

  Future<void> _addCategory() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _AddCategoryDialog(),
    );
    if (!mounted || result == null) return;
    if (result.isEmpty) {
      _showSnack('Enter a category name', error: true);
      return;
    }
    final updated = await addCustomLaborCategory(result);
    if (!mounted) return;
    final match = updated.firstWhere(
      (c) => c.toLowerCase() == result.toLowerCase(),
      orElse: () => result,
    );
    setState(() {
      _categories = updated;
      _selectedCategory = match;
    });
    _applyRateForSelectedCategory();
    _showSnack('Category "$match" added');
  }

  Future<void> _showCategorySearchDialog() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => _CategorySearchDialog(categories: _categories),
    );
    if (selected != null && mounted) {
      setState(() => _selectedCategory = selected);
      _applyRateForSelectedCategory();
    }
  }

  Future<void> _showAdditionalInfoDialog() async {
    final name = _nameController.text.trim();
    final mobileCtrl = TextEditingController(text: _mobileController.text.trim());
    final addressCtrl = TextEditingController(text: _addressController.text);

    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Additional information')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: mobileCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: tr('Mobile'),
                  filled: true,
                  prefixIcon: const Icon(Icons.phone_rounded),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: tr('Address'),
                  filled: true,
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final m = mobileCtrl.text.trim();
              if (m.isNotEmpty && m.length != 10) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(tr('Mobile must be 10 digits')),
                    backgroundColor: AppColors.expense,
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: Text(tr('Save')),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      final mobile = mobileCtrl.text.trim();
      final address = addressCtrl.text.trim();
      _suppressIdentityListener = true;
      _mobileController.text = mobile;
      _suppressIdentityListener = false;
      setState(() => _addressController.text = address);
      if (name.isNotEmpty) {
        await saveLaborMobile(name, mobile);
        await saveLaborAddress(name, address);
      }
      if (mobile.length == 10) {
        _loadRatesForLabourer(mobile: mobile, name: name);
      }
    }
    mobileCtrl.dispose();
    addressCtrl.dispose();
  }

  Future<void> _addPendingLabour() async {
    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final daysHourText = _daysHourController.text.trim();
    final rateText = _rateController.text.trim();

    if (name.isEmpty) {
      _showSnack('Enter labourer name', error: true);
      return;
    }
    final openingOk = await _ensureLabourOpeningBalance(
      mobile: mobile.isNotEmpty ? mobile : null,
      name: name,
    );
    if (openingOk != true) {
      _showSnack(tr('Opening balance is required for this labourer'),
          error: true);
      return;
    }
    if (mobile.isNotEmpty && mobile.length != 10) {
      _showSnack('Mobile must be 10 digits', error: true);
      return;
    }
    final daysHour = double.tryParse(daysHourText);
    final rate = double.tryParse(rateText);
    if (daysHour == null || daysHour <= 0) {
      _showSnack('Enter valid days/hour', error: true);
      return;
    }
    if (rate == null || rate <= 0) {
      _showSnack('Enter valid rate', error: true);
      return;
    }

    setState(() {
      _pending.add(_PendingLabour(
        name: name,
        mobile: mobile.isEmpty ? null : mobile,
        shift: _selectedShift,
        daysHour: daysHour,
        gender: _selectedGender,
        rate: rate,
        category: _selectedCategory,
      ));
    });
    // Remember mobile/address for this name so autocomplete can restore it.
    if (mobile.isNotEmpty) saveLaborMobile(name, mobile);
    if (_addressController.text.trim().isNotEmpty) {
      saveLaborAddress(name, _addressController.text.trim());
    }
    // Clear after setState so listeners cannot nest rebuilds.
    _clearLabourerIdentityFields();
    if (mounted) setState(() {});
  }

  Future<void> _removePending(int index) async {
    final ok = await _confirmDelete(
      title: tr('Remove labourer?'),
      message: 'Remove this labourer from the pending list?',
    );
    if (ok != true || !mounted) return;
    setState(() => _pending.removeAt(index));
  }

  Future<void> _submitPayment() async {
    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final amount = double.tryParse(_paymentAmountController.text.trim());
    final narration = _narrationController.text.trim();

    if (name.isEmpty) {
      _showSnack(tr('Enter labourer name'), error: true);
      return;
    }
    final openingOk = await _ensureLabourOpeningBalance(
      mobile: mobile.isNotEmpty ? mobile : null,
      name: name,
    );
    if (openingOk != true) {
      _showSnack(tr('Opening balance is required for this labourer'),
          error: true);
      return;
    }
    if (mobile.isNotEmpty && mobile.length != 10) {
      _showSnack(tr('Mobile must be 10 digits'), error: true);
      return;
    }
    if (amount == null || amount <= 0) {
      _showSnack(tr('Enter valid amount'), error: true);
      return;
    }

    var token = await getAuthToken();
    if (token == null || token.isEmpty) {
      final ok = await _promptLoginForSave();
      if (ok != true) return;
      token = await getAuthToken();
      if (token == null || token.isEmpty) {
        _showSnack(tr('Login required to save labour'), error: true);
        return;
      }
    }

    final payload = <String, dynamic>{
      'name': name,
      if (mobile.isNotEmpty) 'mobile': mobile,
      'wage': amount,
      'hours': 1,
      'number_of_labours': 1,
      'entry_kind': 'payment',
      'shift': 'fullday',
      'category': 'Payment',
      'gender': _selectedGender,
      'work_type': 'Daily Wages',
      'location': _selectedLocation ?? 'Farm',
      'narration': narration.isNotEmpty ? narration : tr('Payment'),
      'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
    };

    setState(() => _submitting = true);
    var result = await _api.createLabor(payload);
    if (!mounted) return;
    if (result['success'] != true && _isAuthFailure(result)) {
      setState(() => _submitting = false);
      final ok = await _promptLoginForSave();
      if (ok == true && mounted) {
        setState(() => _submitting = true);
        result = await _api.createLabor(payload);
        if (!mounted) return;
      }
    }
    setState(() => _submitting = false);

    if (result['success'] != true) {
      final msg = result['message']?.toString() ?? tr('Failed to save payment');
      if (_isAuthFailure(result)) {
        await _showJwtExpiredDialog(msg);
      } else {
        _showSnack(msg, error: true);
      }
      return;
    }

    setState(() {
      _paymentAmountController.clear();
      _narrationController.clear();
      _selectedDate = DateTime.now();
    });
    _clearLabourerIdentityFields();
    await _loadLabors();
    _showSnack(tr('Payment saved'));
  }

  Future<void> _submitLabours() async {
    if (_entryMode == 'Payment') {
      await _submitPayment();
      return;
    }

    final narration = _narrationController.text.trim();
    final labourHead = _labourHeadController.text.trim();

    if (_selectedLocation == null || _selectedLocation!.isEmpty) {
      _showSnack(tr('Please select a location'), error: true);
      return;
    }
    if (_isContract && labourHead.isEmpty) {
      _showSnack(tr('Labour head is required for Contract'), error: true);
      return;
    }
    // Direct save: if fields are filled but user forgot "Add", queue them.
    if (_pending.isEmpty && _nameController.text.trim().isNotEmpty) {
      final before = _pending.length;
      await _addPendingLabour();
      if (_pending.length == before) {
        // Validation inside _addPendingLabour already showed a snack.
        return;
      }
    }
    if (_pending.isEmpty) {
      _showSnack(tr('Add at least one labourer'), error: true);
      return;
    }

    // Saving requires a valid login — guest browse is allowed, write is not.
    var token = await getAuthToken();
    if (token == null || token.isEmpty) {
      final ok = await _promptLoginForSave();
      if (ok != true) return;
      token = await getAuthToken();
      if (token == null || token.isEmpty) {
        _showSnack(tr('Login required to save labour'), error: true);
        return;
      }
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final partialPaid = double.tryParse(_paidAmountController.text.trim());
    final payloads = <Map<String, dynamic>>[];
    for (var i = 0; i < _pending.length; i++) {
      final row = _pending[i];
      final map = <String, dynamic>{
        'name': row.name,
        'wage': row.rate,
        'hours': row.daysHour,
        'number_of_labours': 1,
        'shift': row.shift,
        'category': row.category,
        'gender': row.gender,
        'work_type': _selectedWorkType,
        'labour_head': _isContract ? labourHead : '',
        'location': _selectedLocation,
        'narration': narration,
        'date': dateStr,
        'entry_kind': 'payable',
        if (row.mobile != null && row.mobile!.isNotEmpty) 'mobile': row.mobile,
      };
      if (_settleAsPaid) {
        map['paid_amount'] = row.totalCost;
      } else if (partialPaid != null && partialPaid > 0) {
        // Apply explicit partial payment to first row only (batch-safe).
        if (i == 0) map['paid_amount'] = partialPaid;
      }
      payloads.add(map);
    }

    setState(() => _submitting = true);
    var result = await _api.createLaborsBatch(payloads);
    if (!mounted) return;

    // Retry once after re-login if JWT was rejected.
    if (result['success'] != true && _isAuthFailure(result)) {
      setState(() => _submitting = false);
      final ok = await _promptLoginForSave();
      if (ok == true && mounted) {
        setState(() => _submitting = true);
        result = await _api.createLaborsBatch(payloads);
        if (!mounted) return;
      }
    }

    setState(() => _submitting = false);

    if (result['success'] != true) {
      final msg = result['message']?.toString() ?? tr('Failed to add labourers');
      if (_isAuthFailure(result)) {
        await _showJwtExpiredDialog(msg);
      } else {
        _showSnack(msg, error: true);
      }
      return;
    }

    final data = result['data'];
    final createdCount = data is List ? data.length : _pending.length;

    // Full reset after a successful save so the form is ready for the next
    // entry (pending queue, narration, labour head, date, work type,
    // location, shift, gender, category, rate, days, mobile, name, address).
    setState(() {
      _pending.clear();
      _narrationController.clear();
      _labourHeadController.clear();
      _daysHourController.clear();
      _rateController.clear();
      _paidAmountController.clear();
      _settleAsPaid = false;
      _selectedDate = DateTime.now();
      _selectedWorkType = 'Daily Wages';
      _selectedLocation = 'Farm';
      _selectedShift = 'fullday';
      _selectedGender = 'Male';
      _selectedCategory = _categories.isNotEmpty ? _categories.first : 'Plucking';
      _searchQuery = '';
    });
    _clearLabourerIdentityFields();
    if (mounted) setState(() {});

    await _loadLabors();

    _showSnack(
        createdCount == 1
            ? tr('Laborer added successfully')
            : trf('{0} labourers added successfully', [createdCount]));
  }

  bool _isAuthFailure(Map<String, dynamic> result) {
    final code = result['statusCode'];
    if (code == 401) return true;
    final msg = (result['message']?.toString() ?? '').toLowerCase();
    return msg.contains('jwt') ||
        msg.contains('unauthorized') ||
        msg.contains('login required') ||
        msg.contains('missing or malformed');
  }

  Future<bool?> _promptLoginForSave() async {
    if (!mounted) return false;
    final loggedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    return loggedIn == true;
  }

  Future<void> _showJwtExpiredDialog(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Icon(
              Icons.lock_clock_rounded,
              size: 72,
              color: AppColors.expense.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 16),
            Text(
              tr('Session expired'),
              textAlign: TextAlign.center,
              style: AppText.h3,
            ),
            const SizedBox(height: 8),
            Text(
              message.isNotEmpty
                  ? message
                  : tr('Invalid or expired JWT. Please login again to continue.'),
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _promptLoginForSave();
            },
            child: Text(tr('Login')),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
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
  }

  Future<void> _removeLaborer(int index) async {
    if (index < 0 || index >= _laborers.length) return;
    final laborer = _laborers[index];
    final ok = await _confirmDelete(
      title: tr('Delete labour entry?'),
      message:
          'Delete ${laborer.name.isEmpty ? 'this entry' : laborer.name}? This cannot be undone.',
    );
    if (ok != true || !mounted) return;
    if (laborer.id != null) {
      final deleted = await _api.deleteLabor(laborer.id!);
      if (!deleted) {
        _showSnack('Failed to delete laborer', error: true);
        return;
      }
    }
    setState(() => _laborers.removeAt(index));
    _showSnack('Labour entry deleted');
  }

  Future<void> _openLaborDetail(Laborer laborer) async {
    if (laborer.id == null) {
      _showSnack('Save this entry before viewing details', error: true);
      return;
    }
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LaborDetailSheet(
        laborer: laborer,
        workTypes: _workTypes,
        shifts: _shifts,
        genders: _genders,
        categories: _categories,
        locations: List<String>.from(_locations),
        onUpdate: (payload) => _api.updateLabor(laborer.id!, payload),
        onDelete: () => _api.deleteLabor(laborer.id!),
      ),
    );
    if (!mounted) return;
    if (result == 'updated' || result == 'deleted') {
      await _loadLabors();
      if (result == 'deleted' && mounted) {
        _showSnack('Labour entry deleted');
      }
    }
  }

  double get _totalLaborCost {
    return _filteredLaborers.fold(0, (sum, l) => sum + l.totalCost);
  }

  List<Laborer> get _filteredLaborers {
    if (_searchQuery.isEmpty) return _laborers;
    final q = _searchQuery.toLowerCase();
    return _laborers
        .where((l) =>
            l.name.toLowerCase().contains(q) ||
            l.narration.toLowerCase().contains(q) ||
            l.location.toLowerCase().contains(q) ||
            l.labourHead.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              AppHeader(
                icon: Icons.engineering_rounded,
                title: tr('Labour Management'),
                subtitle: tr('Daily wages & contract labour'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: withFeedbackAction(
                    context,
                    menu: 'labour',
                    actions: [
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded,
                            color: Colors.white),
                        onSelected: (v) {
                          if (v == 'opening') _showOpeningBalanceDialog();
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'opening',
                            child: Text(tr('Opening Balance')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Column(
                          children: [
                            _buildLabourSummaryButton(),
                            SizedBox(height: 12),
                            _buildAddFormCard(),
                            SizedBox(height: 14),
                            _buildSummaryCard(),
                            SizedBox(height: 14),
                            _buildLaborerList(),
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

  Widget _buildLabourSummaryButton() {
    return Row(
      children: [
        Expanded(
          child: SecondaryButton(
            label: tr('Summary'),
            icon: Icons.badge_rounded,
            color: AppColors.info,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LabourSummaryPage()),
            ),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: SecondaryButton(
            label: tr('History'),
            icon: Icons.history_rounded,
            color: AppColors.accent,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LaborHistoryPage()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddFormCard() {
    final isPayment = _entryMode == 'Payment';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: Icons.person_add_alt_1_rounded,
            title: tr('Add Labour Entry'),
            subtitle: isPayment
                ? tr('Record a labour payment')
                : tr('Record daily wages or contract labour'),
          ),
          SizedBox(height: 14),
          AppDropdown(
            label: tr('Mode'),
            value: _entryMode,
            items: const ['Payable', 'Payment'],
            icon: Icons.swap_horiz_rounded,
            onChanged: (v) => setState(() {
              _entryMode = v ?? 'Payable';
              if (_entryMode == 'Payment') {
                _pending.clear();
              }
            }),
          ),
          SizedBox(height: 10),
          _compactDateField(),
          if (isPayment) ...[
            SizedBox(height: 14),
            SectionTitle(
              icon: Icons.payments_rounded,
              title: tr('Payment details'),
              subtitle: tr('Pay against labour balance'),
            ),
            SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppField(
                    controller: _nameController,
                    label: tr('Name'),
                    icon: Icons.person_rounded,
                  ),
                ),
                VoiceMicButton(
                  fieldId: 'labor_name_pay',
                  controller: _nameController,
                ),
              ],
            ),
            if (_nameSuggestions.isNotEmpty) ...[
              SizedBox(height: 6),
              _buildNameSuggestions(),
            ],
            if (_labourBalance != null ||
                _labourNeedsOpening ||
                _nameController.text.trim().length >= 2) ...[
              SizedBox(height: 8),
              _buildBalanceChip(),
            ],
            SizedBox(height: 10),
            AppField(
              controller: _paymentAmountController,
              label: tr('Amount'),
              icon: Icons.currency_rupee_rounded,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppField(
                    controller: _narrationController,
                    label: tr('Narration (optional)'),
                    icon: Icons.description_rounded,
                    maxLines: 2,
                    required: false,
                  ),
                ),
                VoiceMicButton(
                  fieldId: 'labor_narration_pay',
                  controller: _narrationController,
                ),
              ],
            ),
            SizedBox(height: 14),
            PrimaryButton(
              label: _submitting ? tr('Saving…') : tr('Save Payment'),
              icon: Icons.save_rounded,
              onPressed: _submitting ? null : _submitLabours,
              loading: _submitting,
            ),
          ] else ...[
            SizedBox(height: 10),
            AppDropdown(
              label: 'Work Type',
              value: _selectedWorkType,
              items: _workTypes,
              icon: Icons.work_outline_rounded,
              onChanged: (v) => setState(() {
                _selectedWorkType = v ?? 'Daily Wages';
                if (!_isContract) _labourHeadController.clear();
              }),
            ),
            if (_isContract) ...[
              SizedBox(height: 10),
              AppField(
                controller: _labourHeadController,
                label: 'Labour Head',
                icon: Icons.supervisor_account_rounded,
              ),
            ],
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppDropdown(
                    label: 'Location',
                    value: _selectedLocation,
                    items: _locations,
                    icon: Icons.location_on_rounded,
                    onChanged: (v) => setState(() => _selectedLocation = v),
                  ),
                ),
                SizedBox(width: 10),
                _addLocationButton(),
              ],
            ),
            SizedBox(height: 16),
            SectionTitle(
              icon: Icons.badge_outlined,
              title: tr('Labourer details'),
              subtitle: tr('Add one labourer at a time'),
            ),
            SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppField(
                    controller: _nameController,
                    label: 'Name',
                    icon: Icons.person_rounded,
                  ),
                ),
                VoiceMicButton(
                  fieldId: 'labor_name',
                  controller: _nameController,
                ),
                SizedBox(width: 4),
                _squareIconButton(
                  icon: Icons.info_outline_rounded,
                  tooltip: tr('Additional information'),
                  onTap: _showAdditionalInfoDialog,
                  color: AppColors.info,
                  background: AppColors.infoSoft,
                ),
              ],
            ),
            if (_nameSuggestions.isNotEmpty) ...[
              SizedBox(height: 6),
              _buildNameSuggestions(),
            ],
            if (_labourBalance != null ||
                _labourNeedsOpening ||
                _nameController.text.trim().length >= 2) ...[
              SizedBox(height: 8),
              _buildBalanceChip(),
            ],
            SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: AppDropdown(
                    label: 'Category',
                    value: _selectedCategory,
                    items: _categories,
                    icon: Icons.category_rounded,
                    onChanged: (v) {
                      setState(() => _selectedCategory = v!);
                      _applyRateForSelectedCategory();
                    },
                  ),
                ),
                SizedBox(width: 8),
                _squareIconButton(
                  icon: Icons.grid_view_rounded,
                  tooltip: tr('Category rate settings'),
                  onTap: _showLaborRatesPopup,
                ),
                SizedBox(width: 8),
                _squareIconButton(
                  icon: Icons.search_rounded,
                  tooltip: tr('Search category'),
                  onTap: _showCategorySearchDialog,
                  color: AppColors.info,
                  background: AppColors.infoSoft,
                ),
                SizedBox(width: 8),
                _squareIconButton(
                  icon: Icons.add_rounded,
                  tooltip: tr('Add category'),
                  onTap: _addCategory,
                  color: Colors.white,
                  background: AppColors.primary,
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppDropdown(
                    label: 'Shift',
                    value: _selectedShift,
                    items: _shifts,
                    icon: Icons.wb_sunny_rounded,
                    onChanged: (v) =>
                        setState(() => _selectedShift = v ?? 'fullday'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: AppField(
                    controller: _daysHourController,
                    label: 'Days / Hour',
                    icon: Icons.access_time_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppDropdown(
                    label: 'Gender',
                    value: _selectedGender,
                    items: _genders,
                    icon: Icons.wc_rounded,
                    onChanged: (v) =>
                        setState(() => _selectedGender = v ?? 'Male'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: AppField(
                    controller: _rateController,
                    label: 'Rate',
                    icon: Icons.currency_rupee_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            PrimaryButton(
              label: tr('Add Labourer'),
              icon: Icons.add_rounded,
              onPressed: _addPendingLabour,
              height: 50,
            ),
            if (_pending.isNotEmpty) ...[
              SizedBox(height: 16),
              SectionTitle(
                icon: Icons.grid_on_rounded,
                title: 'Added labourers (${_pending.length})',
              ),
              SizedBox(height: 10),
              _buildPendingGrid(),
            ],
            SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppField(
                    controller: _narrationController,
                    label: tr('Narration (optional)'),
                    icon: Icons.description_rounded,
                    maxLines: 2,
                    required: false,
                  ),
                ),
                VoiceMicButton(
                  fieldId: 'labor_narration',
                  controller: _narrationController,
                ),
              ],
            ),
            SizedBox(height: 12),
            AppField(
              controller: _paidAmountController,
              label: tr('Paid amount'),
              icon: Icons.payments_outlined,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              required: false,
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Text(tr('Settlement'), style: AppText.bodyStrong),
                const Spacer(),
                ChoiceChip(
                  label: Text(tr('Payable')),
                  selected: !_settleAsPaid,
                  onSelected: (_) => setState(() => _settleAsPaid = false),
                  selectedColor: AppColors.primarySoft,
                  labelStyle: TextStyle(
                    color: !_settleAsPaid
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 8),
                ChoiceChip(
                  label: Text(tr('Paid')),
                  selected: _settleAsPaid,
                  onSelected: (_) => setState(() => _settleAsPaid = true),
                  selectedColor: AppColors.incomeSoft,
                  labelStyle: TextStyle(
                    color: _settleAsPaid
                        ? AppColors.income
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            PrimaryButton(
              label: _submitting ? 'Saving…' : 'Save Entry',
              icon: Icons.save_rounded,
              onPressed: _submitting ? null : _submitLabours,
              loading: _submitting,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBalanceChip() {
    final payable = _labourPayable ?? 0;
    final receivable = _labourReceivable ?? 0;
    final bal = _labourBalance ?? 0;
    final label = receivable > 0
        ? '${tr('Receivable')}: ₹${receivable.toStringAsFixed(0)}'
        : '${tr('Payable')}: ₹${payable > 0 ? payable.toStringAsFixed(0) : bal.toStringAsFixed(0)}';
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (_labourBalance != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.incomeSoft,
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: AppColors.income.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      size: 16, color: AppColors.income),
                  SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.income,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          if (_labourNeedsOpening)
            TextButton.icon(
              onPressed: () => _ensureLabourOpeningBalance(forcePrompt: true),
              icon: const Icon(Icons.add_card_rounded, size: 18),
              label: Text(tr('Enter opening')),
              style: TextButton.styleFrom(foregroundColor: AppColors.warning),
            )
          else
            TextButton.icon(
              onPressed: () => _showOpeningBalanceDialog(),
              icon: const Icon(Icons.account_balance_rounded, size: 18),
              label: Text(tr('Opening')),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
        ],
      ),
    );
  }

  Widget _addLocationButton() {
    return SizedBox(
      width: 56,
      height: 56,
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _addLocation,
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
    );
  }

  /// Compact square icon button used for the row of actions beside the
  /// Name and Category fields (additional info / rate settings / search /
  /// add category).
  Widget _squareIconButton({
    required IconData icon,
    required VoidCallback? onTap,
    String? tooltip,
    Color color = AppColors.primary,
    Color background = const Color(0xFFE8F5E9),
  }) {
    final button = SizedBox(
      height: _fieldHeight,
      width: _fieldHeight,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  /// Dropdown-style list of matching labourer names shown below the Name
  /// field while typing (name autocomplete).
  Widget _buildNameSuggestions() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 190),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _nameSuggestions.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
        itemBuilder: (_, i) {
          final n = _nameSuggestions[i];
          return InkWell(
            onTap: () => _selectNameSuggestion(n),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(width: 8),
                  Expanded(child: Text(n, style: AppText.bodyStrong)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPendingGrid() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 64,
          ),
          child: DataTable(
            columnSpacing: 14,
            horizontalMargin: 12,
            headingRowHeight: 36,
            dataRowMinHeight: 38,
            dataRowMaxHeight: 44,
            headingTextStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
            dataTextStyle: const TextStyle(
              fontSize: 11,
              color: AppColors.textPrimary,
            ),
            columns: [
              DataColumn(label: Text(tr('Name'))),
              DataColumn(label: Text(tr('Shift'))),
              DataColumn(label: Text(tr('D/H')), numeric: true),
              DataColumn(label: Text(tr('Gender'))),
              DataColumn(label: Text(tr('Rate')), numeric: true),
              DataColumn(label: Text(tr('Category'))),
              DataColumn(label: Text('')),
            ],
            rows: List.generate(_pending.length, (index) {
              final row = _pending[index];
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      row.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  DataCell(Text(row.shift)),
                  DataCell(Text(row.daysHour.toString())),
                  DataCell(Text(row.gender)),
                  DataCell(Text(row.rate.toStringAsFixed(0))),
                  DataCell(Text(row.category, overflow: TextOverflow.ellipsis)),
                  DataCell(
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.expense,
                      ),
                      onPressed: () => _removePending(index),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _compactDateField() {
    return InkWell(
      onTap: () => _selectDate(context),
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: tr('Date'),
          prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
          prefixIconConstraints: BoxConstraints(minWidth: 44, minHeight: 0),
        ),
        child: Row(
          children: [
            Text(
              DateFormat('dd/MM/yyyy').format(_selectedDate),
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.expand_more_rounded,
              color: AppColors.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final entries = _filteredLaborers.length;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: _summaryItem(
              Icons.group_rounded,
              '$entries',
              'Entries',
              AppColors.info,
            ),
          ),
          SizedBox(
            height: 40,
            child: VerticalDivider(color: AppColors.border, width: 1),
          ),
          Expanded(
            child: _summaryItem(
              Icons.currency_rupee_rounded,
              '₹${_totalLaborCost.toStringAsFixed(0)}',
              'Total Cost',
              AppColors.income,
            ),
          ),
          SizedBox(
            height: 40,
            child: VerticalDivider(color: AppColors.border, width: 1),
          ),
          Expanded(
            child: _summaryItem(
              Icons.hourglass_bottom_rounded,
              '${_pending.length}',
              'In Queue',
              AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        TintedIcon(icon: icon, color: color, boxSize: 38, size: 18, radius: 11),
        SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        Text(label, style: AppText.caption),
      ],
    );
  }

  Widget _buildLaborerList() {
    if (_laborers.isEmpty) {
      return AppCard(
        child: EmptyState(
          icon: Icons.people_alt_outlined,
          title: tr('No labourers saved yet'),
          subtitle: tr('Add your first labour entry above'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_laborers.length > 1) ...[
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: tr('Search labourers'),
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              prefixIconConstraints: BoxConstraints(minWidth: 44, minHeight: 0),
            ),
          ),
          SizedBox(height: 10),
        ],
        ..._filteredLaborers.asMap().entries.map((entry) {
          final index = _laborers.indexOf(entry.value);
          return _laborerCard(entry.value, index);
        }),
      ],
    );
  }

  Widget _laborerCard(Laborer laborer, int index) {
    final cost = laborer.totalCost;
    return AppCard(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      radius: 16,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openLaborDetail(laborer),
        child: Row(
          children: [
            TintedIcon(
              icon: Icons.person_rounded,
              color: AppColors.primary,
              boxSize: 42,
              size: 20,
              radius: 12,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(laborer.name, style: AppText.bodyStrong),
                  SizedBox(height: 5),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      if (laborer.workType.isNotEmpty)
                        _chip(laborer.workType, AppColors.info),
                      _chip(laborer.shift, AppColors.warning),
                      _chip(laborer.gender, AppColors.primary),
                      if (laborer.category.isNotEmpty)
                        _chip(laborer.category, AppColors.expense),
                      if (laborer.location.isNotEmpty)
                        _chip(laborer.location, AppColors.textMuted),
                    ],
                  ),
                  SizedBox(height: 5),
                  Text(
                    '₹${laborer.wage.toStringAsFixed(0)} × ${laborer.hours} = ₹${cost.toStringAsFixed(0)}',
                    style: AppText.small,
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy').format(laborer.date),
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.badge_outlined,
                color: AppColors.info,
                size: 22,
              ),
              tooltip: tr('Labourer schedule'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LabourerDetailPage(
                      name: laborer.name,
                      mobile: laborer.mobile,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(
                Icons.visibility_outlined,
                color: AppColors.primary,
                size: 22,
              ),
              tooltip: tr('View / Edit'),
              onPressed: () => _openLaborDetail(laborer),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.expense,
                size: 22,
              ),
              tooltip: tr('Delete'),
              onPressed: () => _removeLaborer(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

}

/// Dedicated dialog so Cancel/Add keep reliable hit targets above the keyboard
/// and the text controller is disposed with the dialog route (not after pop).
class _AddLocationDialog extends StatefulWidget {
  const _AddLocationDialog();

  @override
  State<_AddLocationDialog> createState() => _AddLocationDialogState();
}

class _AddLocationDialogState extends State<_AddLocationDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _cancel() {
    _focusNode.unfocus();
    Navigator.of(context).pop();
  }

  void _submit() {
    final name = _controller.text.trim();
    _focusNode.unfocus();
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(tr('Add Location'), style: AppText.h3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: tr('Location name'),
                  prefixIcon: Icon(Icons.location_on_rounded),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _cancel,
                    child: Text(tr('Cancel')),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(72, 44),
                    ),
                    onPressed: _submit,
                    child: Text(tr('Add')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog to add a new labour category (persisted via SharedPreferences).
class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog();

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _cancel() {
    _focusNode.unfocus();
    Navigator.of(context).pop();
  }

  void _submit() {
    final name = _controller.text.trim();
    _focusNode.unfocus();
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(tr('Add Category'), style: AppText.h3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: tr('Category name'),
                  prefixIcon: const Icon(Icons.category_rounded),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _cancel,
                    child: Text(tr('Cancel')),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(72, 44),
                    ),
                    onPressed: _submit,
                    child: Text(tr('Add')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog to search categories (alphabetical) and select one.
class _CategorySearchDialog extends StatefulWidget {
  final List<String> categories;

  const _CategorySearchDialog({required this.categories});

  @override
  State<_CategorySearchDialog> createState() => _CategorySearchDialogState();
}

class _CategorySearchDialogState extends State<_CategorySearchDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = List<String>.from(widget.categories);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    final q = v.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List<String>.from(widget.categories)
          : widget.categories
              .where((c) => c.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Expanded(
            child: Text(
              tr('Search category'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDeep,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: tr('Search category'),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.field,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: _filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        tr('No categories found'),
                        style: AppText.caption,
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: AppColors.border),
                      itemBuilder: (_, i) {
                        final cat = _filtered[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            cat,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDeep,
                            ),
                          ),
                          onTap: () => Navigator.pop(context, cat),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LaborDetailSheet extends StatefulWidget {
  final Laborer laborer;
  final List<String> workTypes;
  final List<String> shifts;
  final List<String> genders;
  final List<String> categories;
  final List<String> locations;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> payload)
      onUpdate;
  final Future<bool> Function() onDelete;

  _LaborDetailSheet({
    required this.laborer,
    required this.workTypes,
    required this.shifts,
    required this.genders,
    required this.categories,
    required this.locations,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_LaborDetailSheet> createState() => _LaborDetailSheetState();
}

class _LaborDetailSheetState extends State<_LaborDetailSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _rateCtrl;
  late final TextEditingController _labourHeadCtrl;
  late final TextEditingController _narrationCtrl;
  late DateTime _date;
  late String _workType;
  late String _shift;
  late String _gender;
  late String _category;
  late String _location;
  bool _editing = false;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    final l = widget.laborer;
    _nameCtrl = TextEditingController(text: l.name);
    _mobileCtrl = TextEditingController(text: l.mobile ?? '');
    _hoursCtrl = TextEditingController(text: l.hours.toString());
    _rateCtrl = TextEditingController(text: l.wage.toStringAsFixed(0));
    _labourHeadCtrl = TextEditingController(text: l.labourHead);
    _narrationCtrl = TextEditingController(text: l.narration);
    _date = l.date;
    _workType = l.workType.isNotEmpty ? l.workType : 'Daily Wages';
    _shift = l.shift.isNotEmpty ? l.shift : 'fullday';
    _gender = l.gender.isNotEmpty ? l.gender : 'Male';
    _category = l.category;
    _location = l.location.isNotEmpty ? l.location : widget.locations.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _hoursCtrl.dispose();
    _rateCtrl.dispose();
    _labourHeadCtrl.dispose();
    _narrationCtrl.dispose();
    super.dispose();
  }

  bool get _isContract => _workType == 'Contract';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final hours = double.tryParse(_hoursCtrl.text.trim());
    final rate = double.tryParse(_rateCtrl.text.trim());
    final narration = _narrationCtrl.text.trim();
    if (name.isEmpty) {
      _toast('Name is required', error: true);
      return;
    }
    if (hours == null || hours <= 0) {
      _toast('Enter valid days/hour', error: true);
      return;
    }
    if (rate == null || rate <= 0) {
      _toast('Enter valid rate', error: true);
      return;
    }
    if (_isContract && _labourHeadCtrl.text.trim().isEmpty) {
      _toast('Labour head is required for Contract', error: true);
      return;
    }

    final payload = <String, dynamic>{
      'name': name,
      'wage': rate,
      'hours': hours,
      'number_of_labours': widget.laborer.numberOfLabours < 1
          ? 1
          : widget.laborer.numberOfLabours,
      'shift': _shift,
      'category': _category,
      'gender': _gender,
      'work_type': _workType,
      'labour_head': _isContract ? _labourHeadCtrl.text.trim() : '',
      'location': _location,
      'narration': narration,
      'date': DateFormat('yyyy-MM-dd').format(_date),
    };
    final mobile = _mobileCtrl.text.trim();
    if (mobile.isNotEmpty) payload['mobile'] = mobile;

    setState(() => _saving = true);
    final result = await widget.onUpdate(payload);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result['success'] == true) {
      Navigator.pop(context, 'updated');
    } else {
      _toast(result['message']?.toString() ?? 'Update failed', error: true);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Delete labour entry?')),
        content: Text(
          'Delete ${widget.laborer.name.isEmpty ? 'this entry' : widget.laborer.name}? This cannot be undone.',
        ),
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
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    final deleted = await widget.onDelete();
    if (!mounted) return;
    setState(() => _deleting = false);
    if (deleted) {
      Navigator.pop(context, 'deleted');
    } else {
      _toast('Failed to delete', error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.expense : AppColors.primary,
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: AppText.small)),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: AppText.bodyStrong,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _editing ? 'Edit labour entry' : 'Labour entry details',
                    style: AppText.title,
                  ),
                ),
                if (!_editing)
                  IconButton(
                    tooltip: tr('Edit'),
                    onPressed: () => setState(() => _editing = true),
                    icon: const Icon(Icons.edit_rounded,
                        color: AppColors.primary),
                  ),
                IconButton(
                  tooltip: tr('Delete'),
                  onPressed: _deleting ? null : _delete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.expense
                        .withValues(alpha: _deleting ? 0.4 : 1),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: _editing ? _buildEdit() : _buildView(),
              ),
            ),
            if (_editing) ...[
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() => _editing = false),
                      child: Text(tr('Cancel')),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(tr('Save')),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildView() {
    final l = widget.laborer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row('Name', l.name),
        if (l.mobile != null && l.mobile!.isNotEmpty) _row('Mobile', l.mobile!),
        _row('Work type', l.workType),
        _row('Shift', l.shift),
        _row('Gender', l.gender),
        _row('Category', l.category),
        _row('Location', l.location),
        _row('Days / Hour', l.hours.toString()),
        _row('Rate', '₹${l.wage.toStringAsFixed(0)}'),
        _row('Total', '₹${l.totalCost.toStringAsFixed(0)}'),
        _row('Date', DateFormat('dd/MM/yyyy').format(l.date)),
        if (l.labourHead.isNotEmpty) _row('Labour head', l.labourHead),
        _row('Narration', l.narration),
        SizedBox(height: 8),
        Text(
          'Tap the edit icon to change this entry.',
          style: AppText.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEdit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(labelText: tr('Name'), filled: true),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _mobileCtrl,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: InputDecoration(labelText: tr('Mobile'), filled: true),
        ),
        SizedBox(height: 10),
        AppDropdown(
          label: 'Work Type',
          value: _workType,
          items: widget.workTypes,
          icon: Icons.work_outline_rounded,
          onChanged: (v) => setState(() => _workType = v ?? 'Daily Wages'),
        ),
        if (_isContract) ...[
          SizedBox(height: 10),
          TextField(
            controller: _labourHeadCtrl,
            decoration:
                InputDecoration(labelText: tr('Labour Head'), filled: true),
          ),
        ],
        SizedBox(height: 10),
        AppDropdown(
          label: 'Location',
          value: widget.locations.contains(_location) ? _location : null,
          items: widget.locations,
          icon: Icons.location_on_rounded,
          onChanged: (v) => setState(() => _location = v ?? _location),
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AppDropdown(
                label: 'Shift',
                value: _shift,
                items: widget.shifts,
                icon: Icons.wb_sunny_rounded,
                onChanged: (v) => setState(() => _shift = v ?? 'fullday'),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: AppDropdown(
                label: 'Gender',
                value: _gender,
                items: widget.genders,
                icon: Icons.wc_rounded,
                onChanged: (v) => setState(() => _gender = v ?? 'Male'),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        AppDropdown(
          label: 'Category',
          value: widget.categories.contains(_category) ? _category : null,
          items: widget.categories,
          icon: Icons.category_rounded,
          onChanged: (v) {
            if (v != null) setState(() => _category = v);
          },
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _hoursCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: tr('Days / Hour'), filled: true),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _rateCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    InputDecoration(labelText: tr('Rate'), filled: true),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        InkWell(
          onTap: _pickDate,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: tr('Date'),
              filled: true,
              prefixIcon: Icon(Icons.event_rounded),
            ),
            child: Text(DateFormat('dd/MM/yyyy').format(_date)),
          ),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _narrationCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: tr('Narration (optional)'),
            filled: true,
          ),
        ),
      ],
    );
  }
}

class Laborer {
  final int? id;
  final String name;
  final String? mobile;
  final double wage;
  final double hours;
  final int numberOfLabours;
  final DateTime date;
  final String shift;
  final String category;
  final String gender;
  final String workType;
  final String labourHead;
  final String location;
  final String narration;

  Laborer({
    this.id,
    required this.name,
    this.mobile,
    required this.wage,
    required this.hours,
    required this.numberOfLabours,
    required this.date,
    required this.shift,
    required this.category,
    this.gender = '',
    this.workType = '',
    this.labourHead = '',
    this.location = '',
    required this.narration,
  });

  double get totalCost => wage * hours;

  factory Laborer.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) {
      if (v is String && v.isNotEmpty) {
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 1;
      return 1;
    }

    final mobileRaw = json['mobile']?.toString().trim();
    return Laborer(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}'),
      name: json['name']?.toString() ?? '',
      mobile: (mobileRaw == null || mobileRaw.isEmpty) ? null : mobileRaw,
      wage: toDouble(json['wage']),
      hours: toDouble(json['hours']),
      numberOfLabours: toInt(json['number_of_labours']),
      date: parseDate(json['date']),
      shift: json['shift']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      workType: json['work_type']?.toString() ?? '',
      labourHead: json['labour_head']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      narration: json['narration']?.toString() ?? '',
    );
  }
}
