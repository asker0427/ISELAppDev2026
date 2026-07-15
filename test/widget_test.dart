// カレンダー TODO アプリの基本的なスモークテスト。
//
// Firebase 未設定時は設定案内画面が表示されることを確認する。

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/app.dart';

void main() {
  testWidgets('Firebase 未設定時は設定案内画面が表示される',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TodoApp(firebaseReady: false));

    expect(find.byType(FirebaseSetupScreen), findsOneWidget);
    expect(find.text('Firebase の設定が必要です'), findsOneWidget);
  });
}
