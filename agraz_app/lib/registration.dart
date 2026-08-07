import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'terms.dart';
import 'config.dart';
import 'app_theme.dart';

/// Shows the create-account form as a modal bottom sheet. Returns true on success.
Future<bool?> showRegistrationSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.98,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: RegistrationPage(
              scrollController: scrollController,
              asSheet: true,
            ),
          );
        },
      );
    },
  );
}

class RegistrationPage extends StatefulWidget {
  final ScrollController? scrollController;
  final bool asSheet;

  const RegistrationPage({
    super.key,
    this.scrollController,
    this.asSheet = false,
  });

  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstnameController = TextEditingController();
  final TextEditingController _lastnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _contactNoController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _termsAccepted = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  DateTime? _selectedDate;
  String? _fullPhoneNumber;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _firstnameController.dispose();
    _lastnameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _contactNoController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  void _navigateToTermsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TermsAndConditionsPage()),
    );
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept terms and conditions')),
      );
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final payload = {
        'firstname': _firstnameController.text.trim(),
        'lastname': _lastnameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _fullPhoneNumber?.replaceAll(RegExp(r'[^0-9]'), '') ?? '',
        'password': _passwordController.text,
        'confirmPassword': _confirmPasswordController.text,
      };

      final regHeaders = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      mergeTenantHeaders(regHeaders);
      final response = await http.post(
        Uri.parse('$BASE_URL/api/mobile/register'),
        headers: regHeaders,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        if (!mounted) return;
        final msg = responseData['message']?.toString() ??
            'Registration successful. You are in cooling period. Please wait for approval.';
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Registration successful'),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (widget.asSheet) {
          Navigator.of(context).pop(true);
        } else {
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        final responseData =
            jsonDecode(response.body) as Map<String, dynamic>? ?? {};
        String errorMessage = 'Registration failed: ';
        if (responseData['error'] != null) {
          errorMessage += responseData['error'].toString();
        } else if (responseData['details'] != null) {
          errorMessage += responseData['details'].toString();
        } else if (responseData['message'] != null) {
          errorMessage += responseData['message'].toString();
        } else {
          errorMessage += response.body;
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            if (widget.asSheet) ...[
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
            ],
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.headerGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(widget.asSheet ? 0 : 24),
                ),
              ),
              child: Row(
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: widget.asSheet
                          ? () => Navigator.pop(context, false)
                          : () => Navigator.of(context).pop(),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          widget.asSheet
                              ? Icons.close_rounded
                              : Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Account',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Join AgRaz today',
                          style: TextStyle(color: Colors.white70, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Form(
                      key: _formKey,
                      child: AppCard(
                        padding: const EdgeInsets.all(18),
                        radius: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _firstnameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'First Name',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'First name is required'
                                      : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _lastnameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Last Name',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'Last name is required'
                                      : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter a valid email address';
                                }
                                if (!value.contains('@')) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildDatePicker(),
                            const SizedBox(height: 12),
                            IntlPhoneField(
                              controller: _contactNoController,
                              disableLengthCheck: true,
                              initialCountryCode: 'IN',
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                counterText: '',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                              onChanged: (phone) {
                                setState(
                                  () => _fullPhoneNumber = phone.completeNumber,
                                );
                              },
                              validator: (phone) {
                                if (phone == null ||
                                    phone.completeNumber.isEmpty) {
                                  return 'Phone number is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildPasswordField(
                              _passwordController,
                              'Password',
                              'Password is required',
                              _obscurePassword,
                              () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildPasswordField(
                              _confirmPasswordController,
                              'Confirm Password',
                              'Confirm password is required',
                              _obscureConfirmPassword,
                              () => setState(
                                () =>
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword,
                              ),
                              confirmPassword: true,
                            ),
                            const SizedBox(height: 16),
                            _buildTermsCheckbox(),
                            const SizedBox(height: 20),
                            PrimaryButton(
                              label: 'Create Account',
                              icon: Icons.person_add_alt_1_rounded,
                              onPressed: _isLoading ? null : _registerUser,
                              loading: _isLoading,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Already have an account? ",
                                  style: AppText.small,
                                ),
                                GestureDetector(
                                  onTap: () {
                                    if (widget.asSheet) {
                                      Navigator.of(context).pop(false);
                                    } else {
                                      Navigator.pushNamed(context, "/login");
                                    }
                                  },
                                  child: const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    TextEditingController controller,
    String label,
    String validationMessage,
    bool obscureText,
    VoidCallback onToggle, {
    bool confirmPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return validationMessage;
        if (confirmPassword && value != _passwordController.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }

  Widget _buildDatePicker() {
    return TextFormField(
      controller: _dobController,
      readOnly: true,
      onTap: () async {
        DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: _selectedDate ?? DateTime(2000),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (pickedDate != null) {
          setState(() {
            _selectedDate = pickedDate;
            _dobController.text = _formatDate(pickedDate);
          });
        }
      },
      decoration: const InputDecoration(
        labelText: 'Date of Birth',
        prefixIcon: Icon(Icons.calendar_month_rounded),
      ),
      validator: (value) =>
          value == null || value.isEmpty ? 'Date of birth is required' : null,
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 22,
          width: 22,
          child: Checkbox(
            value: _termsAccepted,
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            onChanged: (value) =>
                setState(() => _termsAccepted = value ?? false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: _navigateToTermsPage,
            child: RichText(
              text: TextSpan(
                text: 'I accept the ',
                style: AppText.small,
                children: [
                  TextSpan(
                    text: 'Terms of Use & Privacy Policy',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer:
                        TapGestureRecognizer()..onTap = _navigateToTermsPage,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
