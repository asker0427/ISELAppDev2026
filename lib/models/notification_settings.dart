import 'package:cloud_firestore/cloud_firestore.dart';

/// 毎日のタスク通知に関するユーザー設定。
class TaskNotificationSettings {
  const TaskNotificationSettings({
    this.enabled = true,
    this.morningHour = 8,
    this.morningMinute = 0,
    this.morningLimit = 5,
    this.noonHour = 12,
    this.noonMinute = 0,
    this.weekLimit = 5,
  });

  final bool enabled;
  final int morningHour;
  final int morningMinute;
  final int morningLimit;
  final int noonHour;
  final int noonMinute;
  final int weekLimit;

  TaskNotificationSettings copyWith({
    bool? enabled,
    int? morningHour,
    int? morningMinute,
    int? morningLimit,
    int? noonHour,
    int? noonMinute,
    int? weekLimit,
  }) {
    return TaskNotificationSettings(
      enabled: enabled ?? this.enabled,
      morningHour: morningHour ?? this.morningHour,
      morningMinute: morningMinute ?? this.morningMinute,
      morningLimit: morningLimit ?? this.morningLimit,
      noonHour: noonHour ?? this.noonHour,
      noonMinute: noonMinute ?? this.noonMinute,
      weekLimit: weekLimit ?? this.weekLimit,
    );
  }

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'morningHour': morningHour,
    'morningMinute': morningMinute,
    'morningLimit': morningLimit,
    'noonHour': noonHour,
    'noonMinute': noonMinute,
    'weekLimit': weekLimit,
    'notifySlots': enabled
        ? [
            _notificationSlot('m', morningHour, morningMinute),
            _notificationSlot('n', noonHour, noonMinute),
          ]
        : <String>[],
    'updatedAt': FieldValue.serverTimestamp(),
  };

  factory TaskNotificationSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const TaskNotificationSettings();
    int integer(String key, int fallback) =>
        data[key] is num ? (data[key] as num).toInt() : fallback;
    return TaskNotificationSettings(
      enabled: data['enabled'] as bool? ?? true,
      morningHour: integer('morningHour', 8).clamp(0, 23),
      morningMinute: integer('morningMinute', 0).clamp(0, 59),
      morningLimit: integer('morningLimit', 5).clamp(1, 20),
      noonHour: integer('noonHour', 12).clamp(0, 23),
      noonMinute: integer('noonMinute', 0).clamp(0, 59),
      weekLimit: integer('weekLimit', 5).clamp(1, 20),
    );
  }
}

String _notificationSlot(String prefix, int hour, int minute) {
  final paddedHour = hour.toString().padLeft(2, '0');
  final paddedMinute = minute.toString().padLeft(2, '0');
  return '$prefix$paddedHour:$paddedMinute';
}
