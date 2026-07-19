import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/config.dart';
import '../models/task.dart';
import '../providers/providers.dart';
import 'voice_input_sheet.dart';

/// タスク追加画面。手入力 + 音声入力 + 保存後の AI サブタスク生成。
class AddTaskScreen extends ConsumerStatefulWidget {
  const AddTaskScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends ConsumerState<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _dueDate;
  TaskPriority _priority = TaskPriority.medium;
  bool _generateSubtasks = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dueDate = widget.initialDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('ja'),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _startVoiceInput() async {
    final draft = await showModalBottomSheet<VoiceInputResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const VoiceInputSheet(),
    );
    if (draft == null || !mounted) return;
    setState(() {
      if (draft.title.isNotEmpty) _titleCtrl.text = draft.title;
      if (draft.notes.isNotEmpty) _notesCtrl.text = draft.notes;
      if (draft.dueDate != null) _dueDate = draft.dueDate;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final controller = ref.read(taskControllerProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final task = Task(
      id: '',
      title: _titleCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      dueDate: _dueDate,
      priority: _priority,
      createdAt: DateTime.now(),
    );

    try {
      final id = await controller.add(task);

      if (_generateSubtasks && AppConfig.isGeminiEnabled) {
        // 保存済みタスク（採番後の id）にサブタスクを生成・追記する。
        final count = await controller.generateSubtasks(task.withId(id));
        if (mounted && count > 0) {
          messenger.showSnackBar(
            SnackBar(content: Text('サブタスクを $count 件生成しました')),
          );
        }
      }
      navigator.pop();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('タスクを追加')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _titleCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'タスク名',
                      hintText: '例: 誕生日プレゼントを用意する',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'タスク名を入力してください'
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _startVoiceInput,
                  icon: const Icon(Icons.mic),
                  tooltip: '音声入力',
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'メモ（任意）',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(_dueDate == null
                  ? '期限を設定'
                  : DateFormat('yyyy年M月d日 (E)', 'ja').format(_dueDate!)),
              trailing: _dueDate == null
                  ? const Icon(Icons.chevron_right)
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _dueDate = null),
                    ),
              onTap: _pickDate,
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text('優先度', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<TaskPriority>(
              segments: const [
                ButtonSegment(value: TaskPriority.low, label: Text('低')),
                ButtonSegment(value: TaskPriority.medium, label: Text('中')),
                ButtonSegment(value: TaskPriority.high, label: Text('高')),
              ],
              selected: {_priority},
              onSelectionChanged: (s) => setState(() => _priority = s.first),
            ),
            const SizedBox(height: 16),
            if (AppConfig.isGeminiEnabled)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.auto_awesome),
                title: const Text('AI でサブタスクに自動分割'),
                subtitle: const Text('保存後に Gemini が実行手順を提案します'),
                value: _generateSubtasks,
                onChanged: (v) => setState(() => _generateSubtasks = v),
              )
            else
              const _GeminiDisabledHint(),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? '保存中...' : '保存する'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeminiDisabledHint extends StatelessWidget {
  const _GeminiDisabledHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'GEMINI_API_KEY 未設定のため AI 機能は無効です（README 参照）。',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
