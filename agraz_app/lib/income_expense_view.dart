import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'auth_token.dart';
import 'config.dart';
import 'app_theme.dart';
import 'income_expense_data.dart';

class IncomeExpenseListScreen extends StatefulWidget {
  const IncomeExpenseListScreen({super.key});

  @override
  _IncomeExpenseListScreenState createState() =>
      _IncomeExpenseListScreenState();
}

class _IncomeExpenseListScreenState extends State<IncomeExpenseListScreen> {
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int _currentPage = 1;
  int _totalPages = 1;
  final int _limit = 10;
  int _totalRecords = 0;

  // Filters
  String _selectedType = '';
  String _selectedCategory = '';
  String _selectedMobile = '';
  String _startDate = '';
  String _endDate = '';

  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _mobileController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  int get _incomeCount =>
      _transactions.where((t) => t['type'] == 'Income').length;
  int get _expenseCount =>
      _transactions.where((t) => t['type'] == 'Expense').length;

  Future<void> _fetchTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final Map<String, String> queryParams = {
        'page': _currentPage.toString(),
        'limit': _limit.toString(),
      };

      if (_selectedType.isNotEmpty) {
        queryParams['type'] = _selectedType;
      }
      if (_selectedCategory.isNotEmpty) {
        queryParams['category'] = _selectedCategory;
      }
      if (_selectedMobile.isNotEmpty) {
        queryParams['mobile'] = _selectedMobile;
      }
      if (_startDate.isNotEmpty && _endDate.isNotEmpty) {
        queryParams['start_date'] = _startDate;
        queryParams['end_date'] = _endDate;
      }

      final uri = Uri.parse(
        '$BASE_URL/api/income_expense',
      ).replace(queryParameters: queryParams);

      final headers = await authGetHeaders();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _transactions = data['data'];
          _totalRecords = data['total'];
          _totalPages = (_totalRecords / _limit).ceil();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load transactions: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _selectedCategory = _categoryController.text;
      _selectedMobile = _mobileController.text;
      _startDate = _startDateController.text;
      _endDate = _endDateController.text;
      _currentPage = 1;
    });
    _fetchTransactions();
  }

  void _clearFilters() {
    setState(() {
      _selectedType = '';
      _selectedCategory = '';
      _selectedMobile = '';
      _startDate = '';
      _endDate = '';
      _categoryController.clear();
      _mobileController.clear();
      _startDateController.clear();
      _endDateController.clear();
      _currentPage = 1;
    });
    _fetchTransactions();
  }

  Future<void> _pickFilterDate(TextEditingController ctrl) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      ctrl.text = '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Filter Transactions'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedType.isEmpty ? null : _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      prefixIcon: Icon(Icons.swap_horiz_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All Types')),
                      DropdownMenuItem(value: 'Income', child: Text('Income')),
                      DropdownMenuItem(
                        value: 'Expense',
                        child: Text('Expense'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _mobileController,
                    decoration: const InputDecoration(
                      labelText: 'Mobile',
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _startDateController,
                          readOnly: true,
                          onTap: () => _pickFilterDate(_startDateController),
                          decoration: const InputDecoration(
                            labelText: 'Start Date',
                            prefixIcon: Icon(Icons.event_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _endDateController,
                          readOnly: true,
                          onTap: () => _pickFilterDate(_endDateController),
                          decoration: const InputDecoration(
                            labelText: 'End Date',
                            prefixIcon: Icon(Icons.event_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _clearFilters();
                },
                child: const Text('Clear'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _applyFilters();
                },
                child: const Text('Apply'),
              ),
            ],
          ),
    );
  }

  String _formatAmount(dynamic amount) {
    final value = amount is num
        ? amount.toDouble()
        : double.tryParse(amount?.toString() ?? '') ?? 0.0;
    return value.toStringAsFixed(2);
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _truncate(String s, int n) =>
      s.length <= n ? s : '${s.substring(0, n)}…';

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final bool isIncome = transaction['type'] == 'Income';
    final Color amountColor = isIncome ? AppColors.income : AppColors.expense;
    final String amountPrefix = isIncome ? '+' : '−';
    final name = transaction['name']?.toString() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openTransactionDetail(transaction),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [AppColors.softShadow],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TintedIcon(
                icon: isIncome
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
                color: amountColor,
                boxSize: 40,
                size: 20,
                radius: 12,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      transaction['category'] ?? 'No Category',
                      style: AppText.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (transaction['sub_category'] != null)
                      Text(
                        transaction['sub_category'],
                        style: AppText.small,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (name.isNotEmpty)
                          InfoChip(
                            label: _truncate(name, 20),
                            color: AppColors.info,
                            icon: Icons.person_outline_rounded,
                          ),
                        InfoChip(
                          label: _formatDate(transaction['date'] ?? ''),
                          color: AppColors.textMuted,
                          icon: Icons.event_rounded,
                        ),
                      ],
                    ),
                    if (transaction['narration'] != null &&
                        transaction['narration'].toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        transaction['narration'].toString(),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$amountPrefix ₹${_formatAmount(transaction['amount'])}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InfoChip(
                    label: isIncome ? 'Income' : 'Expense',
                    color: amountColor,
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTransactionDetail(Map<String, dynamic> transaction) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TransactionDetailSheet(
        transaction: Map<String, dynamic>.from(transaction),
      ),
    );
    if (changed == true && mounted) {
      _fetchTransactions();
    }
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _pageButton(
            Icons.arrow_back_rounded,
            _currentPage > 1,
            () {
              setState(() {
                _currentPage--;
              });
              _fetchTransactions();
            },
          ),
          const SizedBox(width: 12),
          Text(
            'Page $_currentPage of $_totalPages',
            style: AppText.label,
          ),
          const SizedBox(width: 12),
          _pageButton(
            Icons.arrow_forward_rounded,
            _currentPage < _totalPages,
            () {
              setState(() {
                _currentPage++;
              });
              _fetchTransactions();
            },
          ),
        ],
      ),
    );
  }

  Widget _pageButton(IconData icon, bool enabled, VoidCallback onTap) {
    return Material(
      color: enabled ? AppColors.primarySoft : AppColors.field,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppColors.primary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.headerGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _statItem('$_totalRecords', 'Records'),
          const SizedBox(height: 34, child: VerticalDivider(color: Colors.white24, width: 1)),
          _statItem('$_incomeCount', 'Income'),
          const SizedBox(height: 34, child: VerticalDivider(color: Colors.white24, width: 1)),
          _statItem('$_expenseCount', 'Expense'),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
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
      appBar: AppBar(
        title: const Text(
          'Income & Expense',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.headerGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Filter',
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _fetchTransactions,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsCard(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Loading…', style: AppText.small),
                      ],
                    ),
                  )
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _errorMessage,
                                style: const TextStyle(
                                  color: AppColors.expense,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _fetchTransactions,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _transactions.isEmpty
                        ? const EmptyState(
                            icon: Icons.receipt_long_rounded,
                            title: 'No transactions found',
                            subtitle: 'Try adjusting the filters',
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: RefreshIndicator(
                                  onRefresh: _fetchTransactions,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      bottom: 8,
                                    ),
                                    itemCount: _transactions.length,
                                    itemBuilder: (context, index) {
                                      return _buildTransactionCard(
                                        _transactions[index],
                                      );
                                    },
                                  ),
                                ),
                              ),
                              _buildPaginationControls(),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}

