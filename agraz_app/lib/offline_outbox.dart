import 'dart:convert';

import 'package:http/http.dart' as http;

const kMaxOfflineQueue = 500;

const kQueueablePrefixes = [
  '/api/income_expense',
  '/api/labors',
  '/api/labor_rates',
  '/api/labor_works',
  '/api/labor_shares',
  '/api/diary',
  '/api/dairy',
  '/api/future_plans',
  '/api/organizations',
  '/api/org_ledgers',
  '/api/org_transactions',
  '/api/land_rtcs',
  '/api/documents',
  '/api/feedbacks',
];

bool isQueueablePath(String path) {
  if (path.contains('/upload')) return false;
  for (final prefix in kQueueablePrefixes) {
    if (path == prefix || path.startsWith('$prefix/')) return true;
  }
  return false;
}

bool isQueueableUri(Uri url) => isQueueablePath(url.path);

/// In-memory write-ahead queue used while offline. [OfflineSync] persists it.
class OfflineOutbox {
  final List<QueuedOp> ops = [];

  int get length => ops.length;
  bool get isEmpty => ops.isEmpty;

  void loadFromJson(List<dynamic> raw) {
    ops
      ..clear()
      ..addAll(
        raw
            .whereType<Map>()
            .map((e) => QueuedOp.fromJson(Map<String, dynamic>.from(e))),
      );
  }

  List<Map<String, dynamic>> toJsonList() =>
      ops.map((e) => e.toJson()).toList();

  http.Response enqueue(String method, Uri url, Object? body) {
    final bodyStr = bodyToString(body);
    final path = url.path;

    if (method == 'PUT' || method == 'DELETE') {
      final id = resourceId(path);
      if (id != null && id < 0) {
        final handled = foldLocalMutation(method, url, id, bodyStr);
        if (handled != null) return handled;
      }
      if (method == 'PUT') {
        final existing = ops.indexWhere(
          (op) => op.method == 'PUT' && op.url == url.toString(),
        );
        if (existing >= 0) {
          ops[existing].body = bodyStr;
          return syntheticOk(method, bodyStr, localId: id);
        }
      }
      if (method == 'DELETE') {
        ops.removeWhere(
          (op) => op.method == 'PUT' && sameResource(op.url, url.toString()),
        );
      }
    }

    if (ops.length >= kMaxOfflineQueue) {
      throw Exception('Too many unsynced changes. Connect to the internet to sync.');
    }

    int? localId;
    List<int>? localIds;
    if (method == 'POST') {
      final decoded = tryJson(bodyStr);
      if (decoded is List) {
        final base = nextLocalId();
        localIds = [for (var i = 0; i < decoded.length; i++) base - i];
      } else {
        localId = nextLocalId();
      }
    } else {
      localId = resourceId(path);
    }

    ops.add(QueuedOp(
      id: '${DateTime.now().microsecondsSinceEpoch}_${ops.length}',
      method: method,
      url: url.toString(),
      body: bodyStr,
      localId: localId,
      localIds: localIds,
    ));
    return syntheticOk(method, bodyStr, localId: localId, localIds: localIds);
  }

  http.Response? foldLocalMutation(
    String method,
    Uri url,
    int localId,
    String? bodyStr,
  ) {
    final idx = ops.indexWhere(
      (op) =>
          op.method == 'POST' &&
          (op.localId == localId || (op.localIds?.contains(localId) ?? false)),
    );
    if (idx < 0) return null;

    if (method == 'DELETE') {
      final op = ops[idx];
      if (op.localIds != null && op.localIds!.length > 1) {
        final decoded = tryJson(op.body);
        if (decoded is List) {
          final keep = <dynamic>[];
          final keepIds = <int>[];
          for (var i = 0; i < decoded.length; i++) {
            final id = i < op.localIds!.length ? op.localIds![i] : null;
            if (id == localId) continue;
            keep.add(decoded[i]);
            if (id != null) keepIds.add(id);
          }
          if (keep.isEmpty) {
            ops.removeAt(idx);
          } else {
            op.body = jsonEncode(keep);
            op.localIds = keepIds;
          }
        } else {
          ops.removeAt(idx);
        }
      } else {
        ops.removeAt(idx);
      }
      return http.Response('{"success":true,"offline":true}', 200);
    }

    final op = ops[idx];
    if (op.localIds != null) {
      final decoded = tryJson(op.body);
      final patch = tryJson(bodyStr);
      if (decoded is List && patch is Map) {
        for (var i = 0; i < decoded.length; i++) {
          if (i < op.localIds!.length && op.localIds![i] == localId) {
            if (decoded[i] is Map) {
              decoded[i] = {
                ...Map<String, dynamic>.from(decoded[i] as Map),
                ...Map<String, dynamic>.from(patch),
                'id': localId,
              };
            }
          }
        }
        op.body = jsonEncode(decoded);
      }
    } else {
      op.body = bodyStr;
    }
    return syntheticOk('PUT', bodyStr, localId: localId);
  }

