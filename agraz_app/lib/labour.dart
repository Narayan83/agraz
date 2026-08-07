import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'app_theme.dart';

class _PendingLabour {
  final String name;
  final String shift;
  final double daysHour;
  final String gender;
  final double rate;
  final String category;

  const _PendingLabour({
    required this.name,
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
  final List<String> _categories = [
    'Plucking',
    'Cutting',
    'Drying',
    'Grading',
    'Packing',
    'Transport',
  ];
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
    _loadLabors();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _daysHourController.dispose();
    _rateController.dispose();
    _labourHeadController.dispose();
    _narrationController.dispose();
    super.dispose();
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
    final daysHourText = _daysHourController.text.trim();
    final rateText = _rateController.text.trim();

    if (name.isEmpty) {
      _showSnack('Enter labourer name', error: true);
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
        shift: _selectedShift,
        daysHour: daysHour,
        gender: _selectedGender,
        rate: rate,
        category: _selectedCategory,
      ));
      // Only clear name — keep shift, days/hour, gender, rate, category
      _nameController.clear();
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
                  onChanged: (v) =>
                      setState(() => _selectedCategory = v ?? 'Plucking'),
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
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
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
