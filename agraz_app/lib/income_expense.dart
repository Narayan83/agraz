import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'income_expense_data.dart';
import 'income_expense_view.dart';
import 'income_expense_report.dart';
import 'api_service.dart';
import 'app_theme.dart';
import 'auth_token.dart';
import 'l10n/app_l10n.dart';
import 'login.dart';
import 'voice_dictation.dart';

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
  String? _pressedToggle;
  List<String> categories = [];
  List<String> subCategories = [];
  bool isLoading = false;

  /// Signed party balance (Income − Expense). Null when unknown / not loaded.
  double? _partyBalance;
  String _partyBalanceSide = 'settled';
  bool _partyDetailsLoaded = false;
  Timer? _nameSearchDebounce;
  List<Map<String, dynamic>> _nameSuggestions = [];
  bool _showNameSuggestions = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  String get _partyLabel {
    if (_formData.receiptPaymentType == 'Expense') return tr('To');
    if (_formData.receiptPaymentType == 'Income') return tr('By');
    return tr('By / To');
  }

  bool _isJwtError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('invalid or expired jwt') ||
        msg.contains('missing or malformed jwt') ||
        msg.contains('unauthorized') ||
        msg.contains('401');
  }

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
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
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
    if (name.length < 2) {
      setState(() {
        _nameSuggestions = [];
        _showNameSuggestions = false;
      });
      return;
    }
    _nameSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      _searchNameSuggestions(name);
    });
  }

  Future<void> _searchNameSuggestions(String name) async {
    try {
      final rows = await _apiService.searchUsersByName(name);
      if (!mounted) return;
      setState(() {
        _nameSuggestions = rows;
        _showNameSuggestions = rows.isNotEmpty;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _nameSuggestions = [];
          _showNameSuggestions = false;
        });
      }
    }
  }

  void _applySuggestion(Map<String, dynamic> row) {
    setState(() {
      _applyTransactionDetails(row);
      _nameSuggestions = [];
      _showNameSuggestions = false;
    });
    final mobile = _mobileController.text.trim();
    if (mobile.length == 10) {
      _loadPartyBalance(mobile);
    }
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
    final amt = double.tryParse(_amountController.text.trim());
    if (amt != null) _formData.amount = amt;
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

  Future<void> _showJwtExpiredDialog() async {
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
              tr('Invalid or expired JWT. Please login again to continue.'),
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
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushNamed('/login');
            },
            child: Text(tr('Login')),
          ),
        ],
      ),
    );
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
      _nameSuggestions = [];
      _showNameSuggestions = false;
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
        SnackBar(
          content: Text(tr('Please select Income or Expense')),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }
    if (_formData.category == null || _formData.subCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Please select category and sub category')),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }
    if (_formData.amount == null || _formData.amount! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Please enter a valid amount')),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    // Guest can browse; saving requires login.
    var token = await getAuthToken();
    if (token == null || token.isEmpty) {
      final loggedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (loggedIn != true || !mounted) return;
      token = await getAuthToken();
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Login required to save')),
            backgroundColor: AppColors.expense,
          ),
        );
        return;
      }
    }

    setState(() => isLoading = true);
    try {
      final success = await _apiService.submitTransaction(_formData);
      if (!mounted) return;
      setState(() => isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Transaction recorded successfully!')),
            backgroundColor: AppColors.income,
          ),
        );
        _clearFormForNextEntry();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      if (_isJwtError(e)) {
        await _showJwtExpiredDialog();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.expense,
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
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  SizedBox(height: 14),
                  Row(
                    children: [
                      TintedIcon(
                        icon: Icons.location_on_rounded,
                        color: AppColors.primary,
                        boxSize: 40,
                        size: 20,
                        radius: 12,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('Other Information', style: AppText.h3),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text('Optional address details', style: AppText.small),
                  SizedBox(height: 16),
                  AppField(
                    label: 'Village',
                    icon: Icons.location_city_rounded,
                    controller: _villageController,
                  ),
                  SizedBox(height: 12),
                  AppField(
                    label: 'Post',
                    icon: Icons.local_post_office_rounded,
                    controller: _postController,
                  ),
                  SizedBox(height: 12),
                  AppField(
                    label: 'Taluk',
                    icon: Icons.map_rounded,
                    controller: _talukController,
                  ),
                  SizedBox(height: 12),
                  AppField(
                    label: 'District',
                    icon: Icons.place_rounded,
                    controller: _districtController,
                  ),
                  SizedBox(height: 12),
                  AppField(
                    label: 'Extra Address',
                    icon: Icons.note_add_rounded,
                    controller: _extraAddressController,
                    maxLines: 2,
                  ),
                  SizedBox(height: 12),
                  AppField(
                    label: 'Pincode',
                    icon: Icons.pin_drop_rounded,
                    controller: _pincodeController,
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 18),
                  PrimaryButton(
                    label: 'Done',
                    icon: Icons.check_rounded,
                    onPressed: () => Navigator.pop(ctx),
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

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Farming Income':
        return AppColors.income;
      case 'Non-Farming Income':
        return AppColors.info;
      case 'Farming Expense':
        return AppColors.warning;
      case 'Living Expense':
        return AppColors.expense;
      default:
        return AppColors.textMuted;
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              AppHeader(
                icon: Icons.account_balance_wallet_rounded,
                title: tr('Record Transaction'),
                subtitle: tr('Income & Expense'),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildTransactionTypeCard(),
                        SizedBox(height: 8),
                        _buildDateAmountCard(),
                        SizedBox(height: 8),
                        if (_formData.receiptPaymentType != null &&
                            categories.isNotEmpty) ...[
                          SizedBox(height: 14),
                          _buildCategorySection(),
                        ],
                        if (_formData.category != null &&
                            subCategories.isNotEmpty) ...[
                          SizedBox(height: 14),
                          _buildSubCategorySection(),
                        ],
                        SizedBox(height: 8),
                        _buildPartyCard(),
                        SizedBox(height: 8),
                        _buildNarrationCard(),
                        SizedBox(height: 10),
                        _buildSubmitButton(),
                        SizedBox(height: 8),
                        _buildSecondaryActions(),
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
          SizedBox(width: 10),
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
          SizedBox(width: 10),
          Expanded(
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
          SizedBox(width: 6),
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: Icons.swap_horiz_rounded,
            title: tr('Transaction Type'),
            subtitle: tr('Is this money in or money out?'),
          ),
          SizedBox(height: 14),
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
              SizedBox(width: 12),
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
        ],
      ),
    );
  }

  Widget _typeToggle(String type, IconData icon, Color color, Color softColor) {
    final selected = _formData.receiptPaymentType == type;
    final pressed = _pressedToggle == type;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressedToggle = type),
      onTapUp: (_) => setState(() => _pressedToggle = null),
      onTapCancel: () => setState(() => _pressedToggle = null),
      onTap: () {
        setState(() {
          _formData.receiptPaymentType = type;
          _updateCategories();
        });
      },
      child: AnimatedScale(
        scale: pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          height: 92,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color.lerp(color, Colors.white, 0.12)!, color],
                  )
                : null,
            color: selected ? null : softColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.35),
              width: selected ? 1.6 : 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.22)
                          : Colors.white,
                      border: Border.all(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.35)
                            : color.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: selected ? Colors.white : color,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          type,
                          style: TextStyle(
                            color: selected ? Colors.white : color,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          selected ? 'Selected' : 'Tap to select',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected
                                ? Colors.white.withValues(alpha: 0.9)
                                : AppColors.textMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: color,
                      size: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateAmountCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: Icons.calendar_month_rounded,
            title: tr('Date & Amount'),
            subtitle: tr('When and how much?'),
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildDateField()),
              SizedBox(width: 12),
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
            SizedBox(width: 8),
            Text(
              DateFormat('dd/MM/yyyy').format(_formData.transactionDate!),
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
          hintText: tr('Amount'),
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: Icons.category_rounded,
            title: tr('Category'),
            subtitle: tr('Pick the type of income or expense'),
          ),
          SizedBox(height: 14),
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
            width: 1.4,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
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
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                color: selected ? color : AppColors.border,
                width: 1.4,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: TextStyle(fontSize: 16)),
                SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    option,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.textPrimary,
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(_partyLabel, Icons.person_rounded),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
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
                      hintText: tr('Name (optional, for search)'),
                      hintStyle:
                          TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              VoiceMicButton(
                fieldId: 'ie_name',
                controller: _nameController,
                onTextChanged: () => _onNameChanged(_nameController.text),
              ),
            ],
          ),
          if (_showNameSuggestions && _nameSuggestions.isNotEmpty) ...[
            SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: [AppColors.softShadow],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _nameSuggestions.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: AppColors.border),
                itemBuilder: (context, index) {
                  final row = _nameSuggestions[index];
                  final name = row['name']?.toString() ?? '';
                  final mobile = row['mobile']?.toString() ?? '';
                  final village = row['village']?.toString() ?? '';
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_search_rounded,
                        color: AppColors.primary, size: 20),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      [
                        if (mobile.isNotEmpty) mobile,
                        if (village.isNotEmpty) village,
                      ].join(' · '),
                      style: AppText.caption,
                    ),
                    onTap: () => _applySuggestion(row),
                  );
                },
              ),
            ),
          ],
          SizedBox(height: 6),
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
                hintText: tr('By/To mobile'),
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (_partyDetailsLoaded && _partyBalance != null) ...[
            SizedBox(height: 6),
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
          SizedBox(width: 6),
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionTitle(
                  tr('Narration (optional)'),
                  Icons.description_rounded,
                ),
              ),
              VoiceMicButton(
                fieldId: 'ie_narration',
                controller: _narrationController,
              ),
            ],
          ),
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
                hintText: tr('Describe the transaction (optional)...'),
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _halfOutlinedButton(
                label: 'Reports',
                icon: Icons.insights_rounded,
                color: AppColors.info,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const IncomeExpenseReportPage(),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _halfOutlinedButton(
                label: 'View All',
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFF2E7D32),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const IncomeExpenseListScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _halfOutlinedButton(
                label: _hasOtherInfo ? 'Other Info ✓' : 'Other Info',
                icon: _hasOtherInfo
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
                color: const Color(0xFF1565C0),
                onPressed: _showOtherInfoSheet,
              ),
            ),
            SizedBox(width: 8),
            Expanded(child: SizedBox.shrink()),
          ],
        ),
      ],
    );
  }

  Widget _halfOutlinedButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.55), width: 1.4),
        backgroundColor: color.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        minimumSize: const Size(0, 42),
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
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
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
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}
