import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

Map<String, String> _govHeaders() {
  final headers = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  mergeTenantHeaders(headers);
  return headers;
}

Future<List<dynamic>> _getList(String path, [Map<String, String>? query]) async {
  try {
    final uri = Uri.parse('${normalizedBaseUrl()}$path').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
    final response = await http.get(uri, headers: _govHeaders());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return [];
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['data'] is List) {
      return decoded['data'] as List<dynamic>;
    }
    if (decoded is List) return decoded;
    return [];
  } catch (_) {
    return [];
  }
}

Future<Map<String, dynamic>> _getObject(String path) async {
  final uri = Uri.parse('${normalizedBaseUrl()}$path');
  final response = await http.get(uri, headers: _govHeaders());
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Request failed (${response.statusCode}): ${response.body}');
  }
  final decoded = jsonDecode(response.body);
  if (decoded is Map && decoded['data'] is Map) {
    return Map<String, dynamic>.from(decoded['data'] as Map);
  }
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  throw Exception('Unexpected response');
}

Future<List<Map<String, dynamic>>> fetchGovDepartments() async {
  final list = await _getList('/api/gov/departments');
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

Future<List<Map<String, dynamic>>> fetchGovCrops() async {
  final list = await _getList('/api/gov/crops');
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

Future<List<Map<String, dynamic>>> fetchGovCategories() async {
  final list = await _getList('/api/gov/categories');
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

Future<List<Map<String, dynamic>>> fetchGovFacilities({
  int? departmentId,
  int? cropId,
  String? category,
  String? q,
}) async {
  final qp = <String, String>{};
  if (departmentId != null) qp['department_id'] = '$departmentId';
  if (cropId != null) qp['crop_id'] = '$cropId';
  if (category != null && category.isNotEmpty) qp['category'] = category;
  if (q != null && q.trim().isNotEmpty) qp['q'] = q.trim();
  final list = await _getList('/api/gov/facilities', qp);
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

Future<Map<String, dynamic>> fetchGovFacility(int id) async {
  return _getObject('/api/gov/facilities/$id');
}
