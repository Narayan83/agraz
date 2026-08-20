import 'dart:convert';

import 'package:agraz/offline_outbox.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late OfflineOutbox box;

  setUp(() {
    box = OfflineOutbox();
  });

  Map<String, dynamic> decode(String body) =>
      jsonDecode(body) as Map<String, dynamic>;

  List<Map<String, dynamic>> overlayList(
    String getPath, {
    List<Map<String, dynamic>> cached = const [],
  }) {
    final overlaid = box.applyOverlay(getPath, {'data': cached});
    final data = (overlaid as Map)['data'] as List;
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  group('queueable paths', () {
    test('allows feature CRUD endpoints', () {
      const allowed = [
        '/api/dairy/entries',
        '/api/dairy/owner/customers/3',
        '/api/diary/entries',
        '/api/labors/batch',
        '/api/labor_works/12',
        '/api/income_expense/9',
        '/api/future_plans',
        '/api/organizations',
        '/api/org_ledgers/1',
        '/api/org_transactions',
        '/api/land_rtcs/4',
        '/api/documents/browse',
        '/api/feedbacks',
      ];
      for (final path in allowed) {
        expect(isQueueablePath(path), isTrue, reason: path);
      }
    });

    test('does not queue login, family, or uploads', () {
      expect(isQueueablePath('/api/login'), isFalse);
      expect(isQueueablePath('/api/family/members'), isFalse);
      expect(isQueueablePath('/api/me/password'), isFalse);
      expect(isQueueablePath('/api/land_rtcs/upload'), isFalse);
      expect(isQueueablePath('/api/documents/upload'), isFalse);
      expect(isQueueablePath('/api/register-business'), isFalse);
    });
  });

  group('dairy CRUD', () {
    final collection = Uri.parse('https://agrazllp.com/api/dairy/entries');

    test('create returns local id and overlays onto list GET', () {
      final created = box.enqueue('POST', collection, {
        'kind': 'milk_given',
        'party_name': 'Gowda Dairy',
        'quantity_liters': 12.5,
      });
      expect(created.statusCode, 201);
      final body = decode(created.body);
      expect(body['success'], isTrue);
      expect(body['offline'], isTrue);
      final id = body['id'] as int;
      expect(id, lessThan(0));
      expect(box.length, 1);

      final list = overlayList('/api/dairy/entries');
      expect(list, hasLength(1));
      expect(list.first['party_name'], 'Gowda Dairy');
      expect(list.first['id'], id);
      expect(list.first['pending_sync'], isTrue);
    });

    test('update of local record folds into the queued POST', () {
      final created = box.enqueue('POST', collection, {'party_name': 'Old'});
      final id = decode(created.body)['id'] as int;

      final updated = box.enqueue(
        'PUT',
        Uri.parse('https://agrazllp.com/api/dairy/entries/$id'),
        {'party_name': 'New', 'quantity_liters': 8},
      );
      expect(updated.statusCode, 200);
      expect(box.length, 1);
      expect(box.ops.single.method, 'POST');
      expect(jsonDecode(box.ops.single.body!)['party_name'], 'New');

      final list = overlayList('/api/dairy/entries');
      expect(list.single['party_name'], 'New');
    });

    test('delete of local record drops the queued POST', () {
      final created = box.enqueue('POST', collection, {'party_name': 'Temp'});
      final id = decode(created.body)['id'] as int;

      final deleted = box.enqueue(
        'DELETE',
        Uri.parse('https://agrazllp.com/api/dairy/entries/$id'),
        null,
      );
      expect(deleted.statusCode, 200);
      expect(box.isEmpty, isTrue);
      expect(overlayList('/api/dairy/entries'), isEmpty);
    });

    test('update then delete of a server row queues DELETE only', () {
      box.enqueue(
        'PUT',
        Uri.parse('https://agrazllp.com/api/dairy/entries/50'),
        {'party_name': 'Edited'},
      );
      expect(box.length, 1);

      box.enqueue(
        'DELETE',
        Uri.parse('https://agrazllp.com/api/dairy/entries/50'),
        null,
      );
      expect(box.length, 1);
      expect(box.ops.single.method, 'DELETE');

      final list = overlayList(
        '/api/dairy/entries',
        cached: [
          {'id': 50, 'party_name': 'Server'},
          {'id': 51, 'party_name': 'Keep'},
        ],
      );
      expect(list.map((e) => e['id']), [51]);
    });

    test('does not overlay dairy entries onto summary GET', () {
      box.enqueue('POST', collection, {'party_name': 'Hidden from summary'});
      final summary = box.applyOverlay('/api/dairy/summary', {'total': 10});
      expect(summary, {'total': 10});
    });
  });

  group('labour / diary / income-expense CRUD', () {
    test('labour batch create overlays onto /api/labors list', () {
      final res = box.enqueue(
        'POST',
        Uri.parse('https://agrazllp.com/api/labors/batch'),
        [
          {'name': 'Ramu', 'wage': 500},
          {'name': 'Sita', 'wage': 450},
        ],
      );
      expect(res.statusCode, 201);
      final data = decode(res.body)['data'] as List;
      expect(data, hasLength(2));
      expect(box.length, 1);

      final list = overlayList('/api/labors');
      expect(list.map((e) => e['name']), ['Ramu', 'Sita']);
      expect(list.every((e) => (e['id'] as int) < 0), isTrue);
    });

    test('diary create / update / delete round-trip', () {
      final notes = Uri.parse('https://agrazllp.com/api/diary/entries');
      final created = box.enqueue('POST', notes, {
        'kind': 'note',
        'title': 'Spray',
        'content': 'Need pesticide',
      });
      final id = decode(created.body)['id'] as int;

      box.enqueue(
        'PUT',
        Uri.parse('https://agrazllp.com/api/diary/entries/$id'),
        {'kind': 'note', 'title': 'Spray done', 'content': 'Done'},
      );
      expect(overlayList('/api/diary/entries').single['title'], 'Spray done');

      box.enqueue(
        'DELETE',
        Uri.parse('https://agrazllp.com/api/diary/entries/$id'),
        null,
      );
      expect(box.isEmpty, isTrue);
    });

    test('income expense PUT overlays onto cached server row', () {
      box.enqueue(
        'PUT',
        Uri.parse('https://agrazllp.com/api/income_expense/7'),
        {'amount': 250, 'narration': 'Feed'},
      );
      final list = overlayList(
        '/api/income_expense',
        cached: [
          {'id': 7, 'amount': 100, 'narration': 'Old'},
        ],
      );
      expect(list.single['amount'], 250);
      expect(list.single['narration'], 'Feed');
      expect(list.single['pending_sync'], isTrue);
    });

    test('repeat PUT of same server id coalesces to one op', () {
      final url = Uri.parse('https://agrazllp.com/api/labor_works/3');
      box.enqueue('PUT', url, {'hours': 4});
      box.enqueue('PUT', url, {'hours': 6});
      expect(box.length, 1);
      expect(jsonDecode(box.ops.single.body!)['hours'], 6);
    });
  });

  group('outbox persistence', () {
    test('round-trips queue JSON', () {
      box.enqueue(
        'POST',
        Uri.parse('https://agrazllp.com/api/future_plans'),
        {'title': 'Drip irrigation'},
      );
      final raw = box.toJsonList();
      final restored = OfflineOutbox()..loadFromJson(raw);
      expect(restored.length, 1);
      expect(restored.ops.single.method, 'POST');
      expect(jsonDecode(restored.ops.single.body!)['title'], 'Drip irrigation');
    });
  });
}
