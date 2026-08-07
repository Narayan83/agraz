import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_token.dart';
import 'config.dart';
import 'app_theme.dart';

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

    return Container(
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
            ],
          ),
        ],
      ),
    );
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
