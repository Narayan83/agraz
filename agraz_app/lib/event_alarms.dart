import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'api_service.dart';
import 'auth_token.dart';

const _channelId = 'agraz_event_alarms';
const _channelName = 'Event alarms';
const _channelDesc = 'Birthday, insurance and reminder alarms';

bool get _alarmsSupported =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

class EventAlarms {
  EventAlarms._();
  static final EventAlarms instance = EventAlarms._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (!_alarmsSupported) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      }

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      );
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();

      _ready = true;
    } catch (e) {
      debugPrint('EventAlarms.init failed: $e');
      _ready = false;
    }
  }

  Future<void> syncFromApi() async {
    if (!_alarmsSupported) return;
    if (!_ready) await init();
    if (!_ready) return;
    final token = await getAuthToken();
    if (token == null || token.isEmpty) {
      await cancelAll();
      return;
    }
    try {
      final rows = await ApiService().fetchManagedEvents();
      await _plugin.cancelAll();
      for (final row in rows) {
        await scheduleEvent(row);
      }
    } catch (e) {
      debugPrint('EventAlarms.syncFromApi failed: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_alarmsSupported || !_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('EventAlarms.cancelAll failed: $e');
    }
  }

  Future<void> cancelEvent(int id) async {
    if (!_alarmsSupported || !_ready) return;
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  Future<void> scheduleEvent(Map<String, dynamic> row) async {
    if (!_alarmsSupported) return;
    if (!_ready) await init();
    if (!_ready) return;
    final id = _asInt(row['id']);
    if (id == null || id <= 0) return;
    final name = (row['name'] ?? '').toString().trim();
    if (name.isEmpty) return;
    final recurrence = (row['recurrence'] ?? 'yearly').toString().toLowerCase();
    final eventDate = parseManagedEventDate(row['event_date']);
    final notify = parseNotifyTime(row['notify_time']);
    final when = nextOccurrence(eventDate, recurrence, notify);
    if (when == null) return;

    final scheduled = tz.TZDateTime(
      tz.local,
      when.year,
      when.month,
      when.day,
      when.hour,
      when.minute,
    );
    final match = _matchFor(recurrence);
    final body = _alarmBody(name, recurrence);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        ticker: name,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBanner: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    try {
      await _plugin.cancel(id);
      try {
        await _plugin.zonedSchedule(
          id,
          name,
          body,
          scheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          matchDateTimeComponents: match,
          payload: '$id',
        );
      } catch (_) {
        await _plugin.zonedSchedule(
          id,
          name,
          body,
          scheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: match,
          payload: '$id',
        );
      }
    } catch (e) {
      debugPrint('EventAlarms.scheduleEvent($id) failed: $e');
    }
  }

  DateTimeComponents _matchFor(String recurrence) {
    switch (recurrence) {
      case 'daily':
        return DateTimeComponents.time;
      case 'weekly':
        return DateTimeComponents.dayOfWeekAndTime;
      case 'monthly':
        return DateTimeComponents.dayOfMonthAndTime;
      case 'yearly':
      default:
        return DateTimeComponents.dateAndTime;
    }
  }

  String _alarmBody(String name, String recurrence) {
    switch (recurrence) {
      case 'daily':
        return 'Daily reminder: $name';
      case 'weekly':
        return 'Weekly reminder: $name';
      case 'monthly':
        return 'Monthly reminder: $name';
      default:
        return 'Time for $name';
    }
  }
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse('$v');
}

DateTime parseManagedEventDate(dynamic v) {
  final s = v?.toString() ?? '';
  if (s.length >= 10) {
    return DateTime.tryParse(s.substring(0, 10)) ??
        DateTime.tryParse(s) ??
        DateTime.now();
  }
  return DateTime.tryParse(s) ?? DateTime.now();
}

({int hour, int minute}) parseNotifyTime(dynamic v) {
  final s = (v?.toString() ?? '09:00').trim();
  final parts = s.split(':');
  final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 9 : 9;
  final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return (hour: h.clamp(0, 23), minute: m.clamp(0, 59));
}

String formatNotifyTime(({int hour, int minute}) t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

DateTime? nextOccurrence(
  DateTime eventDate,
  String recurrence,
  ({int hour, int minute}) notify,
) {
  final now = DateTime.now();
  DateTime at(int y, int m, int d) {
    final last = DateTime(y, m + 1, 0).day;
    final day = d.clamp(1, last);
    return DateTime(y, m, day, notify.hour, notify.minute);
  }

  switch (recurrence) {
    case 'daily':
      var c = DateTime(now.year, now.month, now.day, notify.hour, notify.minute);
      if (!c.isAfter(now)) c = c.add(const Duration(days: 1));
      return c;
    case 'weekly':
      var c = DateTime(now.year, now.month, now.day, notify.hour, notify.minute);
      for (var i = 0; i < 8; i++) {
        if (c.weekday == eventDate.weekday && c.isAfter(now)) return c;
        c = c.add(const Duration(days: 1));
      }
      return c;
    case 'monthly':
      var c = at(now.year, now.month, eventDate.day);
      if (!c.isAfter(now)) {
        final next = DateTime(now.year, now.month + 1, 1);
        c = at(next.year, next.month, eventDate.day);
      }
      return c;
    case 'yearly':
    default:
      var c = at(now.year, eventDate.month, eventDate.day);
      if (!c.isAfter(now)) {
        c = at(now.year + 1, eventDate.month, eventDate.day);
      }
      return c;
  }
}
