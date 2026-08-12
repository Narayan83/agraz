import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'app_theme.dart';
import 'auth_token.dart';
import 'l10n/app_l10n.dart';
import 'login.dart';

class FeedbackPage extends StatefulWidget {
  final String initialMenu;

  const FeedbackPage({super.key, this.initialMenu = ''});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _menuCtrl = TextEditingController();

  late TabController _tabs;
  bool _submitting = false;
  bool _loadingMine = true;
  bool _loadingAll = true;
  String? _errorMine;
  String? _errorAll;
  List<Map<String, dynamic>> _mine = [];
  List<Map<String, dynamic>> _all = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    if (widget.initialMenu.isNotEmpty) {
      _menuCtrl.text = widget.initialMenu;
    }
    _loadLists();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    _menuCtrl.dispose();
    super.dispose();
  }

  Future<bool> _ensureLogin() async {
    var token = await getAuthToken();
    if (token != null && token.isNotEmpty) return true;
    if (!mounted) return false;
    final loggedIn = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (loggedIn != true) return false;
    token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> _loadLists() async {
    await Future.wait([_loadMine(), _loadAll()]);
  }

  Future<void> _loadMine() async {
    setState(() {
      _loadingMine = true;
      _errorMine = null;
    });
    try {
      final rows = await _api.fetchMyFeedbacks();
      if (!mounted) return;
      setState(() {
        _mine = rows;
        _loadingMine = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMine = e.toString().replaceFirst('Exception: ', '');
        _loadingMine = false;
      });
    }
  }

  Future<void> _loadAll() async {
    setState(() {
      _loadingAll = true;
      _errorAll = null;
    });
    try {
      final rows = await _api.fetchAllFeedbacks();
      if (!mounted) return;
      setState(() {
        _all = rows;
        _loadingAll = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorAll = e.toString().replaceFirst('Exception: ', '');
        _loadingAll = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!await _ensureLogin()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Login required to save')),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await _api.createFeedback(
        subject: _subjectCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
        menu: _menuCtrl.text.trim(),
      );
      if (!mounted) return;
      _subjectCtrl.clear();
      _messageCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Feedback submitted')),
          backgroundColor: AppColors.income,
        ),
      );
      _tabs.animateTo(1);
      await _loadLists();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.expense,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              icon: Icons.feedback_rounded,
              title: tr('Feedback'),
              subtitle: tr('Share ideas and report issues'),
            ),
            TabBar(
              controller: _tabs,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(text: tr('Submit')),
                Tab(text: tr('My feedback')),
                Tab(text: tr('All feedback')),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildForm(),
                  _buildList(
                    loading: _loadingMine,
                    error: _errorMine,
                    rows: _mine,
                    onRetry: _loadMine,
                    empty: tr('No feedback yet'),
                  ),
                  _buildList(
                    loading: _loadingAll,
                    error: _errorAll,
                    rows: _all,
                    onRetry: _loadAll,
                    empty: tr('No feedback yet'),
                    showUser: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Form(
        key: _formKey,
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(
                icon: Icons.edit_note_rounded,
                title: tr('Write feedback'),
                subtitle: tr('We read every message'),
              ),
              SizedBox(height: 16),
              AppField(
                controller: _subjectCtrl,
                label: tr('Subject'),
                icon: Icons.subject_rounded,
                required: true,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? tr('Required') : null,
              ),
              SizedBox(height: 12),
              AppField(
                controller: _messageCtrl,
                label: tr('Message'),
                icon: Icons.message_rounded,
                required: true,
                maxLines: 5,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? tr('Required') : null,
              ),
              SizedBox(height: 12),
              AppField(
                controller: _menuCtrl,
                label: tr('Menu context (optional)'),
                icon: Icons.menu_open_rounded,
                hint: tr('e.g. income_expense'),
              ),
              SizedBox(height: 18),
              PrimaryButton(
                label: tr('Submit feedback'),
                icon: Icons.send_rounded,
                loading: _submitting,
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList({
    required bool loading,
    required String? error,
    required List<Map<String, dynamic>> rows,
    required Future<void> Function() onRetry,
    required String empty,
    bool showUser = false,
  }) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, textAlign: TextAlign.center),
              SizedBox(height: 12),
              ElevatedButton(
                onPressed: onRetry,
                child: Text(tr('Retry')),
              ),
            ],
          ),
        ),
      );
    }
    if (rows.isEmpty) {
      return EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: empty,
      );
    }
    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        itemCount: rows.length,
        separatorBuilder: (_, __) => SizedBox(height: 8),
        itemBuilder: (context, i) => _FeedbackTile(
          row: rows[i],
          showUser: showUser,
        ),
      ),
    );
  }
}

class _FeedbackTile extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool showUser;

  const _FeedbackTile({required this.row, this.showUser = false});

  @override
  Widget build(BuildContext context) {
    final verified = row['verified'] == true;
    final subject = row['subject']?.toString().trim() ?? '';
    final message = row['message']?.toString() ?? '';
    final menu = row['menu']?.toString().trim() ?? '';
    final userName = row['user_name']?.toString().trim() ?? '';
    DateTime? created;
    final raw = row['created_at']?.toString();
    if (raw != null && raw.isNotEmpty) {
      created = DateTime.tryParse(raw);
    }

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subject.isEmpty ? tr('Feedback') : subject,
                  style: AppText.title,
                ),
              ),
              if (verified)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.incomeSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded,
                          size: 14, color: AppColors.income),
                      SizedBox(width: 4),
                      Text(
                        tr('Verified'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.income,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: 8),
          Text(message, style: AppText.body),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (showUser && userName.isNotEmpty)
                InfoChip(
                  label: userName,
                  color: AppColors.info,
                  icon: Icons.person_rounded,
                ),
              if (menu.isNotEmpty)
                InfoChip(
                  label: menu,
                  color: AppColors.primary,
                  icon: Icons.menu_rounded,
                ),
              if (created != null)
                InfoChip(
                  label: DateFormat('dd MMM yyyy').format(created.toLocal()),
                  color: AppColors.textMuted,
                  icon: Icons.schedule_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
