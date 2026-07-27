import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_settings.dart';
import '../providers/providers.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  TaskNotificationSettings? _settings;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final asyncSettings = ref.watch(notificationSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('通知設定')),
      body: asyncSettings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('設定の読み込みに失敗しました\n$error')),
        data: (loaded) {
          final settings = _settings ??= loaded;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                title: const Text('毎日の通知'),
                subtitle: const Text('朝と昼にタスク一覧を通知します'),
                value: settings.enabled,
                onChanged: (value) =>
                    _change(settings.copyWith(enabled: value)),
              ),
              const Divider(),
              ListTile(
                enabled: settings.enabled,
                leading: const Icon(Icons.wb_sunny_outlined),
                title: const Text('朝の通知時刻'),
                subtitle: const Text('本日締め切りの未完了タスク'),
                trailing: Text(
                  _timeText(settings.morningHour, settings.morningMinute),
                ),
                onTap: settings.enabled
                    ? () => _pickTime(
                        settings.morningHour,
                        settings.morningMinute,
                        (time) => settings.copyWith(
                          morningHour: time.hour,
                          morningMinute: time.minute,
                        ),
                      )
                    : null,
              ),
              _LimitTile(
                enabled: settings.enabled,
                title: '朝に表示する上限',
                value: settings.morningLimit,
                onChanged: (value) =>
                    _change(settings.copyWith(morningLimit: value)),
              ),
              const Divider(),
              ListTile(
                enabled: settings.enabled,
                leading: const Icon(Icons.light_mode_outlined),
                title: const Text('昼の通知時刻'),
                subtitle: const Text('今後7日間を優先度順、同じなら締切順'),
                trailing: Text(
                  _timeText(settings.noonHour, settings.noonMinute),
                ),
                onTap: settings.enabled
                    ? () => _pickTime(
                        settings.noonHour,
                        settings.noonMinute,
                        (time) => settings.copyWith(
                          noonHour: time.hour,
                          noonMinute: time.minute,
                        ),
                      )
                    : null,
              ),
              _LimitTile(
                enabled: settings.enabled,
                title: '昼に表示する件数',
                value: settings.weekLimit,
                onChanged: (value) =>
                    _change(settings.copyWith(weekLimit: value)),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : () => _save(settings),
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('設定を保存'),
              ),
              const SizedBox(height: 12),
              Text(
                '表示上限を超えた朝のタスクは「ほか ○ 件」とまとめて表示します。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }

  void _change(TaskNotificationSettings settings) {
    setState(() => _settings = settings);
  }

  Future<void> _pickTime(
    int hour,
    int minute,
    TaskNotificationSettings Function(TimeOfDay) update,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
    );
    if (picked != null) _change(update(picked));
  }

  Future<void> _save(TaskNotificationSettings settings) async {
    setState(() => _saving = true);
    try {
      await ref.read(notificationSettingsControllerProvider).save(settings);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('通知設定を保存しました')));
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _timeText(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class _LimitTile extends StatelessWidget {
  const _LimitTile({
    required this.enabled,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final bool enabled;
  final String title;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: enabled,
      title: Text(title),
      trailing: DropdownButton<int>(
        value: value,
        onChanged: enabled
            ? (next) {
                if (next != null) onChanged(next);
              }
            : null,
        items: List.generate(
          20,
          (index) =>
              DropdownMenuItem(value: index + 1, child: Text('${index + 1} 件')),
        ),
      ),
    );
  }
}
