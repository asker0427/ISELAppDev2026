import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/config.dart';
import '../providers/providers.dart';

/// 音声入力の結果（呼び出し元に返す）。
class VoiceInputResult {
  final String title;
  final String notes;
  final DateTime? dueDate;

  const VoiceInputResult({
    required this.title,
    this.notes = '',
    this.dueDate,
  });
}

/// 音声でタスクを入力するボトムシート。
///
/// 流れ:
///   1. マイクで発話を認識（speech_to_text）
///   2. 確定テキストを Gemini で整形（タスク名・メモ・期限を抽出）
///   3. VoiceInputResult を pop で返す
class VoiceInputSheet extends ConsumerStatefulWidget {
  const VoiceInputSheet({super.key});

  @override
  ConsumerState<VoiceInputSheet> createState() => _VoiceInputSheetState();
}

enum _Phase { idle, listening, processing, done, error }

class _VoiceInputSheetState extends ConsumerState<VoiceInputSheet> {
  _Phase _phase = _Phase.idle;
  String _recognized = '';
  String _message = '';
  VoiceInputResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    ref.read(speechServiceProvider).cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final speech = ref.read(speechServiceProvider);
    final ok = await speech.init();
    if (!ok) {
      setState(() {
        _phase = _Phase.error;
        _message = 'マイクを利用できません。端末の権限設定を確認してください。';
      });
      return;
    }
    setState(() {
      _phase = _Phase.listening;
      _recognized = '';
    });
    await speech.start(
      onResult: (partial) => setState(() => _recognized = partial),
      onFinal: (text) => _onFinal(text),
    );
  }

  Future<void> _stop() async {
    await ref.read(speechServiceProvider).stop();
    if (_recognized.trim().isNotEmpty) {
      _onFinal(_recognized);
    } else if (mounted) {
      setState(() => _phase = _Phase.idle);
    }
  }

  Future<void> _onFinal(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      if (mounted) setState(() => _phase = _Phase.idle);
      return;
    }
    final gemini = ref.read(geminiServiceProvider);

    // Gemini 未設定なら、生テキストをそのままタスク名として返す。
    if (gemini == null) {
      setState(() {
        _phase = _Phase.done;
        _result = VoiceInputResult(title: trimmed);
      });
      return;
    }

    setState(() {
      _phase = _Phase.processing;
      _recognized = trimmed;
    });
    try {
      final draft = await gemini.refineVoiceInput(trimmed);
      if (!mounted) return;
      setState(() {
        _phase = _Phase.done;
        _result = VoiceInputResult(
          title: draft.title,
          notes: draft.notes,
          dueDate: draft.dueDate,
        );
      });
    } catch (e) {
      if (!mounted) return;
      // 整形に失敗しても生テキストは活かす。
      setState(() {
        _phase = _Phase.done;
        _result = VoiceInputResult(title: trimmed);
        _message = 'AI 整形に失敗したため、認識テキストをそのまま使用します。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text('音声でタスクを追加',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
            _buildBody(theme),
            const SizedBox(height: 24),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    switch (_phase) {
      case _Phase.listening:
        return Column(
          children: [
            _MicPulse(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              _recognized.isEmpty ? '聞き取り中...' : _recognized,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        );
      case _Phase.processing:
        return Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('「$_recognized」', textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('AI が整形しています...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ],
        );
      case _Phase.done:
        final r = _result!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResultRow(icon: Icons.title, label: 'タスク名', value: r.title),
            if (r.notes.isNotEmpty)
              _ResultRow(icon: Icons.notes, label: 'メモ', value: r.notes),
            if (r.dueDate != null)
              _ResultRow(
                icon: Icons.event,
                label: '期限',
                value: DateFormat('yyyy年M月d日 (E)', 'ja').format(r.dueDate!),
              ),
            if (_message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  )),
            ],
          ],
        );
      case _Phase.error:
        return Column(
          children: [
            Icon(Icons.mic_off,
                size: 40, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(_message, textAlign: TextAlign.center),
          ],
        );
      case _Phase.idle:
        return Column(
          children: [
            Icon(Icons.mic_none,
                size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            const Text('マイクをタップして話してください'),
            if (!AppConfig.isGeminiEnabled) ...[
              const SizedBox(height: 8),
              Text('（Gemini 未設定：認識テキストがそのまま入ります）',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ],
          ],
        );
    }
  }

  Widget _buildActions() {
    switch (_phase) {
      case _Phase.listening:
        return FilledButton.icon(
          onPressed: _stop,
          icon: const Icon(Icons.stop),
          label: const Text('停止して整形'),
        );
      case _Phase.done:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _start,
                child: const Text('やり直す'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_result),
                child: const Text('これで追加'),
              ),
            ),
          ],
        );
      case _Phase.processing:
        return const SizedBox.shrink();
      case _Phase.idle:
      case _Phase.error:
        return FilledButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.mic),
          label: const Text('話す'),
        );
    }
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// マイクの脈打つアニメーション。
class _MicPulse extends StatefulWidget {
  const _MicPulse({required this.color});
  final Color color;

  @override
  State<_MicPulse> createState() => _MicPulseState();
}

class _MicPulseState extends State<_MicPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final scale = 1.0 + _c.value * 0.3;
        return Container(
          width: 80 * scale,
          height: 80 * scale,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.mic, size: 36, color: widget.color),
        );
      },
    );
  }
}
