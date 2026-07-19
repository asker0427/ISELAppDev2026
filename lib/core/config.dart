/// アプリ全体の設定値。
///
/// Gemini API キーはソースにハードコードせず、実行時に --dart-define で渡す。
///   flutter run --dart-define=GEMINI_API_KEY=xxxxx
/// 未設定でもビルドは通り、Gemini 機能だけが無効化される。
import 'package:firebase_remote_config/firebase_remote_config.dart';
class AppConfig {
  const AppConfig._();

  /// Gemini(Generative Language) API キー。
  static String get geminiApiKey {
    return FirebaseRemoteConfig.instance.getString('GEMINI_API_KEY');
  }

  /// 使用する Gemini モデル名。
  static const String geminiModel =
        String.fromEnvironment('GEMINI_MODEL',
  defaultValue: 'gemini-3-flash-preview');

    static bool get isGeminiEnabled =>
  geminiApiKey.isNotEmpty;
  }
