import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';

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

  static const Color _primaryGreen = Color(0xFF2E7D32);
  static const Color _darkGreen = Color(0xFF1B5E20);
  static const Color _fieldBg = Color(0xFFF5F7F5);
  static const Color _cardBg = Colors.white;
  static const double _fieldHeight = 40;

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
              primary: _primaryGreen,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _primaryGreen),
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
        backgroundColor: error ? Colors.red.shade600 : _primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              hintText: 'Enter location name',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            textCapitalization: TextCapitalization.words,
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
      backgroundColor: const Color(0xFFF5F7F5),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: _primaryGreen),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF388E3C), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.engineering_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Labour Management',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Daily wages & contract labour',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _primaryGreen),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _darkGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddFormCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Add Labour Entry', Icons.person_add_alt_1_rounded),
          _compactDateField(),
          const SizedBox(height: 8),
          _buildDropdown(
            label: 'Work Type',
            value: _selectedWorkType,
            items: _workTypes,
            icon: Icons.work_outline_rounded,
            onChanged: (v) => setState(() {
              _selectedWorkType = v!;
              if (!_isContract) _labourHeadController.clear();
            }),
          ),
          if (_isContract) ...[
            const SizedBox(height: 8),
            _buildTextField(
              controller: _labourHeadController,
              label: 'Labour Head',
              icon: Icons.supervisor_account_rounded,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildNullableDropdown(
                  label: 'Location',
                  value: _selectedLocation,
                  items: _locations,
                  icon: Icons.location_on_rounded,
                  onChanged: (v) => setState(() => _selectedLocation = v),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: _fieldHeight,
                width: _fieldHeight,
                child: ElevatedButton(
                  onPressed: _addLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Icon(Icons.add_rounded, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _sectionTitle('Labourer details', Icons.badge_outlined),
          _buildTextField(
            controller: _nameController,
            label: 'Name',
            icon: Icons.person_rounded,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'Shift',
                  value: _selectedShift,
                  items: _shifts,
                  icon: Icons.wb_sunny_rounded,
                  onChanged: (v) => setState(() => _selectedShift = v!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  controller: _daysHourController,
                  label: 'Days / Hour',
                  icon: Icons.access_time_rounded,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'Gender',
                  value: _selectedGender,
                  items: _genders,
                  icon: Icons.wc_rounded,
                  onChanged: (v) => setState(() => _selectedGender = v!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  controller: _rateController,
                  label: 'Rate',
                  icon: Icons.currency_rupee_rounded,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildDropdown(
                  label: 'Category',
                  value: _selectedCategory,
                  items: _categories,
                  icon: Icons.category_rounded,
                  onChanged: (v) => setState(() => _selectedCategory = v!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: _fieldHeight,
                  child: ElevatedButton(
                    onPressed: _addPendingLabour,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Add',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
          if (_pending.isNotEmpty) ...[
            const SizedBox(height: 14),
            _sectionTitle('Added labourers', Icons.grid_on_rounded),
            _buildPendingGrid(),
          ],
          const SizedBox(height: 12),
          _buildTextField(
            controller: _narrationController,
            label: 'Narration *',
            icon: Icons.description_rounded,
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submitLabours,
              style: ElevatedButton.styleFrom(
                backgroundColor: _darkGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _primaryGreen.withValues(alpha: 0.6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save Entry',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingGrid() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 64,
          ),
          child: DataTable(
            columnSpacing: 12,
            horizontalMargin: 10,
            headingRowHeight: 34,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 42,
            headingTextStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _darkGreen,
            ),
            dataTextStyle: const TextStyle(
              fontSize: 11,
              color: _darkGreen,
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
                  DataCell(Text(row.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600))),
                  DataCell(Text(row.shift)),
                  DataCell(Text(row.daysHour.toString())),
                  DataCell(Text(row.gender)),
                  DataCell(Text(row.rate.toStringAsFixed(0))),
                  DataCell(Text(row.category,
                      overflow: TextOverflow.ellipsis)),
                  DataCell(
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: Icon(Icons.close_rounded,
                          size: 16, color: Colors.red.shade400),
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
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: _fieldHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _fieldBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                color: _primaryGreen, size: 16),
            const SizedBox(width: 8),
            Text(
              DateFormat('dd MMM yyyy').format(_selectedDate),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _darkGreen,
              ),
            ),
            const Spacer(),
            Text(
              'Date',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final entries = _filteredLaborers.length;
    return _card(
      child: Row(
        children: [
          Expanded(
            child: _summaryItem(
              Icons.group_rounded,
              '$entries',
              'Entries',
              const Color(0xFF42A5F5),
            ),
          ),
          Container(width: 1, height: 36, color: Colors.grey.shade200),
          Expanded(
            child: _summaryItem(
              Icons.currency_rupee_rounded,
              '₹${_totalLaborCost.toStringAsFixed(0)}',
              'Total Cost',
              const Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _darkGreen,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildLaborerList() {
    if (_laborers.isEmpty) {
      return _card(
        child: Column(
          children: [
            Icon(Icons.people_alt_outlined,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(
              'No labourers saved yet',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_laborers.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              height: _fieldHeight,
              decoration: BoxDecoration(
                color: _fieldBg,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(fontSize: 13, color: _darkGreen),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  prefixIcon: Icon(Icons.search_rounded,
                      color: _primaryGreen, size: 18),
                  prefixIconConstraints:
                      BoxConstraints(minWidth: 30, minHeight: 0),
                  hintText: 'Search labourers',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        ..._filteredLaborers.asMap().entries.map((entry) {
          final index = _laborers.indexOf(entry.value);
          return _laborerCard(entry.value, index);
        }),
      ],
    );
  }

  Widget _laborerCard(Laborer laborer, int index) {
    final cost = laborer.totalCost;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person_rounded,
                color: _primaryGreen, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  laborer.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _darkGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (laborer.workType.isNotEmpty) _chip(laborer.workType),
                    _chip(laborer.shift),
                    _chip(laborer.gender),
                    if (laborer.category.isNotEmpty) _chip(laborer.category),
                    if (laborer.location.isNotEmpty) _chip(laborer.location),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${laborer.wage.toStringAsFixed(0)} × ${laborer.hours} = ₹${cost.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(laborer.date),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                color: Colors.red.shade500, size: 22),
            onPressed: () => _removeLaborer(index),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonFormField<String>(
        initialValue: value != null && items.contains(value) ? value : null,
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

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: child,
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
