import 'package:flutter/material.dart';
import 'api_service.dart';

class ServiceRegisterPage extends StatefulWidget {
  const ServiceRegisterPage({super.key});

  @override
  _ServiceRegisterPageState createState() => _ServiceRegisterPageState();
}

class _ServiceRegisterPageState extends State<ServiceRegisterPage>
    with SingleTickerProviderStateMixin {
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

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

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
      'New Planation Planning',
      'Irrigation Planning',
      'Drianage Planning',
      'Irrigation Service',
      'Drianage System Service',
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
      'Animal Tratment Ayurvedic',
      'Animal Treatment Alophaty',
      'Accessories',
      'Milking Machine',
      'Insaminators',
      'Doctors',
    ],
    'Passanger Vehicle': ['Car', 'Jeep', 'Tempo', 'Bus', 'Bike', 'Rikshaw'],
    'Goods Vehicle': ['Pick Up', 'Ace', 'Jeeto', 'Tractor', 'Lorry'],
    'JCB/Hitachi': ['JCB', 'Hitachi', 'Mini Hitachi'],
    'Medicine': ['Ayurvedic', 'Other Methods'],
    'Other Services': [
      'Electricians',
      'Plmbers',
      'Building Contractors',
      'Engineers',
      'Gavadi Work',
      'POP workj',
      'Solar Seriveices',
      'Welders',
      'Inerior Designers',
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
        !categories.containsKey(selectedMainCategory)) return [];
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to fetch details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        remarks: remarksController.text.isNotEmpty ? remarksController.text : null,
      );

      setState(() => isLoading = false);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Service registered successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to register. Try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void initState() {
    super.initState();
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
    mobileController.dispose();
    nameController.dispose();
    businessNameController.dispose();
    emailController.dispose();
    remarksController.dispose();
    super.dispose();
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildContactCard(),
                        const SizedBox(height: 16),
                        _buildCategoryCard(),
                        const SizedBox(height: 16),
                        _buildDetailsCard(),
                        const SizedBox(height: 16),
                        _buildEmailRemarksCard(),
                        const SizedBox(height: 28),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF388E3C), Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.miscellaneous_services_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Service Registration',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Register your business or service',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B5E20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Contact Info', Icons.contact_phone_rounded),
          _buildTextField(
            controller: nameController,
            label: 'Full Name',
            icon: Icons.person_rounded,
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: mobileController,
            label: 'Mobile Number',
            icon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
            validator: (v) => v!.isEmpty ? 'Required' : null,
            onChanged: (v) {
              if (v.length == 10) _fetchUserDetails(v);
            },
          ),
          const SizedBox(height: 12),
          _buildTextField(
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
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Service Category', Icons.category_rounded),
          _buildDropdown(
            label: 'Main Category',
            value: selectedMainCategory,
            items: getMainCategories(),
            icon: Icons.folder_rounded,
            onChanged: (v) {
              setState(() {
                selectedMainCategory = v;
                selectedSubCategory = null;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            label: 'Sub Category',
            value: selectedSubCategory,
            items: getSubCategories(),
            icon: Icons.subdirectory_arrow_right_rounded,
            onChanged: (v) => setState(() => selectedSubCategory = v),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Business Details', Icons.business_rounded),
          _buildTextField(
            controller: businessNameController,
            label: 'Business / Service Name',
            icon: Icons.store_rounded,
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildEmailRemarksCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Remarks', Icons.notes_rounded),
          _buildTextField(
            controller: remarksController,
            label: 'Remarks',
            icon: Icons.notes_rounded,
            maxLines: 3,
            validator: null,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F5),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1B5E20)),
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        onChanged: onChanged,
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 0),
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          contentPadding: EdgeInsets.symmetric(vertical: maxLines > 1 ? 14 : 14),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F5),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonFormField<String>(
        value: value,
        validator: (v) => v == null ? 'Please select $label' : null,
        onChanged: onChanged,
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
          prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 0),
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1B5E20)),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF2E7D32)),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  Widget _buildSubmitButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
        );
      },
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              elevation: 0,
              disabledBackgroundColor: const Color(0xFFA5D6A7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 22),
                      SizedBox(width: 8),
                      Text('Register Service', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
