import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';

import '../core/config.dart';

/// 音声入力から整形されたタスク下書き。
class VoiceTaskDraft {
  final String title;
  final String notes;
  final DateTime? dueDate;

  const VoiceTaskDraft({
    required this.title,
    this.notes = '',
    this.dueDate,
  });
}

/// Gemini を使った AI 機能。
/// - タスクのサブタスク分割
/// - 音声入力テキストの整形
class GeminiService {
  GeminiService._(this._model);

  final GenerativeModel _model;

  /// 設定済みならインスタンスを返す。未設定なら null。
  static GeminiService? create() {
    if (!AppConfig.isGeminiEnabled) return null;
    final model = GenerativeModel(
      model: AppConfig.geminiModel,
      apiKey: AppConfig.geminiApiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.4,
      ),
    );
    return GeminiService._(model);
  }

  /// タスクを実行可能なサブタスクに分割する。
  /// 失敗時は空リストを返す（呼び出し側でハンドリング）。
  Future<List<String>> splitIntoSubtasks(
    String title, {
    String notes = '',
  }) async {
    final prompt = '''
あなたは優秀なタスク管理アシスタントです。
以下のタスクを、実行可能な具体的なサブタスクに分割してください。

タスク: $title
${notes.isNotEmpty ? '補足: $notes' : ''}

制約:
- 3〜7個程度
- 各サブタスクは短い動詞句（例: 「資料を集める」）
- 実行順に並べる
- 日本語で

次の JSON 形式のみを出力してください:
{"subtasks": ["...", "..."]}
''';

    final res = await _model.generateContent([Content.text(prompt)]);
    final json = _decode(res.text);
    final list = json?['subtasks'];
    if (list is! List) return const [];
    return list
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// 音声認識で得た生テキストを、きれいなタスクに整形する。
  /// [now] は日付表現（「明日」など）の基準日時。
  Future<VoiceTaskDraft> refineVoiceInput(
    String rawText, {
    DateTime? now,
  }) async {
    final base = now ?? DateTime.now();
    final today = base.toIso8601String().split('T').first;
    final prompt = '''
音声認識で入力された次の発話を、TODO タスクに整形してください。
発話: "$rawText"

今日の日付: $today

制約:
- title は簡潔なタスク名（句読点や冗長な言い回しを除く）
- notes には補足があれば入れる（無ければ空文字）
- 「明日」「来週月曜」などの日付表現があれば dueDate に "YYYY-MM-DD" で。無ければ null
- 日本語で

次の JSON 形式のみを出力してください:
{"title": "...", "notes": "...", "dueDate": "YYYY-MM-DD" または null}
''';

    final res = await _model.generateContent([Content.text(prompt)]);
    final json = _decode(res.text);
    final title = (json?['title'] as String?)?.trim();
    return VoiceTaskDraft(
      title: (title == null || title.isEmpty) ? rawText.trim() : title,
      notes: (json?['notes'] as String?)?.trim() ?? '',
      dueDate: _parseDate(json?['dueDate']),
    );
  }

  Map<String, dynamic>? _decode(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    try {
      // responseMimeType=json でも稀にコードフェンスが付くため除去する。
      final cleaned = text
          .replaceAll(RegExp(r'```json|```'), '')
          .trim();
      final decoded = jsonDecode(cleaned);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty || value == 'null') return null;
    return DateTime.tryParse(value);
  }
}
