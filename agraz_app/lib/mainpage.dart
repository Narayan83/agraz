import 'package:flutter/material.dart';
import 'dart:async';
import 'profile_page.dart';
import 'settings_page.dart';
import 'about_page.dart';
import 'income_expense.dart';
import 'services.dart';
import 'labour.dart';
import 'marke_report.dart';
import 'buy_and_sell.dart';
import 'farmer_education.dart';
import 'government_facilities.dart';
import 'auth_token.dart';
import 'login.dart';
import 'welcome_screen.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _ServiceFeature {
  final IconData icon;
  final String title;
  final String description;
  final List<String> details;

  const _ServiceFeature({
    required this.icon,
    required this.title,
    required this.description,
    required this.details,
  });
}

class _MainPageState extends State<MainPage> {
  bool _isLoggedIn = false;

  final List<String> _sliderImages = [
    'assets/images/areca.jpg',
    'assets/images/banana.jpeg',
    'assets/images/pepper.jpg',
    'assets/images/coffee.jpeg',
    'assets/images/bhatta.jpeg',
  ];

  late PageController _pageController;
  late Timer _autoSlideTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _refreshAuthState();
    _currentPage = 0;
    _pageController = PageController(viewportFraction: 1.0);
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _currentPage++;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoSlideTimer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _refreshAuthState() async {
    final token = await getAuthToken();
    if (!mounted) return;
    setState(() => _isLoggedIn = token != null);
  }

