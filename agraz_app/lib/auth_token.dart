import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

const _prefsKeyJwt = 'agraz_auth_jwt';

Future<void> saveAuthToken(String token) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(_prefsKeyJwt, token.trim());
}

Future<String?> getAuthToken() async {
  final p = await SharedPreferences.getInstance();
  final v = p.getString(_prefsKeyJwt)?.trim();
  if (v == null || v.isEmpty) return null;
  return v;
}

/// Stored JWT if it is present and not past its `exp` claim.
/// Clears the saved token when it is expired or not a JWT.
Future<String?> getValidAuthToken() async {
  final t = await getAuthToken();
  if (t == null) return null;
  if (isJwtExpired(t)) {
    await clearAuthToken();
    return null;
  }
  return t;
}

bool isUnauthorizedStatus(int statusCode) => statusCode == 401;

/// True when [token] is missing `exp`, malformed, or already expired.
bool isJwtExpired(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return true;
  try {
    var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    switch (payload.length % 4) {
      case 2:
        payload += '==';
      case 3:
        payload += '=';
    }
    final decoded = jsonDecode(utf8.decode(base64.decode(payload)));
    if (decoded is! Map) return true;
    final exp = decoded['exp'];
    if (exp is! num) return true;
    final expiry = DateTime.fromMillisecondsSinceEpoch(
      (exp * 1000).round(),
      isUtc: true,
    );
    return DateTime.now().toUtc().isAfter(expiry);
  } catch (_) {
    return true;
  }
}

/// Opens the login route when there is no valid session.
/// Uses named `/login` to avoid circular imports with [LoginScreen].
Future<bool> ensureLoggedIn(BuildContext context, {bool force = false}) async {
  if (force) {
    await clearAuthToken();
  } else {
    final token = await getValidAuthToken();
    if (token != null) return true;
  }
  if (!context.mounted) return false;
  final result = await Navigator.of(context).pushNamed('/login');
  if (result != true || !context.mounted) return false;
  final token = await getValidAuthToken();
  return token != null;
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
  final t = await getValidAuthToken();
  final h = <String, String>{'Content-Type': 'application/json'};
  mergeTenantHeaders(h);
  if (t != null && t.isNotEmpty) {
    h['Authorization'] = 'Bearer $t';
  }
  return h;
}

/// GET requests: tenant + optional Bearer (no body).
Future<Map<String, String>> authGetHeaders() async {
  final t = await getValidAuthToken();
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
