/// アプリ全体の設定値。
///
/// Gemini API キーはソースにハードコードせず、実行時に --dart-define で渡す。
///   flutter run --dart-define=GEMINI_API_KEY=xxxxx
/// 未設定でもビルドは通り、Gemini 機能だけが無効化される。
class AppConfig {
  const AppConfig._();

  /// Gemini(Generative Language) API キー。
  static const String geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  /// 使用する Gemini モデル名。
  static const String geminiModel =
      String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-1.5-flash');

  /// Gemini が利用可能か（キーが設定されているか）。
  static bool get isGeminiEnabled => geminiApiKey.isNotEmpty;
}
