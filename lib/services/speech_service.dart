import 'package:speech_to_text/speech_to_text.dart';

/// 端末の音声認識（speech_to_text）のラッパー。
///
/// iOS では Info.plist に NSSpeechRecognitionUsageDescription /
/// NSMicrophoneUsageDescription が、Android では RECORD_AUDIO 権限が必要。
/// 手順は README を参照。
class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _available = false;

  bool get isListening => _speech.isListening;

  /// 認識エンジンを初期化し、利用可否を返す。
  Future<bool> init({void Function(String status)? onStatus}) async {
    _available = await _speech.initialize(
      onStatus: (s) => onStatus?.call(s),
      onError: (e) => onStatus?.call('error: ${e.errorMsg}'),
    );
    return _available;
  }

  /// 音声認識を開始する。[onResult] は途中経過も含めて呼ばれる。
  /// [onFinal] は確定テキストで一度だけ呼ばれる。
  Future<void> start({
    required void Function(String partial) onResult,
    required void Function(String finalText) onFinal,
    String localeId = 'ja_JP',
  }) async {
    if (!_available) {
      _available = await init();
      if (!_available) return;
    }
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        localeId: localeId,
      ),
      onResult: (result) {
        onResult(result.recognizedWords);
        if (result.finalResult) {
          onFinal(result.recognizedWords);
        }
      },
    );
  }

  Future<void> stop() => _speech.stop();
  Future<void> cancel() => _speech.cancel();
}
