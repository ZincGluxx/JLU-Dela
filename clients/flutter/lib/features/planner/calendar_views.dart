import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/local_date.dart';
import '../../core/models/todo.dart';
import 'calendar_entries.dart';
import 'calendar_grid.dart';
import 'calendar_time.dart';

/// 周视图的「时段行 × 7 日列」结构移植自
/// `codex/E02-calendar-aggregation` 的 `planner_page.dart`（GPL-3.0-or-later），
/// 数据来源改为本地 SQLite。

class CalendarTone {
  const CalendarTone(this.background, this.foreground);

  final Color background;
  final Color foreground;

  static const lesson = CalendarTone(Color(0xFFE8F0FD), Color(0xFF2A5DA8));
  static const assignment = CalendarTone(Color(0xFFFBEFE3), Color(0xFF8A5227));

  static CalendarTone of(CalendarEntry entry) {
    return switch (entry.kind) {
      CalendarEntryKind.lesson => lesson,
      CalendarEntryKind.assignment => assignment,
      CalendarEntryKind.todo => forTodoColor(entry.todo?.color),
    };
  }

  static CalendarTone forTodoColor(CalendarColor? color) {
    return switch (color) {
      CalendarColor.rose => const CalendarTone(
        Color(0xFFFBE9EC),
        Color(0xFF8A3448),
      ),
      CalendarColor.peach => const CalendarTone(
        Color(0xFFFBEFE3),
        Color(0xFF8A5227),
      ),
      CalendarColor.sand => const CalendarTone(
        Color(0xFFFBF3DE),
        Color(0xFF7A6122),
      ),
      CalendarColor.sage => const CalendarTone(
        Color(0xFFE9F5EC),
        Color(0xFF2F6B45),
      ),
      CalendarColor.teal => const CalendarTone(
        Color(0xFFE4F4F6),
        Color(0xFF1F6673),
      ),
      CalendarColor.blue => const CalendarTone(
        Color(0xFFE8F0FD),
        Color(0xFF2A5DA8),
      ),
      CalendarColor.lilac => const CalendarTone(
        Color(0xFFF2EBFA),
        Color(0xFF65418F),
      ),
      CalendarColor.slate ||
      null => const CalendarTone(Color(0xFFEDEEF1), Color(0xFF474B54)),
    };
  }
}

class CalendarEntryCard extends StatelessWidget {
  const CalendarEntryCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.compact = false,
  });

  final CalendarEntry entry;
  final ValueChanged<CalendarEntry> onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tone = CalendarTone.of(entry);
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: tone.foreground,
      decoration: entry.completed ? TextDecoration.lineThrough : null,
    );
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: entry.semanticsLabel,
      child: Material(
        color: tone.background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: Key('calendar-entry-${entry.id}'),
          borderRadius: BorderRadius.circular(10),
          onTap: () => onTap(entry),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: compact ? AppSpacing.xs : AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  entry.timeLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle?.copyWith(
                    fontSize: 11,
                    color: tone.foreground.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CalendarWeekGrid extends StatelessWidget {
  const CalendarWeekGrid({
    super.key,
    required this.week,
    required this.today,
    required this.onTap,
  });

  final CalendarWeek week;
  final LocalDate today;
  final ValueChanged<CalendarEntry> onTap;

  static const double _timeColumnWidth = 56;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _gridRow(
          context,
          header: '',
          cells: [
            for (final day in week.days)
              _DayHeading(date: day.date, today: today),
          ],
          emphasize: true,
        ),
        if (week.hasAllDay)
          _gridRow(
            context,
            header: '全天',
            cells: [
              for (final day in week.days)
                _CellEntries(entries: day.allDay, onTap: onTap),
            ],
          ),
        for (final slot in week.slots)
          _gridRow(
            context,
            header: slot,
            cells: [
              for (final day in week.days)
                _CellEntries(
                  entries: day.timed[slot] ?? const [],
                  onTap: onTap,
                ),
            ],
          ),
      ],
    );
  }

  Widget _gridRow(
    BuildContext context, {
    required String header,
    required List<Widget> cells,
    bool emphasize = false,
  }) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _timeColumnWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                header,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.muted,
                  fontWeight: emphasize ? FontWeight.w600 : null,
                ),
              ),
            ),
          ),
          for (final cell in cells)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: cell,
              ),
            ),
        ],
      ),
    );
  }
}

