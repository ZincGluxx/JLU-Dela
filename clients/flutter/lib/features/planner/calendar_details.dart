import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/assignment.dart';
import '../../core/models/school_time.dart';
import '../../core/models/todo.dart';
import 'calendar_entries.dart';
import 'calendar_time.dart';

class CalendarEntryDetail extends StatefulWidget {
  const CalendarEntryDetail({
    super.key,
    required this.entry,
    this.onToggleTodo,
  });

  final CalendarEntry entry;
  final Future<Todo?> Function(Todo todo)? onToggleTodo;

  @override
  State<CalendarEntryDetail> createState() => _CalendarEntryDetailState();
}

class _CalendarEntryDetailState extends State<CalendarEntryDetail> {
  late Todo? _todo = widget.entry.todo;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return Padding(
      key: const Key('calendar-detail'),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.blueSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    entry.kind.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  key: const Key('calendar-detail-close'),
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              entry.title,
              key: const Key('calendar-detail-title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            ..._details(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _details(BuildContext context) {
    final entry = widget.entry;
    final lesson = entry.lesson;
    if (lesson != null) {
      final periods = _periodsLabel(lesson.periodStart, lesson.periodEnd);
      final location = lesson.location?.trim();
      return [
        _DetailRow(
          '时间',
          '${calendarDateLabel(entry.date!)} '
              '${calendarWeekdayLabel(entry.date!)} '
              '${calendarClockRangeLabel(lesson.startsAtUtc, lesson.endsAtUtc)}',
        ),
        if (location != null && location.isNotEmpty) _DetailRow('地点', location),
        if (periods != null) _DetailRow('节次', periods),
        _DetailRow('来源', '教务课表 · 只读'),
        const _DetailHint('课程来自教务课表；刷新请到「课表」页。'),
      ];
    }

    final assignment = entry.assignment;
    if (assignment != null) {
      return _assignmentDetails(assignment);
    }

    final todo = _todo;
    if (todo != null) {
      return _todoDetails(todo);
    }

    return [_DetailRow('时间', entry.timeLabel)];
  }

  List<Widget> _assignmentDetails(Assignment assignment) {
    final dueAt = assignment.dueAtUtc;
    final dueDate = assignment.dueDate;
    final timingText = assignment.timingText?.trim();
    final statusText = assignment.sourceStatusText?.trim();
    return [
      _DetailRow('截止', switch (assignment.dueKind) {
        AssignmentDueKind.exact when dueAt != null =>
          '${calendarDateLabel(schoolDateOf(dueAt))} '
              '${formatSchoolClock(dueAt)}（北京时间）',
        AssignmentDueKind.dateOnly when dueDate != null =>
          '${calendarDateLabel(dueDate)} · 全天（按校园日期）',
        _ => '截止时间待确认',
      }),
      if (timingText != null && timingText.isNotEmpty)
        _DetailRow('平台原文', timingText),
      if (assignment.dueKind == AssignmentDueKind.relative ||
          assignment.dueKind == AssignmentDueKind.unknown)
        const _DetailHint('相对时间只保留同步快照原文，不推算具体时刻。'),
      _DetailRow(
        '平台状态',
        statusText != null && statusText.isNotEmpty
            ? statusText
            : assignment.sourceStatus,
      ),
      _DetailRow('标记', assignment.readAtUtc == null ? '未读' : '已读'),
      _DetailRow('快照时间', calendarTimestampLabel(assignment.observedAtUtc)),
      _DetailRow('来源', '学习通 · 只读'),
      const _DetailHint('作业是同步快照；刷新请到「作业」页。'),
    ];
  }

  List<Widget> _todoDetails(Todo todo) {
    final dueAt = todo.dueAtUtc;
    final dueDate = todo.dueDate;
    final notes = todo.notes.trim();
    return [
      _DetailRow('截止', switch (todo.dueKind) {
        TodoDueKind.exact when dueAt != null =>
          '${calendarDateLabel(schoolDateOf(dueAt))} '
              '${formatSchoolClock(dueAt)}（北京时间）',
        TodoDueKind.dateOnly when dueDate != null =>
          '${calendarDateLabel(dueDate)} · 全天',
        _ => '未设置截止',
      }),
      _DetailRow('颜色', calendarColorLabel(todo.color)),
      _DetailRow('状态', todo.completed ? '已完成' : '未完成'),
      _DetailRow('日历', todo.showInCalendar ? '显示在日历' : '不显示在日历'),
      _DetailRow('备注', notes.isEmpty ? '无备注' : notes),
      _DetailRow('来源', '个人待办'),
      const SizedBox(height: AppSpacing.sm),
      FilledButton.tonal(
        key: const Key('calendar-todo-toggle'),
        onPressed: _saving ? null : _toggleTodo,
        child: Text(
          _saving
              ? '正在更新…'
              : todo.completed
              ? '标记为未完成'
              : '标记为完成',
        ),
      ),
      const _DetailHint('在「待办」页编辑标题、备注与截止时间；这里只切换完成状态。'),
    ];
  }

  Future<void> _toggleTodo() async {
    final callback = widget.onToggleTodo;
    final todo = _todo;
    if (callback == null || todo == null) {
      return;
    }
    setState(() => _saving = true);
    final updated = await callback(todo);
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      if (updated != null) {
        _todo = updated;
      }
    });
  }
}

String? _periodsLabel(int? start, int? end) {
  if (start == null && end == null) {
    return null;
  }
  if (start != null && end != null) {
    return '第 $start–$end 节';
  }
  return '第 ${start ?? end} 节';
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _DetailHint extends StatelessWidget {
  const _DetailHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
      ),
    );
  }
}
