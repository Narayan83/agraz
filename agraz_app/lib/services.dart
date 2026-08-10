import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'config.dart';
import 'service_register.dart';
import 'app_theme.dart';
import 'l10n/app_l10n.dart';

class ServiceListingPage extends StatefulWidget {
  const ServiceListingPage({super.key});

  @override
  State<ServiceListingPage> createState() => _ServiceListingPageState();
}

class _ServiceListingPageState extends State<ServiceListingPage> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<ServiceProvider> _all = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({String? q}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _api.fetchApprovedServices(query: q);
      if (!mounted) return;
      setState(() {
        _all = rows.map(ServiceProvider.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String? _currentQuery() =>
      _searchController.text.trim().isEmpty ? null : _searchController.text.trim();

  Map<String, Map<String, List<ServiceProvider>>> _grouped() {
    final map = <String, Map<String, List<ServiceProvider>>>{};
    for (final s in _all) {
      final main = s.mainCategory.isEmpty ? 'Other' : s.mainCategory;
      final sub = (s.subCategory == null || s.subCategory!.isEmpty)
          ? 'General'
          : s.subCategory!;
      map.putIfAbsent(main, () => {});
      map[main]!.putIfAbsent(sub, () => []);
      map[main]![sub]!.add(s);
    }
    return map;
  }

  Future<void> _openRegister() async {
    final ok = await showServiceRegisterSheet(context);
    if (ok == true && mounted) {
      _load(q: _currentQuery());
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped();
    final mains = grouped.keys.toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(tr('General Services')),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.headerGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: tr('Register Service'),
            onPressed: _openRegister,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: tr('Refresh'),
            onPressed: () => _load(q: _currentQuery()),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: tr('Search services, place, category…'),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  tooltip: tr('Clear'),
                  onPressed: () {
                    _searchController.clear();
                    _load();
                  },
                ),
              ),
              onSubmitted: (v) => _load(q: v.trim().isEmpty ? null : v.trim()),
            ),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => _load(q: _currentQuery()),
                                child: Text(tr('Retry')),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _load(q: _currentQuery()),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                          children: [
                            if (mains.isEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: 60),
                                child: EmptyState(
                                  icon: Icons.search_off_rounded,
                                  title: tr('No approved services yet'),
                                  subtitle:
                                      tr('Pull down to refresh or register a new service'),
                                ),
                              )
                            else
                              ...mains.map(
                                (main) => _CategoryBlock(
                                  mainCategory: main,
                                  subCategories: grouped[main]!,
                                ),
                              ),
                          ],
                        ),
                      ),
          ),
          SafeArea(
            top: false,
            child: Material(
              color: AppColors.surface,
              elevation: 8,
              shadowColor: Colors.black26,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _openRegister,
                    icon: const Icon(Icons.add_business_rounded, size: 18),
                    label: Text(tr('Register your Business or Service')),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      backgroundColor: AppColors.primarySoft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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
}

class ServiceProvider {
  final int id;
  final String name;
  final String businessName;
  final String mobile;
  final String mainCategory;
  final String? subCategory;
  final String? email;
  final String? businessAddress;
  final String? coverImage;
  final List<String> imagePaths;

  ServiceProvider({
    required this.id,
    required this.name,
    required this.businessName,
    required this.mobile,
    required this.mainCategory,
    this.subCategory,
    this.email,
    this.businessAddress,
    this.coverImage,
    this.imagePaths = const [],
  });

  String get displayImage {
    if (coverImage != null && coverImage!.isNotEmpty) {
      return resolveStoreMediaUrl(coverImage!);
    }
    if (imagePaths.isNotEmpty) {
      return resolveStoreMediaUrl(imagePaths.first);
    }
    return '';
  }

  factory ServiceProvider.fromJson(Map<String, dynamic> json) {
    List<String> paths = [];
    final raw = json['image_paths'];
    if (raw is List) {
      paths = raw.map((e) => e.toString()).toList();
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is List) {
          paths = parsed.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    return ServiceProvider(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      businessName: json['business_name']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      mainCategory: json['main_category']?.toString() ?? '',
      subCategory: json['sub_category']?.toString(),
      email: json['email']?.toString(),
      businessAddress: json['business_address']?.toString(),
      coverImage: json['cover_image']?.toString(),
      imagePaths: paths,
    );
  }
}

class _CategoryBlock extends StatelessWidget {
  final String mainCategory;
  final Map<String, List<ServiceProvider>> subCategories;

  const _CategoryBlock({
    required this.mainCategory,
    required this.subCategories,
  });

  IconData _iconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'farming services':
        return Icons.agriculture_rounded;
      case 'animal husbandry':
        return Icons.pets_rounded;
      case 'passenger vehicle':
        return Icons.airport_shuttle_rounded;
      case 'goods vehicle':
        return Icons.local_shipping_rounded;
      case 'jcb/hitachi':
        return Icons.precision_manufacturing_rounded;
      case 'medicine':
        return Icons.medication_rounded;
      default:
        return Icons.miscellaneous_services_rounded;
    }
  }

  Color _colorForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'farming services':
        return AppColors.primary;
      case 'animal husbandry':
        return AppColors.warning;
      case 'passenger vehicle':
        return AppColors.info;
      case 'goods vehicle':
        return AppColors.accent;
      case 'jcb/hitachi':
        return AppColors.expense;
      case 'medicine':
        return AppColors.primaryLight;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
          child: Row(
            children: [
              TintedIcon(
                icon: _iconForCategory(mainCategory),
                color: _colorForCategory(mainCategory),
                boxSize: 38,
                size: 19,
                radius: 11,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  mainCategory,
                  style: AppText.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        ...subCategories.entries.expand((e) {
          return [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: Text(e.key, style: AppText.subtitle),
            ),
            ...e.value.map((b) => _BusinessCard(provider: b)),
          ];
        }),
      ],
    );
  }
}

class _BusinessCard extends StatelessWidget {
  final ServiceProvider provider;

  const _BusinessCard({required this.provider});

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: provider.mobile);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = provider.displayImage;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [AppColors.softShadow],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 150,
            child: img.isEmpty
                ? Container(
                    color: AppColors.primarySoft,
                    child: const Icon(
                      Icons.storefront_rounded,
                      size: 48,
                      color: AppColors.primaryLight,
                    ),
                  )
                : Image.network(
                    img,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.surfaceAlt,
                      child: const Icon(
                        Icons.broken_image_rounded,
                        size: 48,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.businessName,
                  style: AppText.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(provider.name, style: AppText.small),
                if (provider.businessAddress != null &&
                    provider.businessAddress!.isNotEmpty) ...[
                  SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.place_rounded,
                        size: 15,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          provider.businessAddress!,
                          style: AppText.small,
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.infoSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.phone_rounded, size: 14, color: AppColors.info),
                          SizedBox(width: 6),
                          Text(
                            'Contact',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.info,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _call,
                      icon: const Icon(Icons.call_rounded, size: 16),
                      label: Text(tr('Call')),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