  dynamic applyOverlay(String getPath, dynamic decoded) {
    final matching = ops
        .where((op) => affectsPath(getPath, Uri.parse(op.url).path))
        .toList();
    if (matching.isEmpty) return decoded;

    dynamic copy =
        decoded == null ? {'data': []} : jsonDecode(jsonEncode(decoded));
    List<dynamic>? list;
    Map<String, dynamic>? wrapper;
    if (copy is List) {
      list = copy;
    } else if (copy is Map && copy['data'] is List) {
      wrapper = Map<String, dynamic>.from(copy);
      list = List<dynamic>.from(copy['data'] as List);
    } else if (copy is Map) {
      wrapper = Map<String, dynamic>.from(copy);
    }

    for (final op in matching) {
      final opPath = Uri.parse(op.url).path;
      if (op.method == 'POST') {
        if (resourceId(getPath) != null) continue;
        final stripped = stripBatch(opPath);
        if (stripped != collectionPath(stripped)) continue;
        final items = itemsFromPost(op);
        list ??= [];
        list.addAll(items);
      } else if (op.method == 'PUT') {
        final id = resourceId(opPath);
        final patch = tryJson(op.body);
        if (id != null && patch is Map) {
          final merged = Map<String, dynamic>.from(patch);
          merged['id'] = id;
          merged['pending_sync'] = true;
          if (list != null) {
            final i = list.indexWhere((row) => idOf(row) == id);
            if (i >= 0 && list[i] is Map) {
              list[i] = {
                ...Map<String, dynamic>.from(list[i] as Map),
                ...merged,
              };
            }
          } else if (wrapper != null && idOf(wrapper) == id) {
            wrapper.addAll(merged);
          }
        }
      } else if (op.method == 'DELETE') {
        final id = resourceId(opPath);
        if (id != null && list != null) {
          list.removeWhere((row) => idOf(row) == id);
        }
      }
    }

    if (list != null) {
      if (wrapper != null) {
        wrapper['data'] = list;
        return wrapper;
      }
      return list;
    }
    return wrapper ?? copy;
  }

  List<Map<String, dynamic>> itemsFromPost(QueuedOp op) {
    final decoded = tryJson(op.body);
    if (decoded is List) {
      final items = <Map<String, dynamic>>[];
      for (var i = 0; i < decoded.length; i++) {
        final row = decoded[i] is Map
            ? Map<String, dynamic>.from(decoded[i] as Map)
            : <String, dynamic>{};
        row['id'] = (op.localIds != null && i < op.localIds!.length)
            ? op.localIds![i]
            : (op.localId ?? nextLocalId());
        row['pending_sync'] = true;
        items.add(row);
      }
      return items;
    }
    final row = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    row['id'] = op.localId ?? nextLocalId();
    row['pending_sync'] = true;
    return [row];
  }
}

class QueuedOp {
  QueuedOp({
    required this.id,
    required this.method,
    required this.url,
    this.body,
    this.localId,
    this.localIds,
  });

  final String id;
  final String method;
  final String url;
  String? body;
  int? localId;
  List<int>? localIds;

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'url': url,
        'body': body,
        'localId': localId,
        'localIds': localIds,
      };

  factory QueuedOp.fromJson(Map<String, dynamic> json) {
    return QueuedOp(
      id: '${json['id'] ?? ''}',
      method: '${json['method'] ?? 'POST'}',
      url: '${json['url'] ?? ''}',
      body: json['body']?.toString(),
      localId: asInt(json['localId']),
      localIds: json['localIds'] is List
          ? (json['localIds'] as List).map(asInt).whereType<int>().toList()
          : null,
    );
  }
}

http.Response syntheticOk(
  String method,
  String? bodyStr, {
  int? localId,
  List<int>? localIds,
}) {
  if (method == 'DELETE') {
    return http.Response('{"success":true,"offline":true}', 200);
  }
  final decoded = tryJson(bodyStr);
  if (localIds != null && decoded is List) {
    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < decoded.length; i++) {
      final row = decoded[i] is Map
          ? Map<String, dynamic>.from(decoded[i] as Map)
          : <String, dynamic>{'value': decoded[i]};
      row['id'] = i < localIds.length ? localIds[i] : nextLocalId();
      row['pending_sync'] = true;
      items.add(row);
    }
      return http.Response(
        jsonEncode({'success': true, 'offline': true, 'data': items}),
        201,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    final map = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (localId != null) map['id'] = localId;
    map['pending_sync'] = true;
    return http.Response(
      jsonEncode({
        'success': true,
        'offline': true,
        'id': localId,
        'data': map,
        'message': 'Saved on this device - will sync when online',
      }),
      method == 'POST' ? 201 : 200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

bool affectsPath(String getPath, String opPath) {
  return collectionPath(stripBatch(getPath)) ==
      collectionPath(stripBatch(opPath));
}

String? bodyToString(Object? body) {
  if (body == null) return null;
  if (body is String) return body;
  return jsonEncode(body);
}

dynamic tryJson(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    return jsonDecode(raw);
  } catch (_) {
    return null;
  }
}

int? asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v');
}

int? idOf(dynamic row) {
  if (row is Map) return asInt(row['id']);
  return null;
}

int? resourceId(String path) {
  final segs = path.split('/').where((s) => s.isNotEmpty).toList();
  if (segs.isEmpty) return null;
  return int.tryParse(segs.last);
}

String stripBatch(String path) {
  if (path.endsWith('/batch')) {
    return path.substring(0, path.length - '/batch'.length);
  }
  return path;
}

String collectionPath(String path) {
  final segs = path.split('/').where((s) => s.isNotEmpty).toList();
  if (segs.isEmpty) return path;
  if (int.tryParse(segs.last) != null) {
    return '/${segs.sublist(0, segs.length - 1).join('/')}';
  }
  const actions = {'accept', 'reject'};
  if (segs.length >= 2 &&
      actions.contains(segs.last) &&
      int.tryParse(segs[segs.length - 2]) != null) {
    return '/${segs.sublist(0, segs.length - 2).join('/')}';
  }
  return path.startsWith('/') ? path : '/$path';
}

bool sameResource(String a, String b) {
  final ua = Uri.tryParse(a);
  final ub = Uri.tryParse(b);
  if (ua == null || ub == null) return a == b;
  return ua.path == ub.path;
}

int nextLocalId() => -DateTime.now().microsecondsSinceEpoch;