class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.date, required this.today});

  final LocalDate date;
  final LocalDate today;

  @override
  Widget build(BuildContext context) {
    final isToday = date == today;
    return Text(
      '${calendarWeekdayLabel(date)} ${date.month}/${date.day}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: isToday ? AppTheme.primary : AppTheme.muted,
        fontWeight: isToday ? FontWeight.w600 : null,
      ),
    );
  }
}

class _CellEntries extends StatelessWidget {
  const _CellEntries({required this.entries, required this.onTap});

  final List<CalendarEntry> entries;
  final ValueChanged<CalendarEntry> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: CalendarEntryCard(entry: entry, onTap: onTap, compact: true),
          ),
      ],
    );
  }
}

class CalendarDayList extends StatelessWidget {
  const CalendarDayList({
    super.key,
    required this.week,
    required this.today,
    required this.onTap,
  });

  final CalendarWeek week;
  final LocalDate today;
  final ValueChanged<CalendarEntry> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final day in week.days)
          _DaySection(day: day, today: today, onTap: onTap),
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.today,
    required this.onTap,
  });

  final CalendarDay day;
  final LocalDate today;
  final ValueChanged<CalendarEntry> onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = day.date == today;
    final label =
        '${calendarWeekdayLabel(day.date)} '
        '${day.date.month}月${day.date.day}日${isToday ? ' · 今天' : ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              label,
              key: Key('calendar-day-${day.date.toIso8601String()}'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: isToday ? AppTheme.primary : null,
              ),
            ),
          ),
          if (day.isEmpty)
            Text(
              '没有安排',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
          for (final entry in day.orderedEntries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: CalendarEntryCard(entry: entry, onTap: onTap),
            ),
        ],
      ),
    );
  }
}

class CalendarMonthGrid extends StatelessWidget {
  const CalendarMonthGrid({
    super.key,
    required this.month,
    required this.days,
    required this.entriesByDate,
    required this.today,
    required this.onTap,
  });

  final LocalDate month;
  final List<LocalDate> days;
  final Map<LocalDate, List<CalendarEntry>> entriesByDate;
  final LocalDate today;
  final ValueChanged<CalendarEntry> onTap;

