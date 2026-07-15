# カレンダー TODO アプリ

Flutter 製の TODO アプリです。カレンダー表示・Firebase 認証/データベース・
Gemini による AI サブタスク分割・音声入力に対応しています。

## 主な機能

- 📅 **カレンダー表示** — 月/2週/週で切り替え、期限のある日にマーカー表示（`table_calendar`）
- ✅ **タスク管理** — 追加/編集/削除、完了チェック、優先度、期限、メモ
- 🌲 **サブタスク** — 進捗バー付き。個別にチェック可能
- 🔐 **ログイン** — Firebase Authentication（メール/パスワード）
- ☁️ **データ同期** — Cloud Firestore にユーザー単位で永続化・リアルタイム反映
- ✨ **AI サブタスク分割** — Gemini がタスクを実行手順に自動分割
- 🎤 **音声入力** — 話した内容を音声認識し、Gemini がタスク名・期限に整形

## アーキテクチャ

状態管理は **Riverpod**。レイヤ構成は以下の通り。

```
lib/
├── main.dart                  # エントリ。Firebase 初期化 + ロケール初期化
├── app.dart                   # ルート。認証ゲート / Firebase 未設定案内
├── firebase_options.dart      # ⚠️ プレースホルダー（flutterfire configure で生成）
├── core/
│   ├── config.dart            # Gemini APIキー等の設定（dart-define）
│   └── theme.dart             # Material3 テーマ
├── models/
│   ├── task.dart              # タスク（Firestore シリアライズ）
│   └── subtask.dart           # サブタスク
├── services/
│   ├── auth_service.dart      # Firebase Auth ラッパー
│   ├── firestore_service.dart # Firestore CRUD
│   ├── gemini_service.dart    # Gemini（サブタスク分割 / 音声整形）
│   └── speech_service.dart    # 端末の音声認識
├── providers/
│   └── providers.dart         # Riverpod プロバイダー群 + TaskController
└── screens/
    ├── login_screen.dart
    ├── home_screen.dart       # カレンダー + 当日タスク一覧
    ├── add_task_screen.dart   # タスク追加（音声入力ボタン）
    ├── task_detail_screen.dart# 詳細・サブタスク・AI 分割
    └── voice_input_sheet.dart # 音声入力ボトムシート
```

> **未設定でも起動します。** Firebase 未設定なら設定案内画面、Gemini 未設定なら
> AI 機能だけが無効になり、それ以外は動作します。

---

## セットアップ

### 1. 依存関係の取得

```bash
flutter pub get
```

### 2. Firebase セットアップ（ログイン・DB に必須）

1. [Firebase コンソール](https://console.firebase.google.com/) でプロジェクトを作成
2. FlutterFire CLI で構成ファイルを生成:

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

   → `lib/firebase_options.dart`（プレースホルダー）が実際の値で上書きされ、
   iOS の `GoogleService-Info.plist` / Android の `google-services.json` も配置されます。
3. Firebase コンソールで以下を有効化:
   - **Authentication** → ログイン方法 → **メール/パスワード** を有効化
   - **Firestore Database** → データベースを作成
4. Firestore セキュリティルール（本人のデータのみ許可）:

   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId}/tasks/{taskId} {
         allow read, write: if request.auth != null
                            && request.auth.uid == userId;
       }
     }
   }
   ```

### 3. Gemini API キー（AI 機能に必須）

1. [Google AI Studio](https://aistudio.google.com/app/apikey) で API キーを取得
2. 実行時に `--dart-define` で渡す（ソースにキーを埋め込まないため）:

   ```bash
   flutter run --dart-define=GEMINI_API_KEY=あなたのキー
   ```

   モデルを変える場合は `--dart-define=GEMINI_MODEL=gemini-1.5-pro` も指定可。

### 4. 実行

```bash
# iOS シミュレータ / Android エミュレータ / 実機
flutter run --dart-define=GEMINI_API_KEY=あなたのキー
```

VS Code を使う場合は `.vscode/launch.json` の `args` に
`--dart-define=GEMINI_API_KEY=...` を追加すると便利です。

---

## プラットフォーム別メモ

- **対象**: iOS / Android（音声認識が最も安定するため）
- **iOS**: 音声入力にマイク/音声認識の権限説明を `ios/Runner/Info.plist` に設定済み。
  CocoaPods 未導入なら `sudo gem install cocoapods` が必要。
- **Android**: `RECORD_AUDIO` 権限と音声認識サービスの `queries` を設定済み。
  Firebase 利用時、`android/app/build.gradle.kts` の `minSdk` は 23 以上を推奨。

## 既知の前提・制限

- `firebase_options.dart` は**プレースホルダー**です。`flutterfire configure` を
  実行するまで、アプリは Firebase 設定案内画面を表示します。
- 音声認識は端末の OS 機能を利用します。エミュレータでは動作しないことがあります（実機推奨）。
- Gemini 応答は JSON で受け取り、失敗時は認識テキストをそのまま利用するフォールバックあり。

## 動作確認

```bash
flutter analyze lib test   # 静的解析
flutter test               # スモークテスト
```