  /// Opens [page] if logged in; otherwise shows login, then opens [page] on success.
  Future<void> _openProtected(Widget page, {bool closeDrawer = false}) async {
    if (closeDrawer) Navigator.pop(context);

    final token = await getAuthToken();
    if (token != null) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => page),
      );
      return;
    }

    if (!mounted) return;
    final loggedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
    if (loggedIn == true && mounted) {
      await _refreshAuthState();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => page),
      );
    }
  }

  Future<void> _goToLogin() async {
    final loggedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
    if (loggedIn == true && mounted) {
      await _refreshAuthState();
      if (!mounted) return;
      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const WelcomeScreen(),
          transitionsBuilder:
              (_, anim, _, child) =>
                  FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "AgRaz",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutTeamPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openProtected(const SettingsPage()),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.white),
              child: Center(
                child: Image.asset(
                  'assets/images/menulogo.jpeg',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            ListTile(
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.home_filled,
                  color: Color(0xFF2E7D32),
                  size: 20,
                ),
              ),
              title: const Text('Home'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.account_balance_wallet,
                color: Colors.orange,
              ),
              title: const Text('Income and Expense'),
              onTap:
                  () => _openProtected(
                    const IncomeExpensePage(),
                    closeDrawer: true,
                  ),
            ),
            ListTile(
              leading: const Icon(Icons.engineering, color: Colors.blueGrey),
              title: const Text('Labour Management'),
              onTap:
                  () => _openProtected(
                    const LaborManagementPage(),
                    closeDrawer: true,
                  ),
            ),
            ListTile(
              leading: const Icon(Icons.trending_up, color: Colors.purple),
              title: const Text('Market Reports'),
              onTap:
                  () => _openProtected(
                    const RatesComparisonPage(),
                    closeDrawer: true,
                  ),
            ),
            ListTile(
              leading: const Icon(Icons.store, color: Colors.teal),
              title: const Text('Buy and Sell'),
              onTap:
                  () => _openProtected(const BuySellApp(), closeDrawer: true),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book, color: Colors.indigo),
              title: const Text('Farmer Education'),
              onTap:
                  () => _openProtected(
                    const FarmerEducationPage(),
                    closeDrawer: true,
                  ),
            ),
            ListTile(
              leading: const Icon(
                Icons.account_balance,
                color: Colors.deepOrange,
              ),
              title: const Text('Government Facilities'),
              onTap:
                  () => _openProtected(
                    const GovernmentFacilitiesPage(),
                    closeDrawer: true,
                  ),
            ),
            ListTile(
              leading: const Icon(
                Icons.miscellaneous_services,
                color: Colors.brown,
              ),
              title: const Text('General Services'),
              onTap:
                  () => _openProtected(
                    const ServiceListingPage(),
                    closeDrawer: true,
                  ),
            ),
            ListTile(
              leading: const Icon(Icons.account_circle, color: Colors.blue),
              title: const Text('Profile'),
              onTap:
                  () => _openProtected(const ProfilePage(), closeDrawer: true),
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.grey),
              title: const Text('Settings'),
              onTap:
                  () => _openProtected(const SettingsPage(), closeDrawer: true),
            ),
            ListTile(
              leading: const Icon(Icons.groups, color: Colors.cyan),
              title: const Text('About Team'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AboutTeamPage(),
                  ),
                );
              },
            ),
            if (_isLoggedIn) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showLogoutConfirmationDialog(context);
                },
              ),
            ] else ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.login, color: Colors.green),
                title: const Text(
                  'Login',
                  style: TextStyle(color: Colors.green),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _goToLogin();
                },
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showHelpCenter(context),
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 4,
        child: const Icon(Icons.help, color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Hero Section (Image Slider) ---
            SizedBox(
              height: 260,
              width: double.infinity,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: null,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final imageIndex = index % _sliderImages.length;
                      return Image.asset(
                        _sliderImages[imageIndex],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 260,
                      );
                    },
                  ),
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_sliderImages.length, (i) {
                        final isActive =
                            _currentPage % _sliderImages.length == i;
                        return GestureDetector(
                          onTap: () {
                            int target =
                                (_currentPage ~/ _sliderImages.length) *
                                    _sliderImages.length +
                                i;
                            if (target < _currentPage)
                              target += _sliderImages.length;
                            _pageController.animateToPage(
                              target,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: isActive ? 18 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color:
                                  isActive
                                      ? const Color(0xFF2E7D32)
                                      : Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- What is AgRaz? ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE8F5E9), Color(0xFFF1F8E9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFC8E6C9),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.agriculture,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'What is AgRaz?',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'AgRaz is a smart Agriculture ERP platform built for modern farmers and agribusinesses. '
                          'Whether you\'re managing a small farm or large-scale operations, AgRaz helps you digitize, '
                          'simplify, and grow your agricultural journey.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF33691E),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: SizedBox(
                            width: 200,
                            child: ElevatedButton.icon(
                              onPressed: _isLoggedIn ? null : _goToLogin,
                              icon: const Icon(Icons.login),
                              label: const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // --- Services ---
                  _buildSectionHeader('Our Services for Farmers'),
                  const SizedBox(height: 16),
                  _buildServicesGrid(),
                  const SizedBox(height: 32),
                  // --- Why Choose AgRaz? ---
                  _buildSectionHeader('Why Choose AgRaz?'),
                  const SizedBox(height: 16),
                  _buildWhyChooseCard(
                    icon: Icons.auto_awesome,
                    text: 'AI-driven insights tailored to your farm',
                    color: const Color(0xFF7B1FA2),
                  ),
                  _buildWhyChooseCard(
                    icon: Icons.wifi_off,
                    text: 'Works offline & syncs automatically',
                    color: const Color(0xFF1565C0),
                  ),
                  _buildWhyChooseCard(
                    icon: Icons.language,
                    text: 'Available in local languages',
                    color: const Color(0xFFE65100),
                  ),
                  _buildWhyChooseCard(
                    icon: Icons.verified,
                    text: 'Backed by agriculture experts',
                    color: const Color(0xFF2E7D32),
                  ),
                  _buildWhyChooseCard(
                    icon: Icons.shield,
                    text: 'Secure and farmer-first design',
                    color: const Color(0xFFC62828),
                  ),
                  const SizedBox(height: 32),
                  // --- Let AgRaz Work For You ---
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1B5E20).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.phone_android,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Let AgRaz Work For You',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'AgRaz empowers farmers with the right tools to:',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildBenefitRow('Make informed decisions'),
                        _buildBenefitRow('Maximize profits'),
                        _buildBenefitRow('Reduce risks'),
                        _buildBenefitRow(
                          'Access real-time support and services',
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '"Start your journey with AgRaz today – where technology meets tradition"',
                              style: TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: Colors.white70,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _performLogout();
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout() async {
    await clearAuthToken();
    if (!mounted) return;
    setState(() => _isLoggedIn = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Logged out successfully')));
  }

  void _showHelpCenter(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.help_center,
                      color: Color(0xFF2E7D32),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Help Center',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'How can we help you?',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 20),
                  _buildHelpItem(
                    Icons.article,
                    'Getting Started',
                    'Learn how to use AgRaz',
                    const Color(0xFF1565C0),
                  ),
                  const SizedBox(height: 8),
                  _buildHelpItem(
                    Icons.contact_support,
                    'Contact Support',
                    'Reach out to our team',
                    const Color(0xFFE65100),
                  ),
                  const SizedBox(height: 8),
                  _buildHelpItem(
                    Icons.quiz,
                    'FAQ',
                    'Frequently asked questions',
                    const Color(0xFF7B1FA2),
                  ),
                  const SizedBox(height: 8),
                  _buildHelpItem(
                    Icons.feedback,
                    'Send Feedback',
                    'Help us improve',
                    const Color(0xFF2E7D32),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8F5E9),
                        foregroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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

  Widget _buildHelpItem(
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showServiceDetailModal(BuildContext context, _ServiceFeature service) {
    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      service.icon,
                      color: const Color(0xFF2E7D32),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    service.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    service.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Key Features',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...service.details.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Color(0xFF2E7D32),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              d,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF33691E),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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

  Widget _buildServicesGrid() {
    const services = [
      _ServiceFeature(
        icon: Icons.assignment,
        title: 'Track Expenses',
        description:
            'Stay in control of your farm spending with easy logging of crop-wise, daily, and seasonal expenses.',
        details: [
          'Record expenses by crop and season',
          'Categorize spending automatically',
          'Generate monthly expense reports',
          'Set budget alerts and notifications',
        ],
      ),
      _ServiceFeature(
        icon: Icons.trending_up,
        title: 'Forecast & Predict',
        description:
            'Get AI-powered predictions on crop yield and productivity based on historical patterns, weather, and inputs.',
        details: [
          'AI-driven yield predictions',
          'Weather pattern analysis',
          'Historical data comparison',
          'Real-time productivity tracking',
        ],
      ),
      _ServiceFeature(
        icon: Icons.shopping_basket,
        title: 'Buy & Sell',
        description:
            'Trade seeds, fertilizers, pesticides, and harvested crops with trusted vendors and buyers right from your phone.',
        details: [
          'Verified vendors and buyers',
          'Secure payment gateway',
          'Real-time market prices',
          'Direct farm-to-market selling',
        ],
      ),
      _ServiceFeature(
        icon: Icons.attach_money,
        title: 'Price Optimization',
        description:
            'Use smart tools to identify the best market prices and optimize your selling strategies.',
        details: [
          'Compare prices across markets',
          'Price trend analysis',
          'Smart selling recommendations',
          'Minimum support price alerts',
        ],
      ),
      _ServiceFeature(
        icon: Icons.account_balance,
        title: 'Banking & Finance',
        description:
            'Get access to agricultural loans, credit tools, insurance services, and government schemes.',
        details: [
          'Easy loan applications',
          'Crop insurance management',
          'Government scheme tracking',
          'Credit score monitoring',
        ],
      ),
      _ServiceFeature(
        icon: Icons.dashboard,
        title: 'Farm Analytics',
        description: 'See all your key data in one simple, visual dashboard.',
        details: [
          'Visual data representations',
          'Customizable dashboard views',
          'Real-time data updates',
          'Export reports for analysis',
        ],
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return GestureDetector(
          onTap: () {
            if (service.title == 'Banking & Finance Solutions') {
              _openProtected(const GovernmentFacilitiesPage());
              return;
            }
            _showServiceDetailModal(context, service);
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  const Color(0xFFF1F8E9).withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      service.icon,
                      size: 28,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    service.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    service.description.length > 60
                        ? '${service.description.substring(0, 60)}...'
                        : service.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWhyChooseCard({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: color,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 3),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white70,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
      ],
    );
  }
}
