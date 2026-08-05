import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'config.dart';
import 'service_register.dart';

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
      _load(q: _searchController.text.trim().isEmpty ? null : _searchController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped();
    final mains = grouped.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        title: const Text('General Services'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(
              q: _searchController.text.trim().isEmpty
                  ? null
                  : _searchController.text.trim(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search services, place, category…',
                prefixIcon: const Icon(Icons.search, size: 22),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 20),
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
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => _load(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _load(
                          q: _searchController.text.trim().isEmpty
                              ? null
                              : _searchController.text.trim(),
                        ),
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 24),
                          children: [
                            if (mains.isEmpty)
                              const Padding(
                                padding: EdgeInsets.fromLTRB(24, 40, 24, 16),
                                child: Text(
                                  'No approved services yet.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black54),
                                ),
                              )
                            else
                              ...mains.map(
                                (main) => _CategoryBlock(
                                  mainCategory: main,
                                  subCategories: grouped[main]!,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              child: Center(
                                child: TextButton(
                                  onPressed: _openRegister,
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF2E7D32),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Register your Business or Service',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Color(0xFF2E7D32),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
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
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            mainCategory,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
        ),
        ...subCategories.entries.expand((e) {
          return [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                e.key,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF388E3C),
                ),
              ),
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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: SizedBox(
              height: 150,
              child: img.isEmpty
                  ? Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.store, size: 48, color: Colors.grey),
                    )
                  : Image.network(
                      img,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.broken_image, size: 48),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.businessName,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  provider.name,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                if (provider.businessAddress != null &&
                    provider.businessAddress!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.place, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          provider.businessAddress!,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 18, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text(provider.mobile, style: const TextStyle(fontSize: 15)),
                    const Spacer(),
                    TextButton(onPressed: _call, child: const Text('CALL')),
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
