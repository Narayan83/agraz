import 'package:flutter/material.dart';
import 'api_service.dart';
import 'app_theme.dart';
import 'l10n/app_l10n.dart';

/// Shows service registration as a modal bottom sheet. Returns true on success.
/// Sheet is non-dismissible by swipe/outside tap so typed data is not lost.
Future<bool?> showServiceRegisterSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final discard = await _confirmDiscardRegistration(ctx);
          if (discard == true && ctx.mounted) {
            Navigator.pop(ctx, false);
          }
        },
        child: DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.98,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ServiceRegisterForm(
                scrollController: scrollController,
                asSheet: true,
              ),
            );
          },
        ),
      );
    },
  );
}

Future<bool?> _confirmDiscardRegistration(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('Discard registration?')),
      content: Text(
        'Entered details will be lost if you close now.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(tr('Keep editing')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(tr('Discard')),
        ),
      ],
    ),
  );
}

class ServiceRegisterPage extends StatelessWidget {
  const ServiceRegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: ServiceRegisterForm(asSheet: false)),
    );
  }
}

class ServiceRegisterForm extends StatefulWidget {
  final ScrollController? scrollController;
  final bool asSheet;

  const ServiceRegisterForm({
    super.key,
    this.scrollController,
    this.asSheet = false,
  });

  @override
  State<ServiceRegisterForm> createState() => _ServiceRegisterFormState();
}

