import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'auth_token.dart';
import 'config.dart';

/// `GET /api/store/products?status=active&limit=50` — dashboard store catalog.
/// Sends `X-Tenant-ID` when `AGRaz_TENANT_ID` is set; optional `vendor_id` from `AGRaz_STORE_VENDOR_ID`.
///
/// Response may be `{ "data": [...] }`, `{ "products": [...] }`,
/// `{ "data": { "products": [...] } }`, or a raw array.
Future<List<Map<String, dynamic>>> fetchBuySellListingsRaw() async {
  final base = normalizedBaseUrl();
  final qp = <String, String>{
    'status': 'active',
    'limit': '50',
  };
  final vid = STORE_VENDOR_ID.trim();
  if (vid.isNotEmpty) {
    qp['vendor_id'] = vid;
  }
  final uri = Uri.parse('$base/api/store/products').replace(queryParameters: qp);

  late http.Response response;
  try {
    response = await http
        .get(uri, headers: publicStoreHeaders())
        .timeout(const Duration(seconds: 20));
  } on SocketException catch (e) {
    throw Exception(
      'Cannot reach $uri\n'
      'Set AGRaz_API_BASE to the same host:port as the website (no trailing slash). '
      'Emulator → host: http://10.0.2.2:PORT if the server listens on 0.0.0.0.\n'
      '$e',
    );
  } on TimeoutException catch (e) {
    throw Exception('Request timed out: $uri\n$e');
  }

  if (response.statusCode != 200) {
    final body = response.body;
    final preview = body.length > 280 ? '${body.substring(0, 280)}…' : body;
    throw Exception(
      'HTTP ${response.statusCode} for GET $uri\n'
      'Expect GET /api/store/products under /api. If 400/403, set --dart-define=AGRaz_TENANT_ID=… '
      '(same as web VITE_TENANT_ID).\n'
      '$preview',
    );
  }

  final decoded = jsonDecode(response.body);
  final raw = _extractProductList(decoded);
  return raw
      .whereType<Map<dynamic, dynamic>>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

List<dynamic> _extractProductList(dynamic decoded) {
  if (decoded is List) return decoded;
  if (decoded is! Map) return [];

  final m = Map<String, dynamic>.from(decoded);

  for (final key in ['products', 'items', 'results', 'list', 'data']) {
    final v = m[key];
    if (v is List) return v;
    if (v is Map && v['products'] is List) return v['products'] as List<dynamic>;
    if (v is Map && v['items'] is List) return v['items'] as List<dynamic>;
  }
  return [];
}
