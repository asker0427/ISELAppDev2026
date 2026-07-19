import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/task.dart';
import '../providers/providers.dart';
import '../widgets/task_tile.dart';
import 'add_task_screen.dart';
import 'task_detail_screen.dart';

/// メイン画面：カレンダー + 選択日のタスク一覧。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  CalendarFormat _format = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasksAsync = ref.watch(tasksProvider);
    final selectedDay = ref.watch(selectedDayProvider);
    final tasksByDay = ref.watch(tasksByDayProvider);
    final dayTasks = ref.watch(tasksForSelectedDayProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('カレンダー TODO'),
        actions: [
          IconButton(
            tooltip: 'ログアウト',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('タスクの読み込みに失敗しました:\n$e',
                textAlign: TextAlign.center),
          ),
        ),
        data: (_) => Column(
          children: [
            Card(
              margin: const EdgeInsets.all(12),
              child: TableCalendar<Task>(
                locale: 'ja_JP',
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2035, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _format,
                availableCalendarFormats: const {
                  CalendarFormat.month: '月',
                  CalendarFormat.twoWeeks: '2週',
                  CalendarFormat.week: '週',
                },
                selectedDayPredicate: (day) =>
                    isSameDay(selectedDay, day),
                eventLoader: (day) {
                  final key = DateTime(day.year, day.month, day.day);
                  return tasksByDay[key] ?? const [];
                },
                onDaySelected: (selected, focused) {
                  ref.read(selectedDayProvider.notifier).state = DateTime(
                      selected.year, selected.month, selected.day);
                  setState(() => _focusedDay = focused);
                },
                onFormatChanged: (f) => setState(() => _format = f),
                onPageChanged: (focused) => _focusedDay = focused,
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                  markersMaxCount: 4,
                ),
                headerStyle: const HeaderStyle(
                  formatButtonShowsNext: false,
                  titleCentered: true,
                ),
              ),
            ),
            _DayHeader(day: selectedDay, count: dayTasks.length),
            Expanded(
              child: dayTasks.isEmpty
                  ? _EmptyDay(day: selectedDay)
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: dayTasks.length,
                      itemBuilder: (context, i) {
                        final task = dayTasks[i];
                        return TaskTile(
                          task: task,
                          onToggleDone: (v) => ref
                              .read(taskControllerProvider)
                              .setDone(task.id, v),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  TaskDetailScreen(taskId: task.id),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddTaskScreen(initialDate: selectedDay),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('タスク追加'),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.count});
  final DateTime day;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          Text(
            DateFormat('M月d日 (E)', 'ja').format(day),
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Text('$count 件',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_available,
              size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('この日のタスクはありません',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
        ],
      ),
    );
  }
}
