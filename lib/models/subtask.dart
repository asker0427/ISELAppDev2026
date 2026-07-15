/// タスクを構成するサブタスク（Gemini により自動分割される要素）。
class SubTask {
  final String id;
  final String title;
  final bool done;

  const SubTask({
    required this.id,
    required this.title,
    this.done = false,
  });

  SubTask copyWith({String? title, bool? done}) {
    return SubTask(
      id: id,
      title: title ?? this.title,
      done: done ?? this.done,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'done': done,
      };

  factory SubTask.fromMap(Map<String, dynamic> map) => SubTask(
        id: (map['id'] ?? '') as String,
        title: (map['title'] ?? '') as String,
        done: (map['done'] ?? false) as bool,
      );
}
