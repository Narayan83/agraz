import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_token.dart';
import 'config.dart';
import 'mainpage.dart';
import 'reset_password_page.dart';
import 'registration.dart';
import 'app_theme.dart';
import 'l10n/app_l10n.dart';

void main() {
  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: LoginScreen()));
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
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
      begin: Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final email = _usernameController.text.trim();
        final password = _passwordController.text;
        final url = Uri.parse('$BASE_URL/api/login');
        final headers = <String, String>{'Content-Type': 'application/json'};
        mergeTenantHeaders(headers);
        final response = await http.post(
          url,
          headers: headers,
          body: jsonEncode({
            "email": email,
            "password": password,
          }),
        );
        if (!mounted) return;

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final token = extractTokenFromLoginResponse(data);
          if (token != null) {
            await saveAuthToken(token);
            if (!mounted) return;
          }
          if (!mounted) return;
          if (token == null) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No JWT in login response — Buy & Sell and other APIs may return 401.',
                ),
              ),
            );
          }
          if (!mounted) return;
          if (Navigator.canPop(context)) {
            Navigator.pop(context, true);
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainPage()),
            );
          }
        } else {
          if (!mounted) return;
          String message = 'Login failed';
          try {
            final data = jsonDecode(response.body);
            if (data is Map) {
              message = (data['message'] ?? data['error'] ?? message).toString();
              if (data['code'] == 'cooling_period' ||
                  message.toLowerCase().contains('cooling')) {
                await showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(tr('Cooling period')),
                    content: Text(
                      tr('You are in cooling period. Please wait for approval. An admin will verify your account before you can sign in.'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(tr('OK')),
                      ),
                    ],
                  ),
                );
                return;
              }
            }
          } catch (_) {
            message = response.body;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      } catch (e) {
        if (!mounted) return;
        final raw = e.toString();
        String message = 'Login failed: $e';
        if (raw.contains('Failed host lookup') ||
            raw.contains('SocketException') ||
            raw.contains('Network is unreachable') ||
            raw.contains('Connection refused') ||
            raw.contains('Connection timed out')) {
          message =
              'No internet / DNS on this device.\n'
              'Open Chrome on the emulator and visit https://agrazllp.com\n'
              'If that fails: Cold Boot the AVD or start it with DNS 8.8.8.8';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.headerGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -70,
            right: -50,
            child: IgnorePointer(child: _glow(220)),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: IgnorePointer(child: _glow(200)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(26, 30, 26, 24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 40,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset(
                                  'assets/images/app_logo.png',
                                  width: 92,
                                  height: 92,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            SizedBox(height: 18),
                            Text('Welcome Back', style: AppText.h1),
                            SizedBox(height: 6),
                            Text(
                              'Sign in to continue farming smarter',
                              style: AppText.subtitle,
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 28),
                            TextFormField(
                              controller: _usernameController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: tr('Email'),
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'Enter your email'
                                      : null,
                            ),
                            SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: tr('Password'),
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                      ? 'Enter your password'
                                      : null,
                            ),
                            SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () =>
                                      setState(() => _rememberMe = !_rememberMe),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: Checkbox(
                                          value: _rememberMe,
                                          activeColor: AppColors.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          onChanged: (value) => setState(
                                            () => _rememberMe = value ?? false,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Remember Me', style: AppText.small),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const ResetPasswordPage(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 24),
                            PrimaryButton(
                              label: 'Sign In',
                              icon: Icons.login_rounded,
                              onPressed: _isLoading ? null : _handleLogin,
                              loading: _isLoading,
                            ),
                            SizedBox(height: 18),
                            Text.rich(
                              TextSpan(
                                text: "Don't have an account? ",
                                style: AppText.small,
                                children: [
                                  TextSpan(
                                    text: tr('Sign Up'),
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        showRegistrationSheet(context);
                                      },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.06),
      ),
    );
  }
}
