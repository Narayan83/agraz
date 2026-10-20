import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'income_expense_data.dart';
import 'income_expense_view.dart';
import 'income_expense_report.dart';
import 'farm_income_products.dart';
import 'api_service.dart';
import 'app_theme.dart';
import 'auth_token.dart';
import 'feedback_fab.dart';
import 'l10n/app_l10n.dart';
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
  List<String> categories = [];
  List<String> subCategories = [];
  bool isLoading = false;
  List<Map<String, dynamic>> _organizations = [];

  /// Signed party balance (Income − Expense). Null when unknown / not loaded.
  double? _partyBalance;
  String _partyBalanceSide = 'settled';
  bool _partyDetailsLoaded = false;
  Timer? _nameSearchDebounce;
  List<Map<String, dynamic>> _nameSuggestions = [];
  bool _showNameSuggestions = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

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
    _formData.transactionMode = 'Cash';
    _updateCategories();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapLogin());
  }

  Future<void> _bootstrapLogin() async {
    final ok = await ensureLoggedIn(context);
    if (!ok) {
      if (mounted) Navigator.pop(context);
      return;
    }
    await _loadOrganizations();
  }

  Future<void> _loadOrganizations() async {
    try {
      final token = await getValidAuthToken();
      if (token == null || token.isEmpty) return;
      final rows = await _apiService.fetchOrganizations();
      if (!mounted) return;
      setState(() => _organizations = rows);
    } catch (_) {}
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
    _formData.subCategories = [];
    subCategories = [];
  }

  void _updateSubCategories(String selectedCategory) {
    setState(() {
      subCategories =
          _formData.categorySubCategoryMap[selectedCategory]?.keys.toList() ??
              [];
      _formData.subCategory = null;
      _formData.subCategories = [];
      _formData.productLines = [];
    });
  }

  void _selectSubCategory(String option) {
    setState(() {
      final already =
          _formData.subCategories.length == 1 &&
          _formData.subCategories.first == option;
      if (already) {
        _formData.subCategories = [];
        _formData.subCategory = null;
        _formData.productLines = [];
        return;
      }
      final prev = _formData.subCategories.isEmpty
          ? null
          : _formData.subCategories.first;
      _formData.subCategories = [option];
      _formData.subCategory = option;
      if (prev != option) {
        _formData.productLines = [];
      }
    });
  }

  Future<void> _openProductDetails() async {
    if (!_formData.canAddProductDetails) return;
    final crop = _formData.effectiveSubCategories.first;
    final result = await showFarmIncomeProductLinesSheet(
      context: context,
      crop: crop,
      initial: List<FarmIncomeProductLine>.from(_formData.productLines),
    );
    if (result == null || !mounted) return;
    setState(() {
      _formData.productLines = result;
      if (result.isNotEmpty) {
        _formData.syncAmountFromProductLines();
        _amountController.text = _trimAmount(_formData.amount ?? 0);
      }
    });
  }

  String _trimAmount(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
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
    _nameSearchDebounce?.cancel();
    final name = row['name']?.toString() ?? '';
    final mobile = row['mobile']?.toString() ?? '';
    setState(() {
      if (name.isNotEmpty) {
        _nameController.text = name;
        _nameController.selection =
            TextSelection.collapsed(offset: _nameController.text.length);
      }
      if (mobile.isNotEmpty) {
        _mobileController.text = mobile;
      }
      _villageController.text = row['village']?.toString() ?? '';
      _postController.text = row['post']?.toString() ?? '';
      _talukController.text = row['taluk']?.toString() ?? '';
      _districtController.text = row['district']?.toString() ?? '';
      _extraAddressController.text =
          row['extra_address']?.toString() ??
              row['extraAddress']?.toString() ??
              '';
      _pincodeController.text = row['pincode']?.toString() ?? '';
      _nameSuggestions = [];
      _showNameSuggestions = false;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    final mob = _mobileController.text.trim();
    if (mob.length == 10) {
      _loadPartyBalance(mob);
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
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ensureLoggedIn(context, force: true);
              if (ok && mounted) {
                // Stay on the form; user can tap save again.
              }
            },
            child: Text(tr('Login')),
          ),
        ],
      ),
    );
  }

  void _clearFormForNextEntry() {
    final keptType = _formData.receiptPaymentType;
    // Do not call Form.reset() after clear — it restores TextFormField
    // values (including narration) from the last save.
    stopVoiceAndClearFields([
      _nameController,
      _mobileController,
      _narrationController,
      _amountController,
      _villageController,
      _postController,
      _talukController,
      _districtController,
      _extraAddressController,
      _pincodeController,
    ]);

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
      _formData.transactionMode = 'Cash';
      _formData.organizationId = null;
      _nameSuggestions = [];
      _showNameSuggestions = false;
      _clearPartyBalance();
      _formData.subCategories = [];
      _formData.productLines = [];
      _updateCategories();
    });
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
    if (_formData.category == null ||
        _formData.effectiveSubCategories.isEmpty) {
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
    if (_formData.transactionMode == 'Transfer' &&
        _formData.organizationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Please select an organization for transfer')),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    // Saving requires a valid login.
    if (!await ensureLoggedIn(context)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Login required to save')),
          backgroundColor: AppColors.expense,
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
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
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
                        child: Text(tr('Other Information'), style: AppText.h3),
                      ),
                      IconButton(
                        onPressed: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(tr('Optional address details'), style: AppText.small),
                  SizedBox(height: 16),
                  OutlinedAppField(
                    label: 'Village',
                    icon: Icons.location_city_rounded,
                    controller: _villageController,
                  ),
                  const SizedBox(height: 12),
                  OutlinedAppField(
                    label: 'Post',
                    icon: Icons.local_post_office_rounded,
                    controller: _postController,
                  ),
                  const SizedBox(height: 12),
                  OutlinedAppField(
                    label: 'Taluk',
                    icon: Icons.map_rounded,
                    controller: _talukController,
                  ),
                  const SizedBox(height: 12),
                  OutlinedAppField(
                    label: 'District',
                    icon: Icons.place_rounded,
                    controller: _districtController,
                  ),
                  const SizedBox(height: 12),
                  OutlinedAppField(
                    label: 'Extra Address',
                    icon: Icons.note_add_rounded,
                    controller: _extraAddressController,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  OutlinedAppField(
                    label: 'Pincode',
                    icon: Icons.pin_drop_rounded,
                    controller: _pincodeController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: 'Done',
                    icon: Icons.check_rounded,
                    flat: true,
                    height: 50,
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.pop(ctx);
                    },
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
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              AppHeader(
                title: tr('Record Transaction'),
                subtitle: tr('Income & Expense'),
                bottomRadius: 18,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: withFeedbackAction(
                    context,
                    menu: 'income_expense',
                    actions: const [],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStepper(),
                        const SizedBox(height: 14),
                        _buildBasicsCard(),
                        if (_formData.receiptPaymentType != null &&
                            categories.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildCategorySection(),
                        ],
                        if (_formData.category != null &&
                            subCategories.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildSubCategorySection(),
                        ],
                        if (_formData.canAddProductDetails) ...[
                          const SizedBox(height: 16),
                          _buildProductDetailsCard(),
                        ],
                        const SizedBox(height: 16),
                        _buildPartyCard(),
                        const SizedBox(height: 16),
                        _buildNarrationCard(),
                        const SizedBox(height: 16),
                        _buildSubmitButton(),
                        const SizedBox(height: 12),
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

  Widget _buildStepper() {
    final typeDone = _formData.receiptPaymentType != null;
    final detailsDone =
        _formData.category != null && (_formData.amount ?? 0) > 0;
    final partyDone = _nameController.text.trim().isNotEmpty ||
        _mobileController.text.trim().isNotEmpty;

    Widget step(String label, bool done) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? AppColors.primary : AppColors.surface,
              border: Border.all(
                color: done ? AppColors.primary : AppColors.fieldBorder,
                width: 1.2,
              ),
            ),
            child: Icon(
              done ? Icons.check_rounded : Icons.circle_outlined,
              color: done ? Colors.white : AppColors.textMuted,
              size: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: done ? FontWeight.w700 : FontWeight.w500,
              color: done ? AppColors.primary : AppColors.textMuted,
            ),
          ),
        ],
      );
    }

    Widget connector(bool done) {
      return Expanded(
        child: Container(
          height: 2,
          margin: const EdgeInsets.fromLTRB(6, 0, 6, 18),
          decoration: BoxDecoration(
            color: done
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: AppFieldStyle.box,
      child: Row(
        children: [
          step(tr('Type'), typeDone),
          connector(typeDone),
          step(tr('Details'), detailsDone),
          connector(detailsDone),
          step(tr('Party'), partyDone),
        ],
      ),
    );
  }

  Widget _buildBasicsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _typeToggle(
                'Income',
                Icons.trending_up_rounded,
                AppColors.income,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _typeToggle(
                'Expense',
                Icons.trending_down_rounded,
                AppColors.expense,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedAppDropdown(
          label: 'Mode',
          value: _formData.transactionMode,
          items: const ['Cash', 'Transfer'],
          icon: Icons.account_balance_wallet_outlined,
          onChanged: (v) {
            setState(() {
              _formData.transactionMode = v ?? 'Cash';
              if (_formData.transactionMode != 'Transfer') {
                _formData.organizationId = null;
              } else if (_organizations.isEmpty) {
                _loadOrganizations();
              }
            });
          },
        ),
        if (_formData.transactionMode == 'Transfer') ...[
          const SizedBox(height: 16),
          FieldLabel('Organization'),
          DropdownButtonFormField<int>(
            key: ValueKey('org-${_formData.organizationId}'),
            isExpanded: true,
            initialValue: _formData.organizationId,
            decoration: AppFieldStyle.outlined(icon: Icons.business_rounded),
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            dropdownColor: AppColors.surface,
            icon: const Icon(
              Icons.expand_more_rounded,
              color: AppColors.textMuted,
            ),
            items: _organizations.map((o) {
              final id = o['id'];
              final idInt = id is int ? id : int.tryParse('$id');
              return DropdownMenuItem<int>(
                value: idInt,
                child: Text('${o['name'] ?? ''}'),
              );
            }).where((e) => e.value != null).toList(),
            onChanged: (v) => setState(() => _formData.organizationId = v),
            validator: (v) {
              if (_formData.transactionMode == 'Transfer' && v == null) {
                return tr('Select organization');
              }
              return null;
            },
          ),
        ],
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildDateField()),
            const SizedBox(width: 12),
            Expanded(child: _buildAmountField()),
          ],
        ),
      ],
    );
  }

  Widget _typeToggle(String type, IconData icon, Color color) {
    final selected = _formData.receiptPaymentType == type;
    return Material(
      color: selected ? color : AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            _formData.receiptPaymentType = type;
            _updateCategories();
          });
        },
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : AppColors.fieldBorder,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? Colors.white : color, size: 18),
              const SizedBox(width: 8),
              Text(
                tr(type),
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    final dateText =
        DateFormat('dd/MM/yyyy').format(_formData.transactionDate!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('Date'),
        InkWell(
          onTap: () => _selectDate(context),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            // Match OutlinedAppField height; keep padding tight so
            // dd/MM/yyyy never wraps next to Amount on narrow screens.
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            decoration: AppFieldStyle.box,
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      dateText,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField() {
    return OutlinedAppField(
      controller: _amountController,
      label: 'Amount',
      icon: Icons.currency_rupee_rounded,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) {
        setState(() {
          _formData.amount = double.tryParse(v.trim());
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) return tr('Required');
        if (double.tryParse(value) == null) return tr('Invalid');
        if (double.parse(value) <= 0) return tr('Must be > 0');
        return null;
      },
      onSaved: (value) => _formData.amount = double.tryParse(value ?? ''),
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          icon: Icons.category_outlined,
          title: 'Category',
          tintedIcon: false,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((cat) => _categoryChip(cat)).toList(),
        ),
      ],
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Farming Income':
        return Icons.agriculture_rounded;
      case 'Non-Farming Income':
        return Icons.storefront_rounded;
      case 'Farming Expense':
        return Icons.eco_rounded;
      case 'Living Expense':
        return Icons.home_rounded;
      default:
        return Icons.category_rounded;
    }
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
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : AppColors.fieldBorder,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.2)
                    : color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _categoryIcon(label),
                color: selected ? Colors.white : color,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              tr(label),
              style: TextStyle(
                color: selected ? Colors.white : color,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          icon: Icons.grid_view_rounded,
          title: 'Sub-category',
          tintedIcon: false,
        ),
        const SizedBox(height: 12),
        _buildSubCategoryGrid(),
      ],
    );
  }

  Widget _buildProductDetailsCard() {
    final lines = _formData.productLines;
    final fmt = NumberFormat('#,##0.##');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          icon: Icons.grid_view_rounded,
          title: 'Product details',
          tintedIcon: false,
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _openProductDetails,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: AppFieldStyle.box,
            child: Row(
              children: [
                const Icon(
                  Icons.grid_view_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lines.isEmpty
                        ? tr('Add product details')
                        : '${tr('Total')}: ₹${fmt.format(_formData.productLinesTotal)}',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
              ],
            ),
          ),
        ),
        if (lines.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...lines.map((l) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${tr(l.product.isEmpty ? '—' : l.product)}'
                      ' · ${fmt.format(l.quantity)} ${l.unit}',
                      style: AppText.small,
                    ),
                  ),
                  Text(
                    '₹${fmt.format(l.total)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildSubCategoryGrid() {
    final color = _getCategoryColor(_formData.category!);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: subCategories.map((option) {
        final selected = _formData.subCategories.contains(option);
        final emoji =
            _formData.categorySubCategoryMap[_formData.category]![option] ??
                '📋';
        return ChoiceChip(
          selected: selected,
          showCheckmark: false,
          avatar: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.22)
                  : color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 13))),
          ),
          label: Text(
            tr(option),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
          selectedColor: color,
          backgroundColor: Colors.white,
          side: BorderSide(
            color: selected ? color : AppColors.fieldBorder,
            width: 1.2,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          onSelected: (_) => _selectSubCategory(option),
        );
      }).toList(),
    );
  }

  Widget _buildPartyCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          icon: Icons.person_outline_rounded,
          title: 'Party',
          tintedIcon: false,
        ),
        const SizedBox(height: 16),
        OutlinedAppField(
          controller: _nameController,
          label: 'Name',
          hint: 'Name (optional, for search)',
          icon: Icons.badge_rounded,
          onChanged: _onNameChanged,
          onSaved: (v) => _formData.name = v?.trim() ?? '',
          suffix: VoiceMicButton(
            fieldId: 'ie_name',
            controller: _nameController,
            compact: true,
            onTextChanged: () => _onNameChanged(_nameController.text),
          ),
        ),
        if (_showNameSuggestions && _nameSuggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.fieldBorder, width: 1.2),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _nameSuggestions.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, index) {
                final row = _nameSuggestions[index];
                final name = row['name']?.toString() ?? '';
                final mobile = row['mobile']?.toString() ?? '';
                final village = row['village']?.toString() ?? '';
                return ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.person_search_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
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
        const SizedBox(height: 16),
        OutlinedAppField(
          controller: _mobileController,
          label: 'Mobile',
          hint: 'By/To mobile',
          icon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: (value) {
            if (value != null && value.isNotEmpty && value.length != 10) {
              return '10 digits required';
            }
            return null;
          },
          onChanged: (v) {
            _prefetchByMobile(v);
          },
          onSaved: (v) => _formData.mobile = v?.trim() ?? '',
        ),
        if (_partyDetailsLoaded && _partyBalance != null) ...[
          const SizedBox(height: 10),
          _buildBalanceChip(),
        ],
      ],
    );
  }

  Widget _buildBalanceChip() {
    final amount = _partyBalance!.abs();
    final isCredit = _partyBalanceSide == 'credit' || (_partyBalance! > 0);
    final isDebit = _partyBalanceSide == 'debit' || (_partyBalance! < 0);
    final color = isDebit
        ? AppColors.expense
        : isCredit
            ? AppColors.income
            : Colors.grey.shade600;
    final label = isDebit
        ? 'Debit'
        : isCredit
            ? 'Credit'
            : 'Settled';
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isDebit
                ? Icons.arrow_downward_rounded
                : isCredit
                    ? Icons.arrow_upward_rounded
                    : Icons.check_circle_outline,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            'Balance: $label ${fmt.format(amount)}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrationCard() {
    return OutlinedAppField(
      controller: _narrationController,
      label: 'Narration (optional)',
      hint: 'Enter narration (optional)',
      icon: Icons.description_rounded,
      minLines: 1,
      maxLines: 6,
      suffix: VoiceMicButton(
        fieldId: 'ie_narration',
        controller: _narrationController,
        compact: true,
      ),
      onSaved: (value) => _formData.narration =
          (value == null || value.trim().isEmpty) ? null : value.trim(),
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
                color: AppColors.primary,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const IncomeExpenseReportPage(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _halfOutlinedButton(
                label: 'View All',
                icon: Icons.receipt_long_rounded,
                color: AppColors.primary,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const IncomeExpenseListScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _halfOutlinedButton(
                label: _hasOtherInfo ? 'Other Info ✓' : 'Other Info',
                icon: _hasOtherInfo
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
                color: AppColors.primary,
                onPressed: _showOtherInfoSheet,
              ),
            ),
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
        side: const BorderSide(color: AppColors.fieldBorder, width: 1.2),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        minimumSize: const Size(0, 44),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return PrimaryButton(
      label: isLoading ? 'Saving…' : 'Submit',
      icon: Icons.check_circle_rounded,
      onPressed: isLoading ? null : _submitForm,
      loading: isLoading,
      flat: true,
      height: 50,
    );
  }
}
