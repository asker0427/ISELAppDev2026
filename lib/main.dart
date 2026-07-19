import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 日本語の日付フォーマット（曜日表示など）を初期化。
  await initializeDateFormatting('ja');

  // Firebase を初期化。firebase_options.dart がプレースホルダーのまま
  // （apiKey が 'REPLACE_ME'）なら初期化せず、設定案内画面を表示する。
  // flutterfire configure 実行後は実キーに置き換わり、この判定を自動で抜ける。
  var firebaseReady = false;
  final options = DefaultFirebaseOptions.currentPlatform;
  if (options.apiKey != 'REPLACE_ME') {
    try {
      await Firebase.initializeApp(options: options);
      firebaseReady = true;
    } catch (e, st) {
      debugPrint('Firebase 初期化に失敗しました: $e\n$st');
    }
  }

  runApp(
    ProviderScope(
      child: TodoApp(firebaseReady: firebaseReady),
    ),
  );
}
