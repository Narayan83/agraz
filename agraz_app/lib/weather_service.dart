import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';

Map<String, String> _headers() {
  final headers = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  mergeTenantHeaders(headers);
  return headers;
}

Future<Map<String, dynamic>> fetchWeatherReport({String location = 'sirsi'}) async {
  try {
    final uri = Uri.parse('${normalizedBaseUrl()}/api/weather').replace(
      queryParameters: {'location': location},
    );
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return {};
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['data'] is Map) {
      return Map<String, dynamic>.from(decoded['data'] as Map);
    }
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  } catch (_) {
    return {};
  }
}

Future<List<Map<String, dynamic>>> fetchWeatherLocations() async {
  try {
    final uri = Uri.parse('${normalizedBaseUrl()}/api/weather/locations');
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const [];
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['data'] is List) {
      return (decoded['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  } catch (_) {
    return const [];
  }
}
