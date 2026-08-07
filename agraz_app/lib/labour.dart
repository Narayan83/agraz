import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'labor_categories.dart';

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
  final TextEditingController _daysHourController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _labourHeadController = TextEditingController();
  final TextEditingController _narrationController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedWorkType = 'Daily Wages';
  String? _selectedLocation;
  String _selectedShift = 'fullday';
  String _selectedGender = 'Male';
  String _selectedCategory = 'Plucking';

  final List<String> _workTypes = ['Daily Wages', 'Contract'];
  final List<String> _shifts = ['fullday', 'morning', 'evening', 'hour'];
  final List<String> _genders = ['Male', 'Female'];
  final List<String> _categories = List<String>.from(kLaborWorkCategories);
  final List<String> _locations = [
    'Farm',
    'Warehouse',
    'Processing Unit',
    'Field',
  ];

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  String _searchQuery = '';
  bool _loading = true;
  bool _submitting = false;
  final ApiService _api = ApiService();
  /// Cached rates keyed by category for the current labourer name.
  Map<String, double> _ratesForLabourer = {};
  Timer? _rateLookupDebounce;

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
  }

  @override
  void dispose() {
    _rateLookupDebounce?.cancel();
    _nameController.removeListener(_onLabourerIdentityChanged);
    _mobileController.removeListener(_onLabourerIdentityChanged);
    _animController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _daysHourController.dispose();
    _rateController.dispose();
    _labourHeadController.dispose();
    _narrationController.dispose();
    super.dispose();
  }

  void _onLabourerIdentityChanged() {
    setState(() {}); // refresh rates icon visibility
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
      return;
    }
    _rateLookupDebounce = Timer(const Duration(milliseconds: 400), () {
      _loadRatesForLabourer(name: name);
    });
  }

  Future<void> _loadRatesForLabourer({String? mobile, String? name}) async {
    final rows = await _api.fetchLaborRates(
      mobile: mobile,
      name: name,
    );
    if (!mounted) return;
    final map = <String, double>{};
    for (final r in rows) {
      final cat = r['category']?.toString() ?? '';
      final rate = r['rate'];
      final value = rate is num
          ? rate.toDouble()
          : double.tryParse(rate?.toString() ?? '');
      if (cat.isNotEmpty && value != null && value > 0) {
        map[cat] = value;
      }
    }
    setState(() => _ratesForLabourer = map);
    _applyRateForSelectedCategory();
  }

  void _applyRateForSelectedCategory() {
    final rate = _ratesForLabourer[_selectedCategory];
    if (rate == null || rate <= 0) return;
    _rateController.text = rate.toStringAsFixed(0);
  }

  Future<void> _loadLabors() async {
    setState(() => _loading = true);
    final rows = await _api.fetchLabors();
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
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
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
    if (mobile.length != 10) {
      _showSnack('Enter 10-digit mobile first', error: true);
      return;
    }

    final existing = await _api.fetchLaborRates(mobile: mobile);
    if (!mounted) return;

    final controllers = <String, TextEditingController>{};
    for (final cat in kLaborWorkCategories) {
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
              const Expanded(
                child: Text(
                  'Labour Rates',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _darkGreen,
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
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.55,
                  ),
                  itemCount: kLaborWorkCategories.length,
                  itemBuilder: (_, i) {
                    final cat = kLaborWorkCategories[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: _fieldBg,
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
                                      color: _darkGreen,
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
                              hintText: 'Rate',
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
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final rates = <String, double>{};
                for (final cat in kLaborWorkCategories) {
                  final v = double.tryParse(controllers[cat]!.text.trim());
                  if (v != null && v >= 0) rates[cat] = v;
                }
                if (rates.isEmpty) {
                  Navigator.pop(ctx);
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                final ok = await _api.saveLaborRates(
                  mobile: mobile,
                  name: _nameController.text.trim(),
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
                    backgroundColor: ok ? _primaryGreen : Colors.red,
                  ),
                );
              },
              child: const Text('Save Rates'),
            ),
          ],
        );
      },
    );

    for (final c in controllers.values) {
      c.dispose();
    }
  }

  Future<void> _addLocation() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Location'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Location name',
              prefixIcon: Icon(Icons.location_on_rounded),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null || result.isEmpty) return;
    setState(() {
      if (!_locations.contains(result)) {
        _locations.add(result);
      }
      _selectedLocation = result;
    });
  }

  void _addPendingLabour() {
    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final daysHourText = _daysHourController.text.trim();
    final rateText = _rateController.text.trim();

    if (name.isEmpty) {
      _showSnack('Enter labourer name', error: true);
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
      // Only clear name/mobile — keep shift, days/hour, gender, rate, category
      _nameController.clear();
      _mobileController.clear();
      _ratesForLabourer = {};
    });
  }

  void _removePending(int index) {
    setState(() => _pending.removeAt(index));
  }

  Future<void> _submitLabours() async {
    final narration = _narrationController.text.trim();
    final labourHead = _labourHeadController.text.trim();

    if (_selectedLocation == null || _selectedLocation!.isEmpty) {
      _showSnack('Please select a location', error: true);
      return;
    }
    if (_isContract && labourHead.isEmpty) {
      _showSnack('Labour head is required for Contract', error: true);
      return;
    }
    if (_pending.isEmpty) {
      _showSnack('Add at least one labourer', error: true);
      return;
    }
    if (narration.isEmpty) {
      _showSnack('Please enter narration', error: true);
      return;
    }

    final payloads = _pending
        .map((row) => {
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
              'date': _selectedDate.toIso8601String(),
              if (row.mobile != null && row.mobile!.isNotEmpty)
                'mobile': row.mobile,
            })
        .toList();

    setState(() => _submitting = true);
    final result = await _api.createLaborsBatch(payloads);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result['success'] != true) {
      _showSnack(
          result['message']?.toString() ?? 'Failed to add labourers',
          error: true);
      return;
    }

    final data = result['data'];
    final created = <Laborer>[];
    if (data is List) {
      for (final item in data) {
        if (item is Map) {
          created.add(Laborer.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    setState(() {
      _laborers.insertAll(0, created);
      _pending.clear();
      _nameController.clear();
      _mobileController.clear();
      _ratesForLabourer = {};
      _narrationController.clear();
      _labourHeadController.clear();
      _selectedDate = DateTime.now();
      _selectedWorkType = 'Daily Wages';
      _searchQuery = '';
    });

    _showSnack(
        created.length == 1
            ? 'Laborer added successfully'
            : '${created.length} labourers added successfully');
  }

  Future<void> _removeLaborer(int index) async {
    final laborer = _laborers[index];
    if (laborer.id != null) {
      final ok = await _api.deleteLabor(laborer.id!);
      if (!ok) {
        _showSnack('Failed to delete laborer', error: true);
        return;
      }
    }
    setState(() => _laborers.removeAt(index));
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
              const AppHeader(
                icon: Icons.engineering_rounded,
                title: 'Labour Management',
                subtitle: 'Daily wages & contract labour',
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Column(
                          children: [
                            _buildAddFormCard(),
                            const SizedBox(height: 14),
                            _buildSummaryCard(),
                            const SizedBox(height: 14),
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

  Widget _buildAddFormCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            icon: Icons.person_add_alt_1_rounded,
            title: 'Add Labour Entry',
            subtitle: 'Record daily wages or contract labour',
          ),
          const SizedBox(height: 14),
          _compactDateField(),
          const SizedBox(height: 10),
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
            const SizedBox(height: 10),
            AppField(
              controller: _labourHeadController,
              label: 'Labour Head',
              icon: Icons.supervisor_account_rounded,
            ),
          ],
          const SizedBox(height: 10),
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
              const SizedBox(width: 10),
              _addLocationButton(),
            ],
          ),
          const SizedBox(height: 16),
          const SectionTitle(
            icon: Icons.badge_outlined,
            title: 'Labourer details',
            subtitle: 'Add one labourer at a time',
          ),
          const SizedBox(height: 14),
          AppField(
            controller: _nameController,
            label: 'Name',
            icon: Icons.person_rounded,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _mobileController,
                  label: 'Mobile',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
              ),
              if (_mobileController.text.trim().length == 10) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: _fieldHeight,
                  width: _fieldHeight,
                  child: Material(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: _showLaborRatesPopup,
                      borderRadius: BorderRadius.circular(10),
                      child: const Icon(
                        Icons.grid_view_rounded,
                        color: _primaryGreen,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppDropdown(
                  label: 'Shift',
                  value: _selectedShift,
                  items: _shifts,
                  icon: Icons.wb_sunny_rounded,
                  onChanged: (v) => setState(() => _selectedShift = v ?? 'fullday'),
                ),
              ),
              const SizedBox(width: 10),
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
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppDropdown(
                  label: 'Gender',
                  value: _selectedGender,
                  items: _genders,
                  icon: Icons.wc_rounded,
                  onChanged: (v) => setState(() => _selectedGender = v ?? 'Male'),
                ),
              ),
              const SizedBox(width: 10),
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
          const SizedBox(height: 10),
          Row(
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
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: PrimaryButton(
                  label: 'Add',
                  icon: Icons.add_rounded,
                  onPressed: _addPendingLabour,
                  height: 58,
                ),
              ),
            ],
          ),
          if (_pending.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionTitle(
              icon: Icons.grid_on_rounded,
              title: 'Added labourers (${_pending.length})',
            ),
            const SizedBox(height: 10),
            _buildPendingGrid(),
          ],
          const SizedBox(height: 14),
          AppField(
            controller: _narrationController,
            label: 'Narration',
            icon: Icons.description_rounded,
            maxLines: 2,
            required: true,
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: _submitting ? 'Saving…' : 'Save Entry',
            icon: Icons.save_rounded,
            onPressed: _submitting ? null : _submitLabours,
            loading: _submitting,
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
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Shift')),
              DataColumn(label: Text('D/H'), numeric: true),
              DataColumn(label: Text('Gender')),
              DataColumn(label: Text('Rate'), numeric: true),
              DataColumn(label: Text('Category')),
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
        decoration: const InputDecoration(
          labelText: 'Date',
          prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
          prefixIconConstraints: BoxConstraints(minWidth: 44, minHeight: 0),
        ),
        child: Row(
          children: [
            Text(
              DateFormat('dd MMM yyyy').format(_selectedDate),
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
          const SizedBox(
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
          const SizedBox(
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
        const SizedBox(height: 6),
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
      return const AppCard(
        child: EmptyState(
          icon: Icons.people_alt_outlined,
          title: 'No labourers saved yet',
          subtitle: 'Add your first labour entry above',
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
            decoration: const InputDecoration(
              labelText: 'Search labourers',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              prefixIconConstraints: BoxConstraints(minWidth: 44, minHeight: 0),
            ),
          ),
          const SizedBox(height: 10),
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
      child: Row(
        children: [
          TintedIcon(
            icon: Icons.person_rounded,
            color: AppColors.primary,
            boxSize: 42,
            size: 20,
            radius: 12,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(laborer.name, style: AppText.bodyStrong),
                const SizedBox(height: 5),
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
                const SizedBox(height: 5),
                Text(
                  '₹${laborer.wage.toStringAsFixed(0)} × ${laborer.hours} = ₹${cost.toStringAsFixed(0)}',
                  style: AppText.small,
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(laborer.date),
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.expense,
              size: 22,
            ),
            tooltip: 'Delete',
            onPressed: () => _removeLaborer(index),
          ),
        ],
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
        style: const TextStyle(
            fontSize: 10, color: _primaryGreen, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final isMulti = maxLines > 1;
    return Container(
      height: isMulti ? null : _fieldHeight,
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextField(
        controller: controller,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500, color: _darkGreen),
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          prefixIcon: Icon(icon, color: _primaryGreen, size: 16),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 28, minHeight: 0),
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          contentPadding: EdgeInsets.symmetric(
            vertical: isMulti ? 10 : 8,
          ),
          alignLabelWithHint: isMulti,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return Container(
      height: _fieldHeight,
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        onChanged: onChanged,
        isDense: true,
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          prefixIcon: Icon(icon, color: _primaryGreen, size: 16),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 28, minHeight: 0),
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          contentPadding: const EdgeInsets.only(bottom: 4, top: 0),
        ),
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500, color: _darkGreen),
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: _primaryGreen, size: 18),
        items: items
            .map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(item, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildNullableDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return Container(
      height: _fieldHeight,
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class Laborer {
  final int? id;
  final String name;
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

    return Laborer(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}'),
      name: json['name']?.toString() ?? '',
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
