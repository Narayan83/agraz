import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'auth_token.dart';
import 'offline_outbox.dart';

const _requestTimeout = Duration(seconds: 18);
const _maxCache = 80;

/// Local outbox + GET cache. Writes are stored on device when the network is
/// down and replayed automatically when connectivity returns.
class OfflineSync extends ChangeNotifier with WidgetsBindingObserver {
  OfflineSync._();
  static final OfflineSync instance = OfflineSync._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Future<void> _io = Future<void>.value();
  bool _started = false;
  bool _syncing = false;

  bool isOnline = true;
  bool get isSyncing => _syncing;
  int pendingCount = 0;

  final OfflineOutbox _outbox = OfflineOutbox();
  final Map<String, _CacheEntry> _cache = {};

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _load();
    pendingCount = _outbox.length;
    try {
      final results = await _connectivity.checkConnectivity();
      isOnline = _hasConnection(results);
    } catch (_) {
      isOnline = true;
    }
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final nowOnline = _hasConnection(results);
      final gained = nowOnline && !isOnline;
      isOnline = nowOnline;
      notifyListeners();
      if (gained) {
        unawaited(sync());
      }
    });
    WidgetsBinding.instance.addObserver(this);
    Timer.periodic(const Duration(seconds: 45), (_) {
      if (pendingCount > 0) unawaited(sync());
    });
    notifyListeners();
    unawaited(sync());
  }

  @override
  void dispose() {
    _sub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(sync());
    }
  }

  Future<void> sync() async {
    if (_syncing) return;
    if (!isOnline && _outbox.isEmpty) return;
    final token = await getAuthToken();
    if (token == null || token.isEmpty) return;
    if (_outbox.isEmpty) return;

    _syncing = true;
    notifyListeners();
    try {
      while (_outbox.ops.isNotEmpty) {
        final op = _outbox.ops.first;
        final uri = Uri.parse(op.url);
        final headers = (op.method == 'POST' || op.method == 'PUT')
            ? await authJsonHeaders()
            : await authGetHeaders();
        http.Response response;
        try {
          response = await _send(op.method, uri, headers, op.body);
        } catch (e) {
          if (_isNetworkError(e)) {
            isOnline = false;
            break;
          }
          _outbox.ops.removeAt(0);
          await _save();
          continue;
        }
        final code = response.statusCode;
        if (code == 401) break;
        if (_isNetworkStatus(code) || code == 408 || code == 429 || code >= 500) {
          break;
        }
        _outbox.ops.removeAt(0);
        await _save();
      }
    } finally {
      pendingCount = _outbox.length;
      _syncing = false;
      notifyListeners();
    }
  }

  Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) {
    return _request('GET', url, headers: headers);
  }

  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _request('POST', url, headers: headers, body: body, encoding: encoding);
  }

  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _request('PUT', url, headers: headers, body: body, encoding: encoding);
  }

  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _request('DELETE', url, headers: headers, body: body, encoding: encoding);
  }

  Future<http.Response> _request(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    await start();
    final queueable = method != 'GET' && isQueueableUri(url);

    if (method != 'GET' && queueable && !isOnline) {
      return _enqueue(method, url, body);
    }

    try {
      final response = await _send(method, url, headers, body, encoding: encoding);
      if (!isOnline) {
        isOnline = true;
        notifyListeners();
        unawaited(sync());
      }
      if (method == 'GET' && response.statusCode >= 200 && response.statusCode < 300) {
        await _putCache(url, response);
        return _withOverlay(url, response);
      }
      return response;
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;
      isOnline = false;
      notifyListeners();
      if (method == 'GET') {
        return _offlineGet(url);
      }
      if (queueable) {
        return _enqueue(method, url, body);
      }
      rethrow;
    }
  }

  Future<http.Response> _send(
    String method,
    Uri url,
    Map<String, String>? headers,
    Object? body, {
    Encoding? encoding,
  }) {
    final Future<http.Response> raw = switch (method) {
      'POST' => http.post(url, headers: headers, body: body, encoding: encoding),
      'PUT' => http.put(url, headers: headers, body: body, encoding: encoding),
      'DELETE' => http.delete(url, headers: headers, body: body, encoding: encoding),
      _ => http.get(url, headers: headers),
    };
    return raw.timeout(_requestTimeout);
  }

  Future<http.Response> _enqueue(String method, Uri url, Object? body) {
    return _locked(() async {
      final response = _outbox.enqueue(method, url, body);
      await _persistQueue();
      return response;
    });
  }

  http.Response _offlineGet(Uri url) {
    final cached = _lookupCache(url);
    if (cached != null) {
      return _withOverlay(url, cached);
    }
    final overlayOnly = _overlayBody(url, null);
    if (overlayOnly != null) {
      return http.Response(jsonEncode(overlayOnly), 200, headers: {
        HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
      });
    }
    return http.Response(
      jsonEncode({
        'error': 'Offline and no saved data yet. Open this screen once while online.',
        'success': false,
        'data': [],
      }),
      503,
      headers: {HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8'},
    );
  }

  http.Response _withOverlay(Uri url, http.Response response) {
    if (_outbox.isEmpty) return response;
    final decoded = tryJson(response.body);
    final overlaid = _outbox.applyOverlay(url.path, decoded);
    if (identical(overlaid, decoded)) return response;
    return http.Response(
      jsonEncode(overlaid),
      response.statusCode,
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
      },
    );
  }

  dynamic _overlayBody(Uri url, dynamic decoded) {
    if (_outbox.isEmpty) return decoded;
    return _outbox.applyOverlay(url.path, decoded);
  }

  Future<void> _putCache(Uri url, http.Response response) {
    return _locked(() async {
      _cache[url.toString()] = _CacheEntry(
        status: response.statusCode,
        body: response.body,
        savedAt: DateTime.now().millisecondsSinceEpoch,
      );
      if (_cache.length > _maxCache) {
        final oldest = _cache.entries.toList()
          ..sort((a, b) => a.value.savedAt.compareTo(b.value.savedAt));
        for (final e in oldest.take(_cache.length - _maxCache)) {
          _cache.remove(e.key);
        }
      }
      await _saveUnlocked();
    });
  }

  http.Response? _lookupCache(Uri url) {
    final exact = _cache[url.toString()];
    if (exact != null) {
      return http.Response(
        exact.body,
        exact.status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    _CacheEntry? best;
    for (final e in _cache.entries) {
      final cached = Uri.tryParse(e.key);
      if (cached == null) continue;
      if (cached.path != url.path) continue;
      if (best == null || e.value.savedAt > best.savedAt) best = e.value;
    }
    if (best == null) return null;
    return http.Response(
      best.body,
      best.status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  Future<void> _persistQueue() async {
    pendingCount = _outbox.length;
    notifyListeners();
    await _saveUnlocked();
  }

  Future<void> _load() {
    return _locked(() async {
      try {
        final file = await _storeFile();
        if (!await file.exists()) return;
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is! Map) return;
        final q = decoded['queue'];
        if (q is List) {
          _outbox.loadFromJson(q);
        }
        final c = decoded['cache'];
        if (c is Map) {
          _cache.clear();
          for (final e in c.entries) {
            if (e.value is Map) {
              _cache['${e.key}'] =
                  _CacheEntry.fromJson(Map<String, dynamic>.from(e.value as Map));
            }
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _save() => _locked(_saveUnlocked);

  Future<void> _saveUnlocked() async {
    try {
      final file = await _storeFile();
      await file.writeAsString(
        jsonEncode({
          'queue': _outbox.toJsonList(),
          'cache': {
            for (final e in _cache.entries) e.key: e.value.toJson(),
          },
        }),
      );
    } catch (_) {}
  }

  Future<File> _storeFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}agraz_offline_sync.json');
  }

  Future<T> _locked<T>(Future<T> Function() fn) {
    final completer = Completer<T>();
    _io = _io.catchError((_) {}).then((_) async {
      try {
        completer.complete(await fn());
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}

bool _hasConnection(List<ConnectivityResult> results) {
  if (results.isEmpty) return false;
  return results.any((r) => r != ConnectivityResult.none);
}

bool _isNetworkError(Object e) {
  if (e is TimeoutException) return true;
  if (e is SocketException || e is HandshakeException) return true;
  if (e is http.ClientException) return true;
  final s = e.toString().toLowerCase();
  return s.contains('socketexception') ||
      s.contains('failed host lookup') ||
      s.contains('network is unreachable') ||
      s.contains('connection refused') ||
      s.contains('connection failed') ||
      s.contains('connection reset') ||
      s.contains('connection abort') ||
      s.contains('timed out') ||
      s.contains('timeout') ||
      s.contains('no address associated');
}

bool _isNetworkStatus(int code) => code == 502 || code == 503 || code == 504;

class _CacheEntry {
  _CacheEntry({
    required this.status,
    required this.body,
    required this.savedAt,
  });

  final int status;
  final String body;
  final int savedAt;

  Map<String, dynamic> toJson() => {
        'status': status,
        'body': body,
        'savedAt': savedAt,
      };

  factory _CacheEntry.fromJson(Map<String, dynamic> json) {
    return _CacheEntry(
      status: asInt(json['status']) ?? 200,
      body: '${json['body'] ?? ''}',
      savedAt: asInt(json['savedAt']) ?? 0,
    );
  }
}

/// Drop-in replacements for `http.get/post/put/delete`.
Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
    OfflineSync.instance.get(url, headers: headers);

Future<http.Response> post(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    OfflineSync.instance.post(url, headers: headers, body: body, encoding: encoding);

Future<http.Response> put(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    OfflineSync.instance.put(url, headers: headers, body: body, encoding: encoding);

Future<http.Response> delete(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) =>
    OfflineSync.instance.delete(url, headers: headers, body: body, encoding: encoding);
