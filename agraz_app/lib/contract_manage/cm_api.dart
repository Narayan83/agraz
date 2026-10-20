import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth_token.dart';
import '../config.dart';

class CmApi {
  static Future<Map<String, String>> _headers() => authJsonHeaders();

  static Uri _u(String path, [Map<String, String>? q]) {
    return Uri.parse('$BASE_URL/api$path').replace(queryParameters: q);
  }

  static Future<List<dynamic>> list(String path, {Map<String, String>? q}) async {
    final res = await http.get(_u(path, q), headers: await _headers());
    if (res.statusCode != 200) {
      throw Exception(_err(res));
    }
    final body = jsonDecode(res.body);
    if (body is Map && body['data'] is List) return body['data'] as List;
    if (body is List) return body;
    return [];
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final res = await http.get(_u(path), headers: await _headers());
    if (res.statusCode != 200) throw Exception(_err(res));
    final body = jsonDecode(res.body);
    if (body is Map<String, dynamic>) return body;
    return Map<String, dynamic>.from(body as Map);
  }

  static Future<Map<String, dynamic>> post(String path, Map body) async {
    final res = await http.post(
      _u(path),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_err(res));
    }
    final decoded = jsonDecode(res.body);
    if (decoded is Map && decoded['data'] is Map) {
      return Map<String, dynamic>.from(decoded['data'] as Map);
    }
    if (decoded is Map<String, dynamic>) return decoded;
    return {};
  }

  static Future<Map<String, dynamic>> put(String path, Map body) async {
    final res = await http.put(
      _u(path),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) throw Exception(_err(res));
    final decoded = jsonDecode(res.body);
    if (decoded is Map && decoded['data'] is Map) {
      return Map<String, dynamic>.from(decoded['data'] as Map);
    }
    if (decoded is Map<String, dynamic>) return decoded;
    return {};
  }

  static Future<void> delete(String path) async {
    final res = await http.delete(_u(path), headers: await _headers());
    if (res.statusCode != 200) throw Exception(_err(res));
  }

  static String _err(http.Response res) {
    try {
      final b = jsonDecode(res.body);
      if (b is Map && b['error'] != null) return b['error'].toString();
    } catch (_) {}
    return 'Request failed (${res.statusCode})';
  }
}
