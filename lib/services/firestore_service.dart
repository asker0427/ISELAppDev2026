import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/task.dart';

/// Firestore のタスク永続化ラッパー。
///
/// データ構造:
///   users/{uid}/tasks/{taskId}
class FirestoreService {
  FirestoreService(this._db, this.uid);

  final FirebaseFirestore _db;
  final String uid;

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _db.collection('users').doc(uid).collection('tasks');

  /// タスク一覧をリアルタイム購読する（作成日時の降順）。
  Stream<List<Task>> watchTasks() {
    return _tasks
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Task.fromDoc).toList());
  }

  Future<String> addTask(Task task) async {
    final ref = await _tasks.add(task.toMap());
    return ref.id;
  }

  Future<void> updateTask(Task task) {
    return _tasks.doc(task.id).set(task.toMap());
  }

  Future<void> deleteTask(String taskId) {
    return _tasks.doc(taskId).delete();
  }

  Future<void> setDone(String taskId, bool done) {
    return _tasks.doc(taskId).update({'done': done});
  }
}