class _ServiceRegisterFormState extends State<ServiceRegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final mobileController = TextEditingController();
  final nameController = TextEditingController();
  final businessNameController = TextEditingController();
  final emailController = TextEditingController();
  final remarksController = TextEditingController();
  String? selectedMainCategory;
  String? selectedSubCategory;
  bool isLoading = false;

  final Map<String, List<String>> categories = {
    'Farming Services': [
      'Labour Supply',
      'Harvesting-Manual',
      'Harvesting-Doti',
      'Spraying-Manual',
      'Spraying-Doti',
      'Drone Services',
      'JCB/Hitachi',
      'Tractor',
      'Agri Input Suppliers',
      'Manure Suppliers',
      'Implement Suppliers',
      'Implement Renting',
      'Peeling Services',
      'Peeling Machine',
      'Weeder',
      'Grass/Weed Cutting',
      'Areca Sorting',
      'New Plantation Planning',
      'Irrigation Planning',
      'Drainage Planning',
      'Irrigation Service',
      'Drainage System Service',
      'Electricity Services',
      'Goods Vehicle Service',
      'Dry Leaf Suppliers',
      'Dry Grass Suppliers',
      'Labours',
      'Coconut Harvesting',
      'Coconut Peeling',
      'Soil Suppliers',
      'Soil Work Team',
      'Laterite Supplier',
      'Kaluve Builders',
      'Well Diggers',
      'Areca Pickers',
    ],
    'Animal Husbandry': [
      'Animal Feed',
      'Dry Fodder',
      'Silage',
      'Animal Medicine',
      'Cows and Buffalos',
      'Animal Treatment Ayurvedic',
      'Animal Treatment Allopathy',
      'Accessories',
      'Milking Machine',
      'Inseminators',
      'Doctors',
    ],
    'Passenger Vehicle': ['Car', 'Jeep', 'Tempo', 'Bus', 'Bike', 'Rickshaw'],
    'Goods Vehicle': ['Pick Up', 'Ace', 'Jeeto', 'Tractor', 'Lorry'],
    'JCB/Hitachi': ['JCB', 'Hitachi', 'Mini Hitachi'],
    'Medicine': ['Ayurvedic', 'Other Methods'],
    'Other Services': [
      'Electricians',
      'Plumbers',
      'Building Contractors',
      'Engineers',
      'Gavadi Work',
      'POP Work',
      'Solar Services',
      'Welders',
      'Interior Designers',
      'Painters',
      'Foundation Workers',
      'Movers and Packers',
      'Toilet Cleaning',
      'Other Works',
      'Tailoring',
      'Cement Works-Ring/Door Frame Window',
      'Banana Buyers',
      'Togaru/Other buyers',
      'Areca Buyers',
      'Coconut Buyers',
      'Raddi Buyers',
    ],
  };

  List<String> getMainCategories() => categories.keys.toList();

  List<String> getSubCategories() {
    if (selectedMainCategory == null ||
        !categories.containsKey(selectedMainCategory)) {
      return [];
    }
    return categories[selectedMainCategory]!;
  }

  Future<void> _fetchUserDetails(String mobile) async {
    try {
      final responseData = await _apiService.fetchUserByMobile(mobile);
      if (responseData != null &&
          responseData['data'] != null &&
          responseData['data'].isNotEmpty) {
        final transaction = responseData['data'][0];
        setState(() => nameController.text = transaction['name'] ?? '');
      }
    } catch (_) {}
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => isLoading = true);

    try {
      final result = await _apiService.submitServiceRegistration(
        mobileController.text,
        nameController.text,
        selectedMainCategory!,
        businessNameController.text,
        subCategory: selectedSubCategory,
        email: emailController.text.isNotEmpty ? emailController.text : null,
        remarks: remarksController.text.isNotEmpty
            ? remarksController.text
            : null,
      );

      setState(() => isLoading = false);

      if (result['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('Service registered successfully!')),
            backgroundColor: AppColors.income,
          ),
        );
        if (widget.asSheet) {
          Navigator.of(context).pop(true);
        } else {
          Navigator.of(context).pop();
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ?? 'Failed to register. Try again.',
            ),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unexpected error: $e'),
          backgroundColor: AppColors.expense,
        ),
      );
    }
  }

  @override
  void dispose() {
    mobileController.dispose();
    nameController.dispose();
    businessNameController.dispose();
    emailController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.asSheet) ...[
          SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(height: 4),
        ],
        AppHeader(
          icon: Icons.miscellaneous_services_rounded,
          title: tr('Register your Business or Service'),
          subtitle: tr('Fill in the details below'),
          showBack: !widget.asSheet,
          onBack: () => Navigator.pop(context),
          bottomRadius: widget.asSheet ? 0 : 24,
          trailing: widget.asSheet
              ? IconButton(
                  onPressed: () async {
                    final discard = await _confirmDiscardRegistration(context);
                    if (discard == true && context.mounted) {
                      Navigator.pop(context, false);
                    }
                  },
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                )
              : null,
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildContactCard(),
                  SizedBox(height: 14),
                  _buildCategoryCard(),
                  SizedBox(height: 14),
                  _buildDetailsCard(),
                  SizedBox(height: 14),
                  _buildEmailRemarksCard(),
                  SizedBox(height: 20),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: Icons.contact_phone_rounded,
            title: tr('Contact Info'),
            subtitle: tr('How can we reach you?'),
          ),
          SizedBox(height: 14),
          AppField(
            controller: nameController,
            label: 'Full Name',
            icon: Icons.person_rounded,
            required: true,
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          SizedBox(height: 12),
          AppField(
            controller: mobileController,
            label: 'Mobile Number',
            icon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
            required: true,
            validator: (v) => v!.isEmpty ? 'Required' : null,
            onChanged: (v) {
              if (v.length == 10) _fetchUserDetails(v);
            },
          ),
          SizedBox(height: 12),
          AppField(
            controller: emailController,
            label: 'Email Address',
            icon: Icons.email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v != null && v.isNotEmpty) {
                if (!v.contains('@')) return 'Enter a valid email';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: Icons.category_rounded,
            title: tr('Service Category'),
            subtitle: tr('Choose the best match'),
          ),
          SizedBox(height: 14),
          AppDropdown(
            label: 'Main Category',
            value: selectedMainCategory,
            items: getMainCategories(),
            icon: Icons.folder_rounded,
            required: true,
            onChanged: (v) {
              setState(() {
                selectedMainCategory = v;
                selectedSubCategory = null;
              });
            },
          ),
          SizedBox(height: 12),
          AppDropdown(
            label: 'Sub Category',
            value: selectedSubCategory,
            items: getSubCategories(),
            icon: Icons.subdirectory_arrow_right_rounded,
            required: true,
            onChanged: (v) => setState(() => selectedSubCategory = v),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: Icons.business_rounded,
            title: tr('Business Name'),
            subtitle: tr('Name shown to farmers'),
          ),
          SizedBox(height: 14),
          AppField(
            controller: businessNameController,
            label: 'Business Name',
            icon: Icons.store_rounded,
            required: true,
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildEmailRemarksCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            icon: Icons.notes_rounded,
            title: tr('Remarks'),
            subtitle: tr('Anything else we should know?'),
          ),
          SizedBox(height: 14),
          AppField(
            controller: remarksController,
            label: 'Remarks',
            icon: Icons.notes_rounded,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return PrimaryButton(
      label: isLoading ? 'Registering…' : 'Register Service',
      icon: Icons.check_circle_outline_rounded,
      onPressed: isLoading ? null : _submitForm,
      loading: isLoading,
    );
  }
}
