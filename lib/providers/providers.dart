import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // StateProvider (Riverpod 3.x)

import '../models/subtask.dart';
import '../models/task.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/gemini_service.dart';
import '../services/speech_service.dart';

// ---- サービス ----

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(FirebaseAuth.instance);
});

/// Gemini。未設定なら null。
final geminiServiceProvider = Provider<GeminiService?>((ref) {
  return GeminiService.create();
});

final speechServiceProvider = Provider<SpeechService>((ref) {
  return SpeechService();
});

// ---- 認証状態 ----

/// ログインユーザーの状態ストリーム。
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

// ---- Firestore（ログイン中のみ有効） ----

/// 現在のユーザー向け FirestoreService。未ログインなら null。
final firestoreServiceProvider = Provider<FirestoreService?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return FirestoreService(FirebaseFirestore.instance, user.uid);
});

/// タスク一覧のリアルタイムストリーム。
final tasksProvider = StreamProvider<List<Task>>((ref) {
  final fs = ref.watch(firestoreServiceProvider);
  if (fs == null) return Stream.value(const []);
  return fs.watchTasks();
});

// ---- カレンダー選択日 ----

/// カレンダーで選択中の日付（時刻は無視して日付単位で扱う）。
final selectedDayProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// 日付 → その日が期限のタスク一覧（カレンダーのマーカー用）。
final tasksByDayProvider = Provider<Map<DateTime, List<Task>>>((ref) {
  final tasks = ref.watch(tasksProvider).value ?? const [];
  final map = <DateTime, List<Task>>{};
  for (final t in tasks) {
    final d = t.dueDate;
    if (d == null) continue;
    final key = DateTime(d.year, d.month, d.day);
    map.putIfAbsent(key, () => []).add(t);
  }
  return map;
});

/// 選択中の日付に期限があるタスク。
final tasksForSelectedDayProvider = Provider<List<Task>>((ref) {
  final selected = ref.watch(selectedDayProvider);
  final byDay = ref.watch(tasksByDayProvider);
  final key = DateTime(selected.year, selected.month, selected.day);
  return byDay[key] ?? const [];
});

// ---- タスク操作（Controller） ----

/// タスクの CRUD と AI 操作をまとめる。
final taskControllerProvider = Provider<TaskController>((ref) {
  return TaskController(ref);
});

class TaskController {
  TaskController(this._ref);
  final Ref _ref;

  FirestoreService get _fs {
    final fs = _ref.read(firestoreServiceProvider);
    if (fs == null) {
      throw StateError('ログインしていません。');
    }
    return fs;
  }

  Future<String> add(Task task) => _fs.addTask(task);
  Future<void> update(Task task) => _fs.updateTask(task);
  Future<void> delete(String id) => _fs.deleteTask(id);
  Future<void> setDone(String id, bool done) => _fs.setDone(id, done);

  /// サブタスクの done を切り替えて保存する。
  Future<void> toggleSubtask(Task task, String subtaskId) {
    final updated = task.subtasks
        .map((s) => s.id == subtaskId ? s.copyWith(done: !s.done) : s)
        .toList();
    return _fs.updateTask(task.copyWith(subtasks: updated));
  }

  /// Gemini でサブタスクを生成し、タスクに追加保存する。
  /// 戻り値は生成できた件数（0 なら未生成）。
  Future<int> generateSubtasks(Task task) async {
    final gemini = _ref.read(geminiServiceProvider);
    if (gemini == null) return 0;
    final titles = await gemini.splitIntoSubtasks(task.title, notes: task.notes);
    if (titles.isEmpty) return 0;
    final subtasks = [
      for (final title in titles)
        SubTask(id: _genId(), title: title),
    ];
    await _fs.updateTask(task.copyWith(subtasks: subtasks));
    return subtasks.length;
  }

  String _genId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
  int _counter = 0;
}
