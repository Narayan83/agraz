import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

Map<String, String> _marketHeaders() {
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
    final response = await http.get(uri, headers: _marketHeaders());
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

Future<Map<String, dynamic>> _getMap(String path, [Map<String, String>? query]) async {
  try {
    final uri = Uri.parse('${normalizedBaseUrl()}$path').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
    final response = await http.get(uri, headers: _marketHeaders());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return {};
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  } catch (_) {
    return {};
  }
}

Future<List<Map<String, dynamic>>> fetchMarketAgents() async {
  final list = await _getList('/api/market/agents');
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

Future<List<Map<String, dynamic>>> fetchMarketApmcs({String? taluk}) async {
  final qp = <String, String>{};
  if (taluk != null && taluk.isNotEmpty) qp['taluk'] = taluk;
  final list = await _getList('/api/market/apmcs', qp);
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

Future<List<Map<String, dynamic>>> fetchMarketVarieties() async {
  final list = await _getList('/api/market/varieties');
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

Future<List<String>> fetchMarketTaluks() async {
  final list = await _getList('/api/market/taluks');
  return list.map((e) => e.toString()).toList();
}

Future<List<Map<String, dynamic>>> fetchMarketDailyPrices({
  String? date,
  String? from,
  String? to,
  int? agentId,
  int? apmcId,
  int? varietyId,
  String? taluk,
  int limit = 100,
}) async {
  final qp = <String, String>{'limit': '$limit'};
  if (date != null && date.isNotEmpty) qp['date'] = date;
  if (from != null && from.isNotEmpty) qp['from'] = from;
  if (to != null && to.isNotEmpty) qp['to'] = to;
  if (agentId != null) qp['agent_id'] = '$agentId';
  if (apmcId != null) qp['apmc_id'] = '$apmcId';
  if (varietyId != null) qp['variety_id'] = '$varietyId';
  if (taluk != null && taluk.isNotEmpty) qp['taluk'] = taluk;
  final list = await _getList('/api/market/daily-prices', qp);
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}

Future<Map<String, dynamic>> fetchMarketAnalytics({
  String? date,
  String? from,
  String? to,
  int? agentId,
  int? apmcId,
  int? varietyId,
  String? taluk,
}) async {
  final qp = <String, String>{};
  if (date != null && date.isNotEmpty) qp['date'] = date;
  if (from != null && from.isNotEmpty) qp['from'] = from;
  if (to != null && to.isNotEmpty) qp['to'] = to;
  if (agentId != null) qp['agent_id'] = '$agentId';
  if (apmcId != null) qp['apmc_id'] = '$apmcId';
  if (varietyId != null) qp['variety_id'] = '$varietyId';
  if (taluk != null && taluk.isNotEmpty) qp['taluk'] = taluk;
  return _getMap('/api/market/analytics', qp);
}

Future<List<Map<String, dynamic>>> fetchMarketQuantities({
  String? date,
  int? agentId,
  int? apmcId,
  String? taluk,
  int limit = 50,
}) async {
  final qp = <String, String>{'limit': '$limit'};
  if (date != null && date.isNotEmpty) qp['date'] = date;
  if (agentId != null) qp['agent_id'] = '$agentId';
  if (apmcId != null) qp['apmc_id'] = '$apmcId';
  if (taluk != null && taluk.isNotEmpty) qp['taluk'] = taluk;
  final list = await _getList('/api/market/quantities', qp);
  return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}
