import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/config.dart';
import '../models/task.dart';
import '../providers/providers.dart';

/// タスク詳細画面。サブタスクのチェック、AI 分割、期限編集、削除。
class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  bool _generating = false;

  Task? _find(List<Task> tasks) {
    for (final t in tasks) {
      if (t.id == widget.taskId) return t;
    }
    return null;
  }

  Future<void> _generateSubtasks(Task task) async {
    setState(() => _generating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count =
          await ref.read(taskControllerProvider).generateSubtasks(task);
      messenger.showSnackBar(SnackBar(
        content: Text(count > 0
            ? 'サブタスクを $count 件生成しました'
            : 'サブタスクを生成できませんでした'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('生成に失敗しました: $e')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _pickDue(Task task) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: task.dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('ja'),
    );
    if (picked != null) {
      await ref.read(taskControllerProvider).update(task.copyWith(dueDate: picked));
    }
  }

  Future<void> _confirmDelete(Task task) async {
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('タスクを削除'),
        content: Text('「${task.title}」を削除しますか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('削除')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(taskControllerProvider).delete(task.id);
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasks = ref.watch(tasksProvider).value ?? const [];
    final task = _find(tasks);

    if (task == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('タスクが見つかりません')),
      );
    }

    final controller = ref.read(taskControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('タスクの詳細'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '削除',
            onPressed: () => _confirmDelete(task),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Checkbox(
                value: task.done,
                shape: const CircleBorder(),
                onChanged: (v) => controller.setDone(task.id, v ?? false),
              ),
              Expanded(
                child: Text(
                  task.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    decoration:
                        task.done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
          if (task.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(task.notes, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.event, size: 18),
                label: Text(task.dueDate == null
                    ? '期限なし'
                    : DateFormat('M月d日(E)', 'ja').format(task.dueDate!)),
                onPressed: () => _pickDue(task),
              ),
              Chip(
                avatar: const Icon(Icons.flag, size: 18),
                label: Text('優先度: ${task.priority.label}'),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              Text('サブタスク',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (task.subtasks.isNotEmpty)
                Text('${task.subtasks.where((s) => s.done).length}/${task.subtasks.length}',
                    style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          if (task.subtasks.isEmpty)
            _NoSubtasks(
              geminiEnabled: AppConfig.isGeminiEnabled,
              generating: _generating,
              onGenerate: () => _generateSubtasks(task),
            )
          else ...[
            ...task.subtasks.map((s) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: s.done,
                  title: Text(
                    s.title,
                    style: TextStyle(
                      decoration:
                          s.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  onChanged: (_) => controller.toggleSubtask(task, s.id),
                )),
            const SizedBox(height: 8),
            if (AppConfig.isGeminiEnabled)
              OutlinedButton.icon(
                onPressed:
                    _generating ? null : () => _generateSubtasks(task),
                icon: _generating
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: const Text('AI で作り直す'),
              ),
          ],
        ],
      ),
    );
  }
}

class _NoSubtasks extends StatelessWidget {
  const _NoSubtasks({
    required this.geminiEnabled,
    required this.generating,
    required this.onGenerate,
  });
  final bool geminiEnabled;
  final bool generating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.auto_awesome,
              color: theme.colorScheme.primary, size: 32),
          const SizedBox(height: 12),
          Text(
            geminiEnabled
                ? 'このタスクを AI で実行手順に分割できます'
                : 'サブタスクはまだありません',
            textAlign: TextAlign.center,
          ),
          if (geminiEnabled) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: generating ? null : onGenerate,
              icon: generating
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(generating ? '生成中...' : 'AI でサブタスク分割'),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text('GEMINI_API_KEY を設定すると利用できます（README 参照）',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ],
        ],
      ),
    );
  }
}
