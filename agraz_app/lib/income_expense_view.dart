import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_token.dart';
import 'config.dart';

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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Filter Transactions'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedType.isEmpty ? null : _selectedType,
                    decoration: InputDecoration(labelText: 'Type'),
                    items: [
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
                  SizedBox(height: 10),
                  TextField(
                    controller: _categoryController,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      hintText: 'Enter category',
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _mobileController,
                    decoration: InputDecoration(
                      labelText: 'Mobile',
                      hintText: 'Enter mobile number',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _startDateController,
                    decoration: InputDecoration(
                      labelText: 'Start Date',
                      hintText: 'YYYY-MM-DD',
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _endDateController,
                    decoration: InputDecoration(
                      labelText: 'End Date',
                      hintText: 'YYYY-MM-DD',
                    ),
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
                child: Text('Clear'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _applyFilters();
                },
                child: Text('Apply'),
              ),
            ],
          ),
    );
  }

  static const Color _primaryGreen = Color(0xFF2E7D32);
  static const Color _incomeGreen = Color(0xFF4CAF50);
  static const Color _expenseRed = Color(0xFFE53935);

  String _formatAmount(dynamic amount) {
    final value = amount is num
        ? amount.toDouble()
        : double.tryParse(amount?.toString() ?? '') ?? 0.0;
    return value.toStringAsFixed(2);
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final bool isIncome = transaction['type'] == 'Income';
    final Color amountColor = isIncome ? _incomeGreen : _expenseRed;
    final Color bgColor = isIncome ? _incomeGreen.withValues(alpha: 0.1) : _expenseRed.withValues(alpha: 0.1);
    final String amountPrefix = isIncome ? '+' : '−';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isIncome ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              color: amountColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  transaction['category'] ?? 'No Category',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                if (transaction['sub_category'] != null)
                  Text(
                    transaction['sub_category'],
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                const SizedBox(height: 2),
                Text(
                  '${transaction['name'] ?? 'N/A'} · ${transaction['mobile'] ?? 'N/A'}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatDate(transaction['date']),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
                if (transaction['narration'] != null &&
                    transaction['narration'].toString().isNotEmpty)
                  Text(
                    transaction['narration'].toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$amountPrefix ₹${_formatAmount(transaction['amount'])}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: amountColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  transaction['type'] ?? 'Unknown',
                  style: TextStyle(
                    color: amountColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios),
            onPressed:
                _currentPage > 1
                    ? () {
                      setState(() {
                        _currentPage--;
                      });
                      _fetchTransactions();
                    }
                    : null,
          ),
          Text('Page $_currentPage of $_totalPages'),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios),
            onPressed:
                _currentPage < _totalPages
                    ? () {
                      setState(() {
                        _currentPage++;
                      });
                      _fetchTransactions();
                    }
                    : null,
          ),
        ],
      ),
    );
  }

  static const _screenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFE8F5E9),
      Color(0xFFF0F7F0),
      Color(0xFFF8F9FA),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _screenGradient),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text(
                  'Income & Expense',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                centerTitle: true,
                elevation: 0,
                backgroundColor: _primaryGreen,
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.filter_list_rounded),
                    onPressed: _showFilterDialog,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _fetchTransactions,
                  ),
                ],
              ),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: _primaryGreen),
                            const SizedBox(height: 12),
                            Text(
                              'Loading…',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
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
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _fetchTransactions,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primaryGreen,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              Container(
                                margin: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 14),
                                decoration: BoxDecoration(
                                  color: _primaryGreen,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _primaryGreen.withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    Column(
                                      children: [
                                        Text(
                                          '$_totalRecords',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          'Records',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white.withValues(alpha: 0.9),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      width: 1,
                                      height: 28,
                                      color: Colors.white.withValues(alpha: 0.4),
                                    ),
                                    Column(
                                      children: [
                                        Text(
                                          '$_currentPage / $_totalPages',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          'Page',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white.withValues(alpha: 0.9),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: _transactions.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.receipt_long_rounded,
                                              size: 44,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'No transactions found',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Try adjusting filters',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.only(
                                            top: 2, bottom: 8),
                                        itemCount: _transactions.length,
                                        itemBuilder: (context, index) {
                                          return _buildTransactionCard(
                                            _transactions[index],
                                          );
                                        },
                                      ),
                              ),
                              _buildPaginationControls(),
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
