import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'income_expense_data.dart';
import 'income_expense_view.dart';
import 'api_service.dart';

class IncomeExpensePage extends StatefulWidget {
  const IncomeExpensePage({super.key});

  @override
  State<IncomeExpensePage> createState() => _IncomeExpensePageState();
}

class _IncomeExpensePageState extends State<IncomeExpensePage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final IncomeExpenseData _formData = IncomeExpenseData();
  final ApiService _apiService = ApiService();

  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _narrationController = TextEditingController();
  final _amountController = TextEditingController();
  final _villageController = TextEditingController();
  final _postController = TextEditingController();
  final _talukController = TextEditingController();
  final _districtController = TextEditingController();
  final _extraAddressController = TextEditingController();
  final _pincodeController = TextEditingController();

  final List<String> receiptPaymentOptions = ['Income', 'Expense'];
  List<String> categories = [];
  List<String> subCategories = [];
  bool isLoading = false;

  /// Signed party balance (Income − Expense). Null when unknown / not loaded.
  double? _partyBalance;
  String _partyBalanceSide = 'settled';
  bool _partyDetailsLoaded = false;
  Timer? _nameSearchDebounce;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _formData.transactionDate = DateTime.now();
    _updateCategories();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _nameSearchDebounce?.cancel();
    _animController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _narrationController.dispose();
    _amountController.dispose();
    _villageController.dispose();
    _postController.dispose();
    _talukController.dispose();
    _districtController.dispose();
    _extraAddressController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  void _updateCategories() {
    if (_formData.receiptPaymentType == 'Income') {
      categories = ['Farming Income', 'Non-Farming Income'];
    } else if (_formData.receiptPaymentType == 'Expense') {
      categories = ['Farming Expense', 'Living Expense'];
    } else {
      categories = [];
    }
    _formData.category = null;
    _formData.subCategory = null;
    subCategories = [];
  }

  void _updateSubCategories(String selectedCategory) {
    setState(() {
      subCategories =
          _formData.categorySubCategoryMap[selectedCategory]?.keys.toList() ??
              [];
      _formData.subCategory = null;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _formData.transactionDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2E7D32),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1B5E20),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2E7D32),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _formData.transactionDate) {
      setState(() {
        _formData.transactionDate = picked;
      });
    }
  }

  void _clearPartyBalance() {
    _partyBalance = null;
    _partyBalanceSide = 'settled';
    _partyDetailsLoaded = false;
  }

  Future<void> _loadPartyBalance(String mobile) async {
    if (mobile.length != 10) {
      setState(_clearPartyBalance);
      return;
    }
    final bal = await _apiService.fetchPartyBalance(mobile);
    if (!mounted) return;
    if (bal == null) {
      setState(_clearPartyBalance);
      return;
    }
    setState(() {
      _partyBalance = (bal['balance'] as num?)?.toDouble() ?? 0;
      _partyBalanceSide = bal['side']?.toString() ?? 'settled';
      _partyDetailsLoaded = true;
    });
  }

  void _applyTransactionDetails(Map transaction) {
    if (_nameController.text.isEmpty) {
      _nameController.text = transaction['name']?.toString() ?? '';
    }
    final mobile = transaction['mobile']?.toString() ?? '';
    if (_mobileController.text.isEmpty && mobile.isNotEmpty) {
      _mobileController.text = mobile;
    }
    _villageController.text = transaction['village']?.toString() ?? '';
    _postController.text = transaction['post']?.toString() ?? '';
    _talukController.text = transaction['taluk']?.toString() ?? '';
    _districtController.text = transaction['district']?.toString() ?? '';
    _extraAddressController.text =
        transaction['extra_address']?.toString() ??
            transaction['extraAddress']?.toString() ??
            '';
    _pincodeController.text = transaction['pincode']?.toString() ?? '';
  }

  Future<void> _prefetchByMobile(String mobile) async {
    if (mobile.length != 10) {
      setState(_clearPartyBalance);
      return;
    }
    try {
      final responseData = await _apiService.fetchUserByMobile(mobile);
      if (!mounted) return;
      if (responseData != null &&
          responseData['data'] != null &&
          responseData['data'].isNotEmpty) {
        final transaction = responseData['data'][0];
        setState(() => _applyTransactionDetails(transaction));
      }
      await _loadPartyBalance(mobile);
    } catch (_) {
      if (mounted) await _loadPartyBalance(mobile);
    }
  }

  void _onNameChanged(String value) {
    _nameSearchDebounce?.cancel();
    final name = value.trim();
    if (name.length < 2) return;
    _nameSearchDebounce = Timer(const Duration(milliseconds: 450), () {
      _prefetchByName(name);
    });
  }

  Future<void> _prefetchByName(String name) async {
    try {
      final row = await _apiService.fetchUserByName(name);
      if (!mounted || row == null) return;
      setState(() => _applyTransactionDetails(row));
      final mobile = _mobileController.text.trim();
      if (mobile.length == 10) {
        await _loadPartyBalance(mobile);
      }
    } catch (_) {}
  }

  void _syncFormDataFromControllers() {
    _formData.name = _nameController.text.trim().isEmpty
        ? ''
        : _nameController.text.trim();
    _formData.mobile = _mobileController.text.trim().isEmpty
        ? ''
        : _mobileController.text.trim();
    _formData.narration = _narrationController.text.trim().isEmpty
        ? null
        : _narrationController.text.trim();
    _formData.village = _villageController.text.trim().isEmpty
        ? null
        : _villageController.text.trim();
    _formData.post =
        _postController.text.trim().isEmpty ? null : _postController.text.trim();
    _formData.taluk = _talukController.text.trim().isEmpty
        ? null
        : _talukController.text.trim();
    _formData.district = _districtController.text.trim().isEmpty
        ? null
        : _districtController.text.trim();
    _formData.extraAddress = _extraAddressController.text.trim().isEmpty
        ? null
        : _extraAddressController.text.trim();
    _formData.pincode = _pincodeController.text.trim().isEmpty
        ? null
        : _pincodeController.text.trim();
  }

  void _clearFormForNextEntry() {
    final keptType = _formData.receiptPaymentType;
    _nameController.clear();
    _mobileController.clear();
    _narrationController.clear();
    _amountController.clear();
    _villageController.clear();
    _postController.clear();
    _talukController.clear();
    _districtController.clear();
    _extraAddressController.clear();
    _pincodeController.clear();

    setState(() {
      _formData.amount = null;
      _formData.narration = null;
      _formData.mobile = null;
      _formData.name = null;
      _formData.village = null;
      _formData.post = null;
      _formData.taluk = null;
      _formData.district = null;
      _formData.extraAddress = null;
      _formData.pincode = null;
      _formData.transactionDate = DateTime.now();
      _formData.receiptPaymentType = keptType;
      _clearPartyBalance();
      _updateCategories();
    });
    _formKey.currentState?.reset();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    _syncFormDataFromControllers();

    if (_formData.receiptPaymentType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Income or Expense'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_formData.category == null || _formData.subCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select category and sub category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final success = await _apiService.submitTransaction(_formData);
      if (!mounted) return;
      setState(() => isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction recorded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _clearFormForNextEntry();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showOtherInfoSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Other Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Text(
                    'Optional address details',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  _sheetField('Village', Icons.location_city, _villageController),
                  _sheetField('Post', Icons.local_post_office, _postController),
                  _sheetField('Taluk', Icons.map, _talukController),
                  _sheetField('District', Icons.place, _districtController),
                  _sheetField(
                    'Extra Address',
                    Icons.note_add,
                    _extraAddressController,
                    maxLines: 2,
                  ),
                  _sheetField(
                    'Pincode',
                    Icons.pin_drop,
                    _pincodeController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    setState(() {});
  }

  Widget _sheetField(
    String label,
    IconData icon,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
          filled: true,
          fillColor: const Color(0xFFF5F7F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Farming Income':
        return const Color(0xFF4CAF50);
      case 'Non-Farming Income':
        return const Color(0xFF42A5F5);
      case 'Farming Expense':
        return const Color(0xFFFF9800);
      case 'Living Expense':
        return const Color(0xFFAB47BC);
      default:
        return const Color(0xFF78909C);
    }
  }

  bool get _hasOtherInfo {
    return _villageController.text.isNotEmpty ||
        _postController.text.isNotEmpty ||
        _talukController.text.isNotEmpty ||
        _districtController.text.isNotEmpty ||
        _extraAddressController.text.isNotEmpty ||
        _pincodeController.text.isNotEmpty;
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildTransactionTypeCard(),
                        const SizedBox(height: 8),
                        _buildDateAmountCard(),
                        const SizedBox(height: 8),
                        if (_formData.receiptPaymentType != null &&
                            categories.isNotEmpty)
                          _buildCategorySection(),
                        if (_formData.category != null &&
                            subCategories.isNotEmpty)
                          _buildSubCategorySection(),
                        const SizedBox(height: 8),
                        _buildPartyCard(),
                        const SizedBox(height: 8),
                        _buildNarrationCard(),
                        const SizedBox(height: 8),
                        _buildViewAllButton(),
                        const SizedBox(height: 6),
                        _buildOtherInfoButton(),
                        const SizedBox(height: 6),
                        _buildSubmitButton(),
                      ],
                    ),
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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF388E3C), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Record Transaction',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Income & Expense',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B5E20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTypeCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Transaction Type', Icons.swap_horiz_rounded),
          Row(
            children: [
              Expanded(
                child: _typeToggle(
                  'Income',
                  Icons.trending_up_rounded,
                  const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _typeToggle(
                  'Expense',
                  Icons.trending_down_rounded,
                  const Color(0xFFE53935),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeToggle(String type, IconData icon, Color color) {
    final selected = _formData.receiptPaymentType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _formData.receiptPaymentType = type;
          _updateCategories();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : Colors.grey.shade600,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              type,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade700,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateAmountCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Date & Amount', Icons.calendar_month_rounded),
          Row(
            children: [
              Expanded(child: _buildDateField()),
              const SizedBox(width: 12),
              Expanded(child: _buildAmountField()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: () => _selectDate(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              color: Color(0xFF2E7D32),
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('dd MMM yyyy').format(_formData.transactionDate!),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B5E20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: _amountController,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1B5E20),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Required';
          if (double.tryParse(value) == null) return 'Invalid';
          if (double.parse(value) <= 0) return 'Must be > 0';
          return null;
        },
        onSaved: (value) => _formData.amount = double.tryParse(value!),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          prefixIcon: const Icon(
            Icons.currency_rupee_rounded,
            color: Color(0xFF2E7D32),
            size: 16,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          hintText: 'Amount',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Category', Icons.category_rounded),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: categories.map((cat) => _categoryChip(cat)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label) {
    final selected = _formData.category == label;
    final color = _getCategoryColor(label);
    return GestureDetector(
      onTap: () {
        setState(() {
          _formData.category = label;
          _updateSubCategories(label);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSubCategorySection() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Sub Category', Icons.list_alt_rounded),
            _buildSubCategoryGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCategoryGrid() {
    final color = _getCategoryColor(_formData.category!);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.0,
      ),
      itemCount: subCategories.length,
      itemBuilder: (context, index) {
        final option = subCategories[index];
        final selected = _formData.subCategory == option;
        final emoji =
            _formData.categorySubCategoryMap[_formData.category]![option] ??
                '📋';
        return GestureDetector(
          onTap: () => setState(() => _formData.subCategory = option),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected ? color : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? color : color.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    option,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : const Color(0xFF1B5E20),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPartyCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('By / To', Icons.person_rounded),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7F5),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: TextFormField(
              controller: _nameController,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B5E20),
              ),
              onChanged: _onNameChanged,
              onSaved: (v) => _formData.name = v?.trim() ?? '',
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                prefixIcon: const Icon(
                  Icons.badge_rounded,
                  color: Color(0xFF2E7D32),
                  size: 16,
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
                hintText: 'Name (optional, for search)',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7F5),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: TextFormField(
              controller: _mobileController,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B5E20),
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              validator: (value) {
                if (value != null &&
                    value.isNotEmpty &&
                    value.length != 10) {
                  return '10 digits required';
                }
                return null;
              },
              onChanged: _prefetchByMobile,
              onSaved: (v) => _formData.mobile = v?.trim() ?? '',
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                prefixIcon: const Icon(
                  Icons.phone_rounded,
                  color: Color(0xFF2E7D32),
                  size: 16,
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
                hintText: 'By/To mobile',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (_partyDetailsLoaded && _partyBalance != null) ...[
            const SizedBox(height: 6),
            _buildBalanceChip(),
          ],
        ],
      ),
    );
  }

  Widget _buildBalanceChip() {
    final amount = _partyBalance!.abs();
    final isCredit = _partyBalanceSide == 'credit' || (_partyBalance! > 0);
    final isDebit = _partyBalanceSide == 'debit' || (_partyBalance! < 0);
    final color = isDebit
        ? const Color(0xFFD32F2F)
        : isCredit
            ? const Color(0xFF2E7D32)
            : Colors.grey.shade700;
    final label = isDebit
        ? 'Debit'
        : isCredit
            ? 'Credit'
            : 'Settled';
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            isDebit
                ? Icons.arrow_downward_rounded
                : isCredit
                    ? Icons.arrow_upward_rounded
                    : Icons.check_circle_outline,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            'Balance: $label ${fmt.format(amount)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrationCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Narration (optional)', Icons.description_rounded),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7F5),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: TextFormField(
              controller: _narrationController,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1B5E20)),
              maxLines: 2,
              validator: (value) {
                if (value != null && value.length > 200) {
                  return 'Max 200 characters';
                }
                return null;
              },
              onSaved: (value) => _formData.narration =
                  (value == null || value.trim().isEmpty) ? null : value.trim(),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Describe the transaction (optional)...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewAllButton() {
    return OutlinedButton.icon(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const IncomeExpenseListScreen()),
      ),
      icon: const Icon(Icons.receipt_long_rounded, size: 16),
      label: const Text('View All Transactions'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF2E7D32),
        side: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 10),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildOtherInfoButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showOtherInfoSheet,
        icon: Icon(
          _hasOtherInfo ? Icons.check_circle_outline : Icons.info_outline,
          size: 16,
        ),
        label: Text(
          _hasOtherInfo
              ? 'Other Information (filled)'
              : 'Other Information (optional)',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1565C0),
          side: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFA5D6A7),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save_rounded, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Submit',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}