class _TransactionDetailSheet extends StatefulWidget {
  final Map<String, dynamic> transaction;

  const _TransactionDetailSheet({required this.transaction});

  @override
  State<_TransactionDetailSheet> createState() =>
      _TransactionDetailSheetState();
}

class _TransactionDetailSheetState extends State<_TransactionDetailSheet> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();
  final _cats = IncomeExpenseData();

  late String _type;
  late String? _category;
  late String? _subCategory;
  late DateTime _date;
  final _amountCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _narrationCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _postCtrl = TextEditingController();
  final _talukCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _extraCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();

  bool _editing = false;
  bool _saving = false;
  bool _deleting = false;

  List<String> get _categories {
    if (_type == 'Income') return ['Farming Income', 'Non-Farming Income'];
    if (_type == 'Expense') return ['Farming Expense', 'Living Expense'];
    return [];
  }

  List<String> get _subCategories =>
      _cats.categorySubCategoryMap[_category ?? '']?.keys.toList() ?? [];

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _type = t['type']?.toString() ?? 'Income';
    _category = t['category']?.toString();
    _subCategory = t['sub_category']?.toString();
    _amountCtrl.text = _numStr(t['amount']);
    _nameCtrl.text = t['name']?.toString() ?? '';
    _mobileCtrl.text = t['mobile']?.toString() ?? '';
    _narrationCtrl.text = t['narration']?.toString() ?? '';
    _villageCtrl.text = t['village']?.toString() ?? '';
    _postCtrl.text = t['post']?.toString() ?? '';
    _talukCtrl.text = t['taluk']?.toString() ?? '';
    _districtCtrl.text = t['district']?.toString() ?? '';
    _extraCtrl.text =
        (t['extra_address'] ?? t['extraAddress'])?.toString() ?? '';
    _pincodeCtrl.text = t['pincode']?.toString() ?? '';
    _date = DateTime.tryParse(t['date']?.toString() ?? '') ?? DateTime.now();
  }

  String _numStr(dynamic v) {
    if (v is num) return v.toStringAsFixed(2);
    return double.tryParse(v?.toString() ?? '')?.toStringAsFixed(2) ?? '';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _narrationCtrl.dispose();
    _villageCtrl.dispose();
    _postCtrl.dispose();
    _talukCtrl.dispose();
    _districtCtrl.dispose();
    _extraCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  int? get _id {
    final v = widget.transaction['id'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }

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
    if (!_formKey.currentState!.validate()) return;
    final id = _id;
    if (id == null) return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    if (_category == null || _subCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category and sub-category required')),
      );
      return;
    }

    final data = IncomeExpenseData()
      ..receiptPaymentType = _type
      ..category = _category
      ..subCategory = _subCategory
      ..amount = amount
      ..narration = _narrationCtrl.text.trim()
      ..mobile = _mobileCtrl.text.trim()
      ..transactionDate = _date
      ..name = _nameCtrl.text.trim()
      ..village = _villageCtrl.text.trim()
      ..post = _postCtrl.text.trim()
      ..taluk = _talukCtrl.text.trim()
      ..district = _districtCtrl.text.trim()
      ..extraAddress = _extraCtrl.text.trim()
      ..pincode = _pincodeCtrl.text.trim();

    setState(() => _saving = true);
    try {
      await _api.updateTransaction(id, data);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.expense),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final id = _id;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This income/expense record will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _deleting = true);
    final deleted = await _api.deleteTransaction(id);
    if (!mounted) return;
    setState(() => _deleting = false);
    if (deleted) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete'),
          backgroundColor: AppColors.expense,
        ),
      );
    }
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    TextInputType? keyboard,
    int maxLines = 1,
    bool required = false,
    List<TextInputFormatter>? formatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        enabled: _editing,
        keyboardType: keyboard,
        maxLines: maxLines,
        inputFormatters: formatters,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: AppColors.field,
        ),
      ),
    );
  }

  Widget _readonlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: AppText.small),
          ),
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
    final isIncome = _type == 'Income';
    final accent = isIncome ? AppColors.income : AppColors.expense;

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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _editing ? 'Edit entry' : 'Entry details',
                    style: AppText.title,
                  ),
                ),
                if (!_editing)
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: () => setState(() => _editing = true),
                    icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
                  ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: _deleting ? null : _delete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.expense.withValues(alpha: _deleting ? 0.4 : 1),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            InfoChip(label: _type, color: accent),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: _editing ? _buildEditForm() : _buildReadonly(),
              ),
            ),
            if (_editing) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() => _editing = false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
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

  Widget _buildReadonly() {
    final t = widget.transaction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _readonlyRow('Category', t['category']?.toString() ?? ''),
        _readonlyRow('Sub-category', t['sub_category']?.toString() ?? ''),
        _readonlyRow('Amount', '₹${_numStr(t['amount'])}'),
        _readonlyRow(
          'Date',
          '${_date.day.toString().padLeft(2, '0')}/'
              '${_date.month.toString().padLeft(2, '0')}/'
              '${_date.year}',
        ),
        _readonlyRow('Name', t['name']?.toString() ?? ''),
        _readonlyRow('Mobile', t['mobile']?.toString() ?? ''),
        _readonlyRow('Narration', t['narration']?.toString() ?? ''),
        _readonlyRow('Village', t['village']?.toString() ?? ''),
        _readonlyRow('Post', t['post']?.toString() ?? ''),
        _readonlyRow('Taluk', t['taluk']?.toString() ?? ''),
        _readonlyRow('District', t['district']?.toString() ?? ''),
        _readonlyRow(
          'Extra address',
          (t['extra_address'] ?? t['extraAddress'])?.toString() ?? '',
        ),
        _readonlyRow('Pincode', t['pincode']?.toString() ?? ''),
        const SizedBox(height: 8),
        Text(
          'Tap the edit icon to change this entry.',
          style: AppText.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Type', filled: true),
          items: const [
            DropdownMenuItem(value: 'Income', child: Text('Income')),
            DropdownMenuItem(value: 'Expense', child: Text('Expense')),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _type = v;
              _category = null;
              _subCategory = null;
            });
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _categories.contains(_category) ? _category : null,
          decoration:
              const InputDecoration(labelText: 'Category', filled: true),
          items: _categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) {
            setState(() {
              _category = v;
              _subCategory = null;
            });
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _subCategories.contains(_subCategory) ? _subCategory : null,
          decoration:
              const InputDecoration(labelText: 'Sub-category', filled: true),
          items: _subCategories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _subCategory = v),
        ),
        const SizedBox(height: 10),
        _field(
          'Amount',
          _amountCtrl,
          keyboard: const TextInputType.numberWithOptions(decimal: true),
          required: true,
        ),
        InkWell(
          onTap: _pickDate,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date',
              filled: true,
              prefixIcon: Icon(Icons.event_rounded),
            ),
            child: Text(
              '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
            ),
          ),
        ),
        const SizedBox(height: 10),
        _field('Name', _nameCtrl),
        _field('Mobile', _mobileCtrl, keyboard: TextInputType.phone),
        _field('Narration', _narrationCtrl, maxLines: 2),
        _field('Village', _villageCtrl),
        _field('Post', _postCtrl),
        _field('Taluk', _talukCtrl),
        _field('District', _districtCtrl),
        _field('Extra address', _extraCtrl),
        _field('Pincode', _pincodeCtrl, keyboard: TextInputType.number),
      ],
    );
  }
}
