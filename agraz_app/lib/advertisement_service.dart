import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

const _adsCacheKey = 'agraz_active_ads_cache_v1';

class Advertisement {
  final int id;
  final String title;
  final String? subtitle;
  final String? tag;
  final String imageUrl;
  final String linkType;
  final String? linkValue;
  final int sortOrder;

  const Advertisement({
    required this.id,
    required this.title,
    this.subtitle,
    this.tag,
    required this.imageUrl,
    this.linkType = 'none',
    this.linkValue,
    this.sortOrder = 0,
  });

  factory Advertisement.fromJson(Map<String, dynamic> json) {
    return Advertisement(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : int.tryParse('${json['id']}') ?? 0,
      title: '${json['title'] ?? ''}',
      subtitle: json['subtitle']?.toString(),
      tag: json['tag']?.toString(),
      imageUrl: '${json['image_url'] ?? ''}',
      linkType: '${json['link_type'] ?? 'none'}',
      linkValue: json['link_value']?.toString(),
      sortOrder: (json['sort_order'] is num)
          ? (json['sort_order'] as num).toInt()
          : int.tryParse('${json['sort_order']}') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (tag != null) 'tag': tag,
        'image_url': imageUrl,
        'link_type': linkType,
        if (linkValue != null) 'link_value': linkValue,
        'sort_order': sortOrder,
      };

  String get resolvedImageUrl => resolveStoreMediaUrl(imageUrl);
}

/// Static fallback when API fails or returns no ads.
const Advertisement kDefaultAdvertisement = Advertisement(
  id: 0,
  title: 'Smart Farming, Simplified',
  subtitle: 'Agriculture ERP for modern farms',
  imageUrl: '',
  linkType: 'none',
);

Future<List<Advertisement>> _readCachedAds() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_adsCacheKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => Advertisement.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  } catch (_) {
    return const [];
  }
}

Future<void> _writeCachedAds(List<Advertisement> ads) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _adsCacheKey,
      jsonEncode(ads.map((a) => a.toJson()).toList()),
    );
  } catch (_) {}
}

Future<List<Advertisement>> fetchActiveAdvertisements() async {
  try {
    final uri = Uri.parse('${normalizedBaseUrl()}/api/advertisements/active');
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    mergeTenantHeaders(headers);
    final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final cached = await _readCachedAds();
      if (cached.isNotEmpty) return cached;
      return const [kDefaultAdvertisement];
    }
    final decoded = jsonDecode(response.body);
    final list = (decoded is Map && decoded['data'] is List)
        ? decoded['data'] as List
        : (decoded is List ? decoded : const []);
    final ads = list
        .whereType<Map>()
        .map((e) => Advertisement.fromJson(Map<String, dynamic>.from(e)))
        .where((a) => a.imageUrl.isNotEmpty || a.title.isNotEmpty)
        .toList();
    if (ads.isEmpty) {
      final cached = await _readCachedAds();
      if (cached.isNotEmpty) return cached;
      return const [kDefaultAdvertisement];
    }
    await _writeCachedAds(ads);
    return ads;
  } catch (_) {
    final cached = await _readCachedAds();
    if (cached.isNotEmpty) return cached;
    return const [kDefaultAdvertisement];
  }
}

Future<void> recordAdvertisementImpression(int id) async {
  if (id <= 0) return;
  try {
    final uri = Uri.parse('${normalizedBaseUrl()}/api/advertisements/$id/impression');
    final headers = <String, String>{'Accept': 'application/json'};
    mergeTenantHeaders(headers);
    await http.post(uri, headers: headers).timeout(const Duration(seconds: 5));
  } catch (_) {}
}

Future<void> recordAdvertisementClick(int id) async {
  if (id <= 0) return;
  try {
    final uri = Uri.parse('${normalizedBaseUrl()}/api/advertisements/$id/click');
    final headers = <String, String>{'Accept': 'application/json'};
    mergeTenantHeaders(headers);
    await http.post(uri, headers: headers).timeout(const Duration(seconds: 5));
  } catch (_) {}
}