  @override
  Widget build(BuildContext context) {
    final weeks = <List<LocalDate>>[];
    for (var index = 0; index < days.length; index += 7) {
      weeks.add(days.sublist(index, index + 7));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final label in calendarWeekdayLabels)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppTheme.muted),
                  ),
                ),
              ),
          ],
        ),
        for (final week in weeks)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final date in week)
                Expanded(
                  child: _MonthCell(
                    date: date,
                    inMonth:
                        date.year == month.year && date.month == month.month,
                    isToday: date == today,
                    entries: entriesByDate[date] ?? const [],
                    onTap: onTap,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.entries,
    required this.onTap,
  });

  final LocalDate date;
  final bool inMonth;
  final bool isToday;
  final List<CalendarEntry> entries;
  final ValueChanged<CalendarEntry> onTap;

  static const int _maxVisibleEntries = 2;

  @override
  Widget build(BuildContext context) {
    final dayNumber = Text(
      '${date.day}',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: isToday
            ? Colors.white
            : inMonth
            ? AppTheme.foreground
            : AppTheme.muted,
        fontWeight: isToday || inMonth ? FontWeight.w600 : null,
      ),
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      decoration: BoxDecoration(
        color: inMonth ? null : AppTheme.background,
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      padding: const EdgeInsets.all(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: isToday
                  ? const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    )
                  : null,
              child: dayNumber,
            ),
          ),
          const SizedBox(height: 2),
          for (final entry in entries.take(_maxVisibleEntries))
            Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: _MonthEntry(entry: entry, onTap: onTap),
            ),
          if (entries.length > _maxVisibleEntries)
            Text(
              '+${entries.length - _maxVisibleEntries}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: AppTheme.muted,
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthEntry extends StatelessWidget {
  const _MonthEntry({required this.entry, required this.onTap});

  final CalendarEntry entry;
  final ValueChanged<CalendarEntry> onTap;

  @override
  Widget build(BuildContext context) {
    final tone = CalendarTone.of(entry);
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: entry.semanticsLabel,
      child: Material(
        color: tone.background,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          key: Key('calendar-entry-${entry.id}'),
          borderRadius: BorderRadius.circular(4),
          onTap: () => onTap(entry),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            child: Text(
              entry.slot == null ? entry.title : '${entry.slot} ${entry.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: tone.foreground,
                decoration: entry.completed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CalendarListView extends StatelessWidget {
  const CalendarListView({
    super.key,
    required this.entriesByDate,
    required this.today,
    required this.onTap,
  });

  final Map<LocalDate, List<CalendarEntry>> entriesByDate;
  final LocalDate today;
  final ValueChanged<CalendarEntry> onTap;

  @override
  Widget build(BuildContext context) {
    final dates = entriesByDate.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final date in dates)
          _ListDaySection(
            date: date,
            entries: entriesByDate[date]!,
            isToday: date == today,
            onTap: onTap,
          ),
      ],
    );
  }
}

class _ListDaySection extends StatelessWidget {
  const _ListDaySection({
    required this.date,
    required this.entries,
    required this.isToday,
    required this.onTap,
  });

  final LocalDate date;
  final List<CalendarEntry> entries;
  final bool isToday;
  final ValueChanged<CalendarEntry> onTap;

  @override
  Widget build(BuildContext context) {
    final label =
        '${calendarDateLabel(date)} '
        '${calendarWeekdayLabel(date)}${isToday ? ' · 今天' : ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: isToday ? AppTheme.primary : null,
              ),
            ),
          ),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: CalendarEntryCard(entry: entry, onTap: onTap),
            ),
        ],
      ),
    );
  }
}

class CalendarUndatedSection extends StatelessWidget {
  const CalendarUndatedSection({
    super.key,
    required this.entries,
    required this.onTap,
  });

  final List<CalendarEntry> entries;
  final ValueChanged<CalendarEntry> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('未定日期 / 截止时间待确认', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '保留来源原文，不推算具体时刻。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: CalendarEntryCard(entry: entry, onTap: onTap),
            ),
        ],
      ),
    );
  }
}

class CalendarLoading extends StatelessWidget {
  const CalendarLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('calendar-loading'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text(
            '正在读取本地日历…',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}

class CalendarFailure extends StatelessWidget {
  const CalendarFailure({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('calendar-error'),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F0),
          borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
          border: Border.all(color: const Color(0xFFF3C2BD)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFB42318)),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.tonalIcon(
              key: const Key('calendar-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重新读取'),
            ),
          ],
        ),
      ),
    );
  }
}

class CalendarEmptyState extends StatelessWidget {
  const CalendarEmptyState({super.key, required this.hasAnyData});

  final bool hasAnyData;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('calendar-empty'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 40,
              color: AppTheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              hasAnyData ? '当前筛选下没有安排' : '还没有可显示的安排',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hasAnyData
                  ? '调整来源筛选或打开「显示已完成」。个人待办需要在「待办」页打开“显示在日历”才会出现在这里。'
                  : '连接校园来源并同步后，课程与作业会显示在这里；也可以到「待办」页新建待办，并设置截止时间与日历开关。',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
          ],
        ),
      ),
    );
  }
}
