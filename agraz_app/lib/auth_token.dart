import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

const _prefsKeyJwt = 'agraz_auth_jwt';

Future<void> saveAuthToken(String token) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(_prefsKeyJwt, token.trim());
}

Future<String?> getAuthToken() async {
  final p = await SharedPreferences.getInstance();
  final v = p.getString(_prefsKeyJwt);
  if (v == null || v.isEmpty) return null;
  return v;
}

Future<void> clearAuthToken() async {
  final p = await SharedPreferences.getInstance();
  await p.remove(_prefsKeyJwt);
}

/// Pulls JWT from common login response shapes (dashboard may vary).
String? extractTokenFromLoginResponse(dynamic decoded) {
  if (decoded is String && decoded.isNotEmpty) return decoded;
  if (decoded is! Map) return null;
  final m = Map<String, dynamic>.from(decoded);
  for (final k in [
    'token',
    'access_token',
    'accessToken',
    'jwt',
    'id_token',
    'idToken',
  ]) {
    final v = m[k];
    if (v is String && v.isNotEmpty) return v;
  }
  final data = m['data'];
  if (data is Map<String, dynamic>) {
    final nested = extractTokenFromLoginResponse(data);
    if (nested != null) return nested;
  }
  if (data is Map) {
    final nested = extractTokenFromLoginResponse(Map<String, dynamic>.from(data));
    if (nested != null) return nested;
  }
  final user = m['user'];
  if (user is Map) {
    final nested = extractTokenFromLoginResponse(Map<String, dynamic>.from(user));
    if (nested != null) return nested;
  }
  return null;
}

/// Headers for authenticated JSON APIs (Bearer JWT + tenant).
Future<Map<String, String>> authJsonHeaders() async {
  final t = await getAuthToken();
  final h = <String, String>{'Content-Type': 'application/json'};
  mergeTenantHeaders(h);
  if (t != null && t.isNotEmpty) {
    h['Authorization'] = 'Bearer $t';
  }
  return h;
}

/// GET requests: tenant + optional Bearer (no body).
Future<Map<String, String>> authGetHeaders() async {
  final t = await getAuthToken();
  final h = <String, String>{'Accept': 'application/json'};
  mergeTenantHeaders(h);
  if (t != null && t.isNotEmpty) {
    h['Authorization'] = 'Bearer $t';
  }
  return h;
}

/// Public store catalog (no JWT) — still sends `X-Tenant-ID` when configured.
Map<String, String> publicStoreHeaders() {
  final h = <String, String>{'Accept': 'application/json'};
  mergeTenantHeaders(h);
  return h;
}
