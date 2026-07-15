import 'package:cloud_firestore/cloud_firestore.dart';

import 'subtask.dart';

/// タスクの優先度。
enum TaskPriority {
  low,
  medium,
  high;

  String get label => switch (this) {
        TaskPriority.low => '低',
        TaskPriority.medium => '中',
        TaskPriority.high => '高',
      };
}

/// TODO タスク本体。Firestore の 1 ドキュメントに対応する。
class Task {
  final String id;
  final String title;
  final String notes;
  final DateTime? dueDate;
  final bool done;
  final TaskPriority priority;
  final List<SubTask> subtasks;
  final DateTime createdAt;

  const Task({
    required this.id,
    required this.title,
    this.notes = '',
    this.dueDate,
    this.done = false,
    this.priority = TaskPriority.medium,
    this.subtasks = const [],
    required this.createdAt,
  });

  /// 採番後の id を差し替えた複製を返す（Firestore add 後に使う）。
  Task withId(String newId) => Task(
        id: newId,
        title: title,
        notes: notes,
        dueDate: dueDate,
        done: done,
        priority: priority,
        subtasks: subtasks,
        createdAt: createdAt,
      );

  /// サブタスクの完了進捗（0.0〜1.0）。サブタスクが無ければ done を反映。
  double get progress {
    if (subtasks.isEmpty) return done ? 1.0 : 0.0;
    final completed = subtasks.where((s) => s.done).length;
    return completed / subtasks.length;
  }

  Task copyWith({
    String? title,
    String? notes,
    DateTime? dueDate,
    bool? done,
    TaskPriority? priority,
    List<SubTask>? subtasks,
    bool clearDueDate = false,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      done: done ?? this.done,
      priority: priority ?? this.priority,
      subtasks: subtasks ?? this.subtasks,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'notes': notes,
        'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
        'done': done,
        'priority': priority.name,
        'subtasks': subtasks.map((s) => s.toMap()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory Task.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Task(
      id: doc.id,
      title: (data['title'] ?? '') as String,
      notes: (data['notes'] ?? '') as String,
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      done: (data['done'] ?? false) as bool,
      priority: TaskPriority.values.firstWhere(
        (p) => p.name == data['priority'],
        orElse: () => TaskPriority.medium,
      ),
      subtasks: ((data['subtasks'] ?? const []) as List)
          .whereType<Map<String, dynamic>>()
          .map(SubTask.fromMap)
          .toList(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
