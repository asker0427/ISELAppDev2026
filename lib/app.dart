import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'providers/providers.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

/// アプリのルート。[firebaseReady] が false のときは設定手順を表示する。
class TodoApp extends StatelessWidget {
  const TodoApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'カレンダー TODO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ja'), Locale('en')],
      locale: const Locale('ja'),
      home: firebaseReady
          ? const _AuthGate()
          : const FirebaseSetupScreen(),
    );
  }
}

/// 認証状態に応じてログイン画面 / ホーム画面を出し分ける。
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('認証エラー: $e')),
      ),
      data: (user) =>
          user == null ? const LoginScreen() : const HomeScreen(),
    );
  }
}

/// Firebase 未設定時に表示する案内画面。
class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.settings_suggest,
                      size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Firebase の設定が必要です',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    'ログイン・データ保存には Firebase プロジェクトの接続が必要です。'
                    '以下を実行して firebase_options.dart を生成してください。',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  const _CodeBlock(
                    'dart pub global activate flutterfire_cli\n'
                    'flutterfire configure',
                  ),
                  const SizedBox(height: 16),
                  Text('詳細な手順は README.md を参照してください。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock(this.code);
  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: SelectableText(
        code,
        style: const TextStyle(fontFamily: 'monospace', height: 1.5),
      ),
    );
  }
}
