import 'package:flutter_test/flutter_test.dart';

import 'package:agraz/event_alarms.dart';

void main() {
  test('parseNotifyTime pads hour and minute', () {
    expect(formatNotifyTime(parseNotifyTime('9:05')), '09:05');
    expect(formatNotifyTime(parseNotifyTime('18:00')), '18:00');
  });

  test('nextOccurrence yearly uses next year when time has passed', () {
    final now = DateTime.now();
    final past = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    final next = nextOccurrence(past, 'yearly', (hour: 9, minute: 0));
    expect(next, isNotNull);
    expect(next!.isAfter(now), isTrue);
    expect(next.month, past.month);
    expect(next.day, past.day);
  });

  test('nextOccurrence daily is today or tomorrow at notify time', () {
    final now = DateTime.now();
    final next = nextOccurrence(now, 'daily', (hour: 23, minute: 59));
    expect(next, isNotNull);
    expect(next!.isAfter(now), isTrue);
    expect(next.difference(now).inHours < 25, isTrue);
  });
}
