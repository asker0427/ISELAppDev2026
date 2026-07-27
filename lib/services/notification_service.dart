import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/notification_settings.dart';
import '../models/task.dart';

final taskNotificationsPlugin = FlutterLocalNotificationsPlugin();

class TaskNotificationService {
  TaskNotificationService(this._plugin);

  static const _firstId = 41000;
  static const _daysToSchedule = 30;
  static const androidChannel = AndroidNotificationChannel(
    'daily_task_summary',
    'タスクのデイリー通知',
    description: '本日締切と今後1週間のタスクを通知します',
    importance: Importance.high,
  );
  static const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_task_summary',
      'タスクのデイリー通知',
      channelDescription: '本日締切と今後1週間のタスクを通知します',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
    ),
    iOS: DarwinNotificationDetails(),
  );

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> initialize() async {
    tz.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone.identifier));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: settings);

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(androidChannel);
    await android?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> reschedule(
    List<Task> tasks,
    TaskNotificationSettings settings,
  ) async {
    if (kIsWeb) return;
    for (var i = 0; i < _daysToSchedule * 2; i++) {
      await _plugin.cancel(id: _firstId + i);
    }
    if (!settings.enabled) return;

    final now = tz.TZDateTime.now(tz.local);
    final today = tz.TZDateTime(tz.local, now.year, now.month, now.day);
    for (var offset = 0; offset < _daysToSchedule; offset++) {
      final day = today.add(Duration(days: offset));
      final morning = tz.TZDateTime(
        tz.local,
        day.year,
        day.month,
        day.day,
        settings.morningHour,
        settings.morningMinute,
      );
      final noon = tz.TZDateTime(
        tz.local,
        day.year,
        day.month,
        day.day,
        settings.noonHour,
        settings.noonMinute,
      );
      if (morning.isAfter(now)) {
        final dueToday = tasksDueOn(tasks, day);
        await _schedule(
          _firstId + offset * 2,
          morning,
          '本日締め切りのタスク',
          formatTaskList(dueToday, settings.morningLimit),
        );
      }
      if (noon.isAfter(now)) {
        final comingWeek = priorityTasksForWeek(tasks, day);
        await _schedule(
          _firstId + offset * 2 + 1,
          noon,
          '今後1週間の優先タスク',
          formatTaskList(comingWeek, settings.weekLimit, showDueDate: true),
        );
      }
    }
  }

  Future<void> _schedule(int id, tz.TZDateTime at, String title, String body) {
    return _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: at,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'task-summary',
    );
  }
}

List<Task> tasksDueOn(List<Task> tasks, DateTime day) {
  final result = tasks.where((task) {
    final due = task.dueDate;
    return !task.done &&
        due != null &&
        due.year == day.year &&
        due.month == day.month &&
        due.day == day.day;
  }).toList();
  result.sort((a, b) => b.priority.index.compareTo(a.priority.index));
  return result;
}

List<Task> priorityTasksForWeek(List<Task> tasks, DateTime start) {
  final from = DateTime(start.year, start.month, start.day);
  final until = from.add(const Duration(days: 7));
  final result = tasks.where((task) {
    final due = task.dueDate;
    if (task.done || due == null) return false;
    final date = DateTime(due.year, due.month, due.day);
    return !date.isBefore(from) && date.isBefore(until);
  }).toList();
  result.sort((a, b) {
    final priority = b.priority.index.compareTo(a.priority.index);
    if (priority != 0) return priority;
    return a.dueDate!.compareTo(b.dueDate!);
  });
  return result;
}

String formatTaskList(List<Task> tasks, int limit, {bool showDueDate = false}) {
  if (tasks.isEmpty) return '該当する未完了タスクはありません';
  final visible = tasks
      .take(limit)
      .map((task) {
        final due = showDueDate && task.dueDate != null
            ? '（${DateFormat('M/d').format(task.dueDate!)}）'
            : '';
        return '・${task.title}$due';
      })
      .join('\n');
  final remaining = tasks.length - limit;
  return remaining > 0 ? '$visible\nほか $remaining 件' : visible;
}
