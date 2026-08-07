import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'income_expense_data.dart';
import 'income_expense_view.dart';
import 'api_service.dart';
import 'app_theme.dart';

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

  Future<void> _prefetchByMobile(String mobile) async {
    if (mobile.length != 10) return;
    try {
      final responseData = await _apiService.fetchUserByMobile(mobile);
      if (responseData != null &&
          responseData['data'] != null &&
          responseData['data'].isNotEmpty) {
        final transaction = responseData['data'][0];
        setState(() {
          if (_nameController.text.isEmpty) {
            _nameController.text = transaction['name']?.toString() ?? '';
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
        });
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
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }
    if (_formData.category == null || _formData.subCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select category and sub category'),
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
          const SnackBar(
            content: Text('Transaction recorded successfully!'),
            backgroundColor: AppColors.income,
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
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      TintedIcon(
                        icon: Icons.location_on_rounded,
                        color: AppColors.primary,
                        boxSize: 40,
                        size: 20,
                        radius: 12,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Other Information', style: AppText.h3),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Optional address details', style: AppText.small),
                  const SizedBox(height: 16),
                  AppField(
                    label: 'Village',
                    icon: Icons.location_city_rounded,
                    controller: _villageController,
                  ),
                  const SizedBox(height: 12),
                  AppField(
                    label: 'Post',
                    icon: Icons.local_post_office_rounded,
                    controller: _postController,
                  ),
                  const SizedBox(height: 12),
                  AppField(
                    label: 'Taluk',
                    icon: Icons.map_rounded,
                    controller: _talukController,
                  ),
                  const SizedBox(height: 12),
                  AppField(
                    label: 'District',
                    icon: Icons.place_rounded,
                    controller: _districtController,
                  ),
                  const SizedBox(height: 12),
                  AppField(
                    label: 'Extra Address',
                    icon: Icons.note_add_rounded,
                    controller: _extraAddressController,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  AppField(
                    label: 'Pincode',
                    icon: Icons.pin_drop_rounded,
                    controller: _pincodeController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 18),
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
              const AppHeader(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Record Transaction',
                subtitle: 'Income & Expense',
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildTransactionTypeCard(),
                        const SizedBox(height: 14),
                        _buildDateAmountCard(),
                        if (_formData.receiptPaymentType != null &&
                            categories.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _buildCategorySection(),
                        ],
                        if (_formData.category != null &&
                            subCategories.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _buildSubCategorySection(),
                        ],
                        const SizedBox(height: 14),
                        _buildPartyCard(),
                        const SizedBox(height: 14),
                        _buildNarrationCard(),
                        const SizedBox(height: 18),
                        _buildViewAllButton(),
                        const SizedBox(height: 10),
                        _buildOtherInfoButton(),
                        const SizedBox(height: 14),
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

  Widget _buildTransactionTypeCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            icon: Icons.swap_horiz_rounded,
            title: 'Transaction Type',
            subtitle: 'Is this money in or money out?',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _typeToggle(
                  'Income',
                  Icons.trending_up_rounded,
                  AppColors.income,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _typeToggle(
                  'Expense',
                  Icons.trending_down_rounded,
                  AppColors.expense,
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
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.field,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : AppColors.textSecondary,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              type,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              selected ? 'Selected' : 'Tap to select',
              style: TextStyle(
                color: selected ? Colors.white70 : AppColors.textMuted,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateAmountCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            icon: Icons.calendar_month_rounded,
            title: 'Date & Amount',
            subtitle: 'When and how much?',
          ),
          const SizedBox(height: 14),
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
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date',
          prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
          prefixIconConstraints: BoxConstraints(minWidth: 44, minHeight: 0),
        ),
        child: Text(
          DateFormat('dd MMM yyyy').format(_formData.transactionDate!),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required';
        if (double.tryParse(value) == null) return 'Invalid';
        if (double.parse(value) <= 0) return 'Must be > 0';
        return null;
      },
      onSaved: (value) => _formData.amount = double.tryParse(value!),
      decoration: const InputDecoration(
        labelText: 'Amount',
        prefixIcon: Icon(Icons.currency_rupee_rounded, size: 18),
        prefixIconConstraints: BoxConstraints(minWidth: 44, minHeight: 0),
      ),
    );
  }

  Widget _buildCategorySection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            icon: Icons.category_rounded,
            title: 'Category',
            subtitle: 'Pick the type of income or expense',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
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
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.3),
            width: 1.4,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 14,
              color: selected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCategorySection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(
            icon: Icons.list_alt_rounded,
            title: 'Sub Category',
            subtitle: 'Choose the exact item',
          ),
          const SizedBox(height: 14),
          _buildSubCategoryGrid(),
        ],
      ),
    );
  }

  Widget _buildSubCategoryGrid() {
    final color = _getCategoryColor(_formData.category!);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
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
              color: selected ? color : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? color : AppColors.border,
                width: 1.4,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    option,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
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
          const SectionTitle(
            icon: Icons.person_rounded,
            title: 'By / To',
            subtitle: 'Who is involved in this transaction',
          ),
          const SizedBox(height: 14),
          AppField(
            controller: _nameController,
            label: 'Name',
            icon: Icons.badge_rounded,
            hint: 'Name (optional, for search)',
            onSaved: (v) => _formData.name = v?.trim() ?? '',
          ),
          const SizedBox(height: 12),
          AppField(
            controller: _mobileController,
            label: 'By/To mobile',
            icon: Icons.phone_rounded,
            hint: 'Mobile (optional)',
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
            onChanged: _prefetchByMobile,
            onSaved: (v) => _formData.mobile = v?.trim() ?? '',
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
          const SectionTitle(
            icon: Icons.description_rounded,
            title: 'Narration (optional)',
            subtitle: 'Add a short note about this transaction',
          ),
          const SizedBox(height: 14),
          AppField(
            controller: _narrationController,
            label: 'Narration',
            icon: Icons.description_outlined,
            hint: 'Describe the transaction...',
            maxLines: 3,
            validator: (value) {
              if (value != null && value.length > 200) {
                return 'Max 200 characters';
              }
              return null;
            },
            onSaved: (value) => _formData.narration =
                (value == null || value.trim().isEmpty) ? null : value.trim(),
          ),
        ],
      ),
    );
  }

  Widget _buildViewAllButton() {
    return SecondaryButton(
      label: 'View All Transactions',
      icon: Icons.receipt_long_rounded,
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const IncomeExpenseListScreen()),
      ),
    );
  }

  Widget _buildOtherInfoButton() {
    return SecondaryButton(
      label: _hasOtherInfo
          ? 'Other Information (filled)'
          : 'Other Information (optional)',
      icon: _hasOtherInfo ? Icons.check_circle_rounded : Icons.info_outline_rounded,
      color: AppColors.info,
      onPressed: _showOtherInfoSheet,
    );
  }

  Widget _buildSubmitButton() {
    return PrimaryButton(
      label: 'Submit Transaction',
      icon: Icons.save_rounded,
      onPressed: isLoading ? null : _submitForm,
      loading: isLoading,
    );
  }
}
