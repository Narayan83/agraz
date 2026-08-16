import 'package:flutter/material.dart';
import 'dart:async';
import 'profile_page.dart';
import 'settings_page.dart';
import 'about_page.dart';
import 'income_expense.dart';
import 'manage_organization.dart';
import 'services.dart';
import 'labour.dart';
import 'diary.dart';
import 'future_plans.dart';
import 'labour_work.dart';
import 'marke_report.dart';
import 'buy_and_sell.dart';
import 'farmer_education.dart';
import 'government_facilities.dart';
import 'weather_report.dart';
import 'rtc_entry.dart';
import 'auth_token.dart';
import 'login.dart';
import 'welcome_screen.dart';
import 'app_theme.dart';
import 'feedback_fab.dart';
import 'feedback_page.dart';
import 'l10n/app_l10n.dart';
import 'l10n/locale_controller.dart';
import 'app_update.dart';

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

  _ServiceFeature({
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) promptInAppUpdateIfNeeded(context);
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

  /// Opens [page] without requiring login (modules remain visible to guests).
  Future<void> _openModule(Widget page, {bool closeDrawer = false}) async {
    if (closeDrawer) Navigator.pop(context);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
    if (mounted) await _refreshAuthState();
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
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) => Scaffold(
      appBar: GradientAppBar(
        title: "AgRaz",
        actions: withFeedbackAction(
          context,
          menu: 'home',
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              tooltip: tr('About Team'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutTeamPage()),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              tooltip: tr('Settings'),
              onPressed: () => _openProtected(const SettingsPage()),
            ),
          ],
        ),
      ),
      drawer: _buildDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showHelpCenter(context),
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.help_rounded, color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Hero Section (Image Slider) ---
            _buildHero(),
            _buildQuickShortcuts(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16),
                  // --- What is AgRaz? ---
                  _buildAboutCard(),
                  SizedBox(height: 28),
                  // --- Services ---
                  _buildSectionHeader('Our Services for Farmers'),
                  SizedBox(height: 14),
                  _buildServicesGrid(),
                  SizedBox(height: 28),
                  // --- Why Choose AgRaz? ---
                  _buildSectionHeader('Why Choose AgRaz?'),
                  SizedBox(height: 14),
                  _buildWhyChooseCard(
                    icon: Icons.auto_awesome_rounded,
                    text: tr('AI-driven insights tailored to your farm'),
                    color: AppColors.accent,
                    index: '01',
                  ),
                  _buildWhyChooseCard(
                    icon: Icons.wifi_off_rounded,
                    text: tr('Works offline & syncs automatically'),
                    color: AppColors.info,
                    index: '02',
                  ),
                  _buildWhyChooseCard(
                    icon: Icons.language_rounded,
                    text: tr('Available in local languages'),
                    color: AppColors.warning,
                    index: '03',
                  ),
                  _buildWhyChooseCard(
                    icon: Icons.verified_rounded,
                    text: tr('Backed by agriculture experts'),
                    color: AppColors.primary,
                    index: '04',
                  ),
                  _buildWhyChooseCard(
                    icon: Icons.shield_rounded,
                    text: tr('Secure and farmer-first design'),
                    color: AppColors.expense,
                    index: '05',
                  ),
                  SizedBox(height: 28),
                  // --- Let AgRaz Work For You ---
                  _buildCtaCard(),
                  SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  /* ------------------------------------------------------------------ */
  /*  Drawer / Sidebar                                                  */
  /* ------------------------------------------------------------------ */

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.background,
      width: 308,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          children: [
            _buildDrawerHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  _drawerSectionLabel(tr('MENU')),
                  _drawerTile(
                    Icons.home_filled,
                    tr('Home'),
                    AppColors.primary,
                    () => Navigator.pop(context),
                    active: true,
                  ),
                  _drawerTile(
                    Icons.account_balance_wallet_rounded,
                    tr('Income & Expense'),
                    AppColors.income,
                    () => _openModule(
                      const IncomeExpensePage(),
                      closeDrawer: true,
                    ),
                  ),
                  _drawerTile(
                    Icons.business_rounded,
                    tr('Manage Organization'),
                    AppColors.primaryLight,
                    () => _openModule(
                      const ManageOrganizationPage(),
                      closeDrawer: true,
                    ),
                  ),
                  _drawerTile(
                    Icons.engineering_rounded,
                    tr('Labour Management'),
                    AppColors.warning,
                    () => _openModule(
                      const LaborManagementPage(),
                      closeDrawer: true,
                    ),
                  ),
                  _drawerTile(
                    Icons.handshake_rounded,
                    tr('Labour Work Entry'),
                    AppColors.primaryLight,
                    () => _openProtected(
                      const LabourWorkPage(),
                      closeDrawer: true,
                    ),
                  ),
                  _drawerTile(
                    Icons.menu_book_outlined,
                    tr('Diary'),
                    AppColors.accent,
                    () => _openProtected(const DiaryPage(), closeDrawer: true),
                  ),
                  _drawerTile(
                    Icons.flag_outlined,
                    tr('Future Plans'),
                    AppColors.info,
                    () => _openProtected(
                      const FuturePlansPage(),
                      closeDrawer: true,
                    ),
                  ),
                  _drawerTile(
                    Icons.trending_up_rounded,
                    tr('Market Reports'),
                    AppColors.info,
                    () => _openModule(
                      const RatesComparisonPage(),
                      closeDrawer: true,
                    ),
                  ),
                  _drawerTile(
                    Icons.cloud_outlined,
                    tr('Weather Report'),
                    AppColors.info,
                    () => _openModule(
                      const WeatherReportPage(),
                      closeDrawer: true,
                    ),
                  ),
                  _drawerTile(
                    Icons.miscellaneous_services_rounded,
                    tr('General Services'),
                    AppColors.expense,
                    () => _openModule(
                      const ServiceListingPage(),
                      closeDrawer: true,
                    ),
                  ),
                  _drawerTile(
                    Icons.store_rounded,
                    tr('Buy & Sell'),
                    AppColors.primaryLight,
                    () => _openModule(const BuySellApp(), closeDrawer: true),
                  ),
                  _drawerTile(
                    Icons.menu_book_rounded,
                    tr('Farmer Education'),
                    AppColors.accent,
                    () => _openModule(
                      const FarmerEducationPage(),
                      closeDrawer: true,
                    ),
                  ),
                  _drawerTile(
                    Icons.account_balance_rounded,
                    tr('Government Facilities'),
                    AppColors.info,
                    () => _openModule(
                      const GovernmentFacilitiesPage(),
                      closeDrawer: true,
                    ),
                  ),
                  _drawerTile(
                    Icons.map_outlined,
                    tr('RTC Entry'),
                    AppColors.primaryDark,
                    () => _openProtected(
                      const RtcEntryPage(),
                      closeDrawer: true,
                    ),
                  ),
                  _drawerTile(
                    Icons.feedback_outlined,
                    tr('Feedback'),
                    AppColors.accent,
                    () => _openModule(
                      const FeedbackPage(initialMenu: 'home'),
                      closeDrawer: true,
                    ),
                  ),
                  _drawerSectionLabel(tr('ACCOUNT')),
                  _drawerTile(
                    Icons.person_rounded,
                    tr('Profile'),
                    AppColors.info,
                    () => _openProtected(const ProfilePage(), closeDrawer: true),
                  ),
                  _drawerTile(
                    Icons.settings_rounded,
                    tr('Settings'),
                    AppColors.textSecondary,
                    () => _openProtected(
                      const SettingsPage(),
                      closeDrawer: true,
                    ),
                  ),
                  _drawerTile(
                    Icons.groups_rounded,
                    tr('About Team'),
                    AppColors.primaryLight,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AboutTeamPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            _buildDrawerFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.headerGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Image.asset(
              'assets/images/logo.jpeg',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AgRaz',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Smart Agriculture ERP',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 6),
      child: Text(label, style: AppText.caption),
    );
  }

  Widget _drawerTile(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap, {
    bool active = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: active ? color.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                TintedIcon(
                  icon: icon,
                  color: color,
                  boxSize: 36,
                  size: 18,
                  radius: 10,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? color : AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: _isLoggedIn
          ? _buildLogoutButton()
          : _buildLoginButton(),
    );
  }

  Widget _buildLoginButton() {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pop(context);
          _goToLogin();
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF3FA97E), AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.login_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Sign in to your account',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Material(
      color: AppColors.expenseSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pop(context);
          _showLogoutConfirmationDialog(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF88B83), AppColors.expense],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.expense.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.expense,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Sign out of your account',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.expense,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* ------------------------------------------------------------------ */
  /*  Home sections                                                     */
  /* ------------------------------------------------------------------ */

  Widget _buildQuickShortcuts() {
    final items = <({IconData icon, String label, Color color, VoidCallback open})>[
      (
        icon: Icons.account_balance_wallet_rounded,
        label: tr('Income & Expense'),
        color: AppColors.income,
        open: () => _openModule(const IncomeExpensePage()),
      ),
      (
        icon: Icons.business_rounded,
        label: tr('Organizations'),
        color: AppColors.primaryLight,
        open: () => _openModule(const ManageOrganizationPage()),
      ),
      (
        icon: Icons.engineering_rounded,
        label: tr('Labour'),
        color: AppColors.warning,
        open: () => _openModule(const LaborManagementPage()),
      ),
      (
        icon: Icons.handshake_rounded,
        label: tr('Work Entry'),
        color: AppColors.primaryLight,
        open: () => _openProtected(const LabourWorkPage()),
      ),
      (
        icon: Icons.menu_book_outlined,
        label: tr('Diary'),
        color: AppColors.accent,
        open: () => _openProtected(const DiaryPage()),
      ),
      (
        icon: Icons.flag_outlined,
        label: tr('Plans'),
        color: AppColors.info,
        open: () => _openProtected(const FuturePlansPage()),
      ),
      (
        icon: Icons.trending_up_rounded,
        label: tr('Market'),
        color: AppColors.info,
        open: () => _openModule(const RatesComparisonPage()),
      ),
      (
        icon: Icons.cloud_outlined,
        label: tr('Weather'),
        color: AppColors.info,
        open: () => _openModule(const WeatherReportPage()),
      ),
      (
        icon: Icons.miscellaneous_services_rounded,
        label: tr('Services'),
        color: AppColors.expense,
        open: () => _openModule(const ServiceListingPage()),
      ),
      (
        icon: Icons.store_rounded,
        label: tr('Buy & Sell'),
        color: AppColors.primaryLight,
        open: () => _openModule(const BuySellApp()),
      ),
      (
        icon: Icons.menu_book_rounded,
        label: tr('Education'),
        color: AppColors.accent,
        open: () => _openModule(const FarmerEducationPage()),
      ),
      (
        icon: Icons.account_balance_rounded,
        label: tr('Govt'),
        color: AppColors.info,
        open: () => _openModule(const GovernmentFacilitiesPage()),
      ),
      (
        icon: Icons.map_outlined,
        label: tr('RTC'),
        color: AppColors.primaryDark,
        open: () => _openProtected(const RtcEntryPage()),
      ),
      (
        icon: Icons.feedback_outlined,
        label: tr('Feedback'),
        color: AppColors.primary,
        open: () => _openModule(const FeedbackPage(initialMenu: 'home')),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
      child: SizedBox(
        height: 86,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final item = items[i];
            return InkWell(
              onTap: item.open,
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 72,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(item.icon, color: item.color, size: 24),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero() {
    return SizedBox(
      height: 280,
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
                height: 280,
              );
            },
          ),
          // Gradient scrim for readability
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.08),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.68),
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
            ),
          ),
          // Caption
          Positioned(
            left: 20,
            right: 20,
            bottom: 38,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'AGRICULTURE ERP',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                      color: Color(0xFF3D2A06),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Smart Farming,\nSimplified.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
          // Dots
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_sliderImages.length, (i) {
                final isActive = _currentPage % _sliderImages.length == i;
                return GestureDetector(
                  onTap: () {
                    int target =
                        (_currentPage ~/ _sliderImages.length) *
                            _sliderImages.length +
                        i;
                    if (target < _currentPage) {
                      target += _sliderImages.length;
                    }
                    _pageController.animateToPage(
                      target,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.accent
                          : Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TintedIcon(
                icon: Icons.agriculture_rounded,
                color: AppColors.primary,
                boxSize: 46,
                size: 24,
                radius: 14,
              ),
              SizedBox(width: 12),
              Expanded(child: Text(tr('What is AgRaz?'), style: AppText.h3)),
            ],
          ),
          SizedBox(height: 14),
          Text(
            tr(
              'AgRaz is a smart Agriculture ERP platform built for modern farmers and agribusinesses. Whether you\'re managing a small farm or large-scale operations, AgRaz helps you digitize, simplify, and grow your agricultural journey.',
            ),
            style: AppText.body.copyWith(height: 1.55),
          ),
          SizedBox(height: 16),
          if (_isLoggedIn)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.incomeSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.income,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr('You\'re logged in — explore all features'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.income,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            PrimaryButton(
              label: tr('Login to Get Started'),
              icon: Icons.login_rounded,
              onPressed: _goToLogin,
              height: 48,
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
          height: 26,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            tr(title),
            style: AppText.h3.copyWith(height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _buildServicesGrid() {
    final services = [
      _ServiceFeature(
        icon: Icons.assignment_rounded,
        title: tr('Track Expenses'),
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
        icon: Icons.trending_up_rounded,
        title: tr('Forecast & Predict'),
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
        icon: Icons.shopping_basket_rounded,
        title: tr('Buy & Sell'),
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
        icon: Icons.attach_money_rounded,
        title: tr('Price Optimization'),
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
        icon: Icons.account_balance_rounded,
        title: tr('Banking & Finance'),
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
        icon: Icons.dashboard_customize_rounded,
        title: tr('Farm Analytics'),
        description: 'See all your key data in one simple, visual dashboard.',
        details: [
          'Visual data representations',
          'Customizable dashboard views',
          'Real-time data updates',
          'Export reports for analysis',
        ],
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < services.length; i += 2) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildServiceCard(services[i])),
                SizedBox(width: 12),
                if (i + 1 < services.length)
                  Expanded(child: _buildServiceCard(services[i + 1]))
                else
                  Expanded(child: SizedBox()),
              ],
            ),
          ),
          if (i + 2 < services.length) SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildServiceCard(_ServiceFeature service) {
    return AppCard(
      onTap: () => _showServiceDetailModal(context, service),
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TintedIcon(
                icon: service.icon,
                color: AppColors.primary,
                boxSize: 40,
                size: 20,
                radius: 12,
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_outward_rounded,
                color: AppColors.textMuted,
                size: 15,
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            service.title,
            style: AppText.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 5),
          Text(
            service.description.length > 72
                ? '${service.description.substring(0, 72)}…'
                : service.description,
            style: AppText.small,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                'Learn more',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 3),
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.primary,
                size: 13,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWhyChooseCard({
    required IconData icon,
    required String text,
    required Color color,
    required String index,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [AppColors.softShadow],
      ),
      child: Row(
        children: [
          TintedIcon(icon: icon, color: color, boxSize: 44, size: 22, radius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AppText.bodyStrong),
          ),
          Text(
            index,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color.withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 13),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCtaCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.ctaGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Let AgRaz Work For You',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Text(
            'AgRaz empowers farmers with the right tools to:',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          SizedBox(height: 12),
          _buildBenefitRow(Icons.insights_rounded, 'Make informed decisions'),
          _buildBenefitRow(Icons.trending_up_rounded, 'Maximize profits'),
          _buildBenefitRow(Icons.shield_outlined, 'Reduce risks'),
          _buildBenefitRow(
            Icons.support_agent_rounded,
            'Access real-time support & services',
          ),
          SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.format_quote_rounded, color: AppColors.accent, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '"Start your journey with AgRaz today – where technology meets tradition"',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoggedIn ? null : _goToLogin,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(_isLoggedIn ? tr('You\'re all set') : tr('Get Started')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDeep,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /* ------------------------------------------------------------------ */
  /*  Dialogs                                                           */
  /* ------------------------------------------------------------------ */

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(tr('Logout')),
          content: Text(tr('Are you sure you want to logout?')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(tr('Cancel')),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _performLogout();
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(tr('Logout')),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.expense,
                foregroundColor: Colors.white,
              ),
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
    ).showSnackBar(SnackBar(content: Text(tr('Logged out successfully'))));
  }

  void _showHelpCenter(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TintedIcon(
                    icon: Icons.help_center_rounded,
                    color: AppColors.primary,
                    boxSize: 64,
                    size: 32,
                    radius: 20,
                  ),
                  SizedBox(height: 14),
                  Text('Help Center', style: AppText.h3),
                  SizedBox(height: 4),
                  Text('How can we help you?', style: AppText.small),
                  SizedBox(height: 18),
                  _buildHelpItem(
                    Icons.article_rounded,
                    'Getting Started',
                    'Learn how to use AgRaz',
                    AppColors.info,
                  ),
                  SizedBox(height: 8),
                  _buildHelpItem(
                    Icons.contact_support_rounded,
                    'Contact Support',
                    'Reach out to our team',
                    AppColors.warning,
                  ),
                  SizedBox(height: 8),
                  _buildHelpItem(
                    Icons.quiz_rounded,
                    'FAQ',
                    'Frequently asked questions',
                    AppColors.accent,
                  ),
                  SizedBox(height: 8),
                  _buildHelpItem(
                    Icons.feedback_rounded,
                    'Send Feedback',
                    'Help us improve',
                    AppColors.primary,
                  ),
                  SizedBox(height: 18),
                  PrimaryButton(
                    label: 'Close',
                    icon: Icons.close_rounded,
                    onPressed: () => Navigator.pop(ctx),
                    height: 48,
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
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          TintedIcon(icon: icon, color: color, boxSize: 40, size: 20, radius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                SizedBox(height: 2),
                Text(subtitle, style: AppText.small),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
            size: 18,
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
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TintedIcon(
                    icon: service.icon,
                    color: AppColors.primary,
                    boxSize: 64,
                    size: 32,
                    radius: 20,
                  ),
                  SizedBox(height: 14),
                  Text(
                    service.title,
                    textAlign: TextAlign.center,
                    style: AppText.h3,
                  ),
                  SizedBox(height: 8),
                  Text(
                    service.description,
                    textAlign: TextAlign.center,
                    style: AppText.body,
                  ),
                  SizedBox(height: 18),
                  const Divider(),
                  SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SectionTitle(
                      icon: Icons.checklist_rounded,
                      title: tr('Key Features'),
                    ),
                  ),
                  SizedBox(height: 12),
                  ...service.details.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: AppColors.primary,
                              size: 14,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(child: Text(d, style: AppText.body)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Close',
                    icon: Icons.close_rounded,
                    onPressed: () => Navigator.pop(ctx),
                    height: 50,
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
