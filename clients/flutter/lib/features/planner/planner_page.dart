import 'package:flutter/material.dart';
import 'package:jlu_dela_api/api.dart';

import '../../app/theme.dart';
import '../../core/api/api_failure.dart';
import 'calendar_service.dart';
import 'school_time.dart';

/// 学习日历周视图。
///
/// 一次只读一周：课程、作业和个人待办按北京时间日历日归位，宽屏排成「时段行 × 日列」
/// 的网格，窄屏退化成按日纵向排列的列表。没有精确时刻的事项不会被编造时间：
/// `date_only` 落在当天顶部标为「全天」，`relative` / `unknown` 的作业集中放到
/// 「未定日期」区，正文用来源原文。
class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key, required this.service, this.clock});

  final CalendarService service;

  /// 当前时刻来源，测试用来固定倒计时和「本周」。
  final DateTime Function()? clock;

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  late DateTime _weekStart;
  late Future<CalendarData> _calendar;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _weekStart = mondayOf(_now);
    _calendar = _load();
  }

  Future<CalendarData> _load() => widget.service.load(
    from: _weekStart,
    to: _weekStart.add(const Duration(days: 7)),
  );

  void _reload() {
    setState(() {
      _calendar = _load();
    });
  }

  void _shiftWeek(int weeks) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * weeks));
      _calendar = _load();
    });
  }

  void _backToThisWeek() {
    setState(() {
      _weekStart = mondayOf(_now);
      _calendar = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WeekNavigation(
            label: _weekLabel(_weekStart),
            onPrevious: () => _shiftWeek(-1),
            onNext: () => _shiftWeek(1),
            onThisWeek: _backToThisWeek,
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: FutureBuilder<CalendarData>(
              future: _calendar,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _PlannerLoading();
                }
                final error = snapshot.error;
                if (error != null) {
                  return _PlannerFailure(
                    message: error is ApiFailure
                        ? calendarFailureMessage(error)
                        : '读取日历失败，请稍后重试。',
                    onRetry: _reload,
                  );
                }
                final data = snapshot.data;
                if (data == null) {
                  return const _PlannerLoading();
                }
                final week = _PlannerWeek.build(data.items, _weekStart, _now);
                if (week.isEmpty) {
                  return const _PlannerEmpty();
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return constraints.maxWidth >= AppBreakpoints.desktop
                        ? _WeekGrid(week: week, now: _now)
                        : _DayList(week: week);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 「‹ 2026年11月10日 – 11月16日 ›」加上回到本周的入口。
class _WeekNavigation extends StatelessWidget {
  const _WeekNavigation({
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.onThisWeek,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onThisWeek;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const Key('planner-previous'),
          tooltip: '上一周',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            label,
            key: const Key('planner-week-label'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          key: const Key('planner-next'),
          tooltip: '下一周',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
        const SizedBox(width: AppSpacing.sm),
        TextButton(
          key: const Key('planner-today'),
          onPressed: onThisWeek,
          child: const Text('本周'),
        ),
      ],
    );
  }
}

String _weekLabel(DateTime monday) {
  final days = weekDays(monday);
  final start = beijingMidnight(days.first);
  final end = beijingMidnight(days.last);
  final head = '${start.year}年${start.month}月${start.day}日';
  final tail = start.year == end.year
      ? '${end.month}月${end.day}日'
      : '${end.year}年${end.month}月${end.day}日';
  return '$head – $tail';
}

const List<String> _weekdayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// 一张卡片的配色。
class _PlannerTone {
  const _PlannerTone(this.background, this.foreground);

  final Color background;
  final Color foreground;

  static const _PlannerTone lesson = _PlannerTone(
    Color(0xFFE8F0FD),
    Color(0xFF2A5DA8),
  );
  static const _PlannerTone assignment = _PlannerTone(
    Color(0xFFFBEFE3),
    Color(0xFF8A5227),
  );
  static const _PlannerTone todo = _PlannerTone(
    Color(0xFFEDEEF1),
    Color(0xFF474B54),
  );

  /// 个人待办的调色板，与服务端 `color` 枚举一一对应。
  static _PlannerTone forTodoColor(TodoItemColorEnum? value) {
    return switch (value) {
      TodoItemColorEnum.rose => const _PlannerTone(
        Color(0xFFFBE9EC),
        Color(0xFF8A3448),
      ),
      TodoItemColorEnum.peach => const _PlannerTone(
        Color(0xFFFBEFE3),
        Color(0xFF8A5227),
      ),
      TodoItemColorEnum.sand => const _PlannerTone(
        Color(0xFFFBF3DE),
        Color(0xFF7A6122),
      ),
      TodoItemColorEnum.sage => const _PlannerTone(
        Color(0xFFE9F5EC),
        Color(0xFF2F6B45),
      ),
      TodoItemColorEnum.teal => const _PlannerTone(
        Color(0xFFE4F4F6),
        Color(0xFF1F6673),
      ),
      TodoItemColorEnum.blue => const _PlannerTone(
        Color(0xFFE8F0FD),
        Color(0xFF2A5DA8),
      ),
      TodoItemColorEnum.lilac => const _PlannerTone(
        Color(0xFFF2EBFA),
        Color(0xFF65418F),
      ),
      TodoItemColorEnum.slate => todo,
      null => todo,
    };
  }
}

/// 一张待渲染的卡片：来源、时间、标题都已经是展示文本。
class _PlannerEntry {
  const _PlannerEntry({
    required this.key,
    required this.source,
    required this.title,
    required this.time,
    required this.tone,
    this.completed = false,
  });

  final String key;
  final String source;
  final String title;
  final String time;
  final _PlannerTone tone;
  final bool completed;

  String get semanticsLabel => '$source：$title，$time';
}

/// 一天里落在网格上的内容。
class _PlannerDay {
  _PlannerDay({required this.start});

  /// 北京时间当天零点的 UTC 时刻。
  final DateTime start;
  final List<_PlannerEntry> allDay = [];
  final Map<String, List<_PlannerEntry>> timed = {};

  bool get isEmpty => allDay.isEmpty && timed.isEmpty;
}

/// 一周的渲染模型：7 天、时段行、未定日期区。
class _PlannerWeek {
  const _PlannerWeek({
    required this.days,
    required this.slots,
    required this.undated,
  });

  final List<_PlannerDay> days;
  final List<String> slots;
  final List<_PlannerEntry> undated;

  bool get isEmpty => undated.isEmpty && days.every((day) => day.isEmpty);

  bool get hasAllDay => days.any((day) => day.allDay.isNotEmpty);

  /// 按北京时间日历日把接口返回的事项归位。
  factory _PlannerWeek.build(
    List<CalendarItem> items,
    DateTime monday,
    DateTime now,
  ) {
    final days = [
      for (final start in weekDays(monday)) _PlannerDay(start: start),
    ];
    final byDate = {for (final day in days) formatDay(day.start): day};
    final undated = <_PlannerEntry>[];
    final slots = <String>{};

    void place(_PlannerEntry entry, String date, String? slot) {
      final day = byDate[date];
      if (day == null) {
        return;
      }
      if (slot == null) {
        day.allDay.add(entry);
      } else {
        slots.add(slot);
        day.timed.putIfAbsent(slot, () => []).add(entry);
      }
    }

    for (final item in items) {
      switch (item.actualInstance) {
        case LessonItem lesson:
          final time =
              '${formatClock(lesson.startsAt)}–${formatClock(lesson.endsAt)}';
          final location = lesson.location;
          final timeText =
              location.isPresent && (location.value ?? '').isNotEmpty
              ? '$time · ${location.value}'
              : time;
          place(
            _PlannerEntry(
              key: lesson.id,
              source: '课程',
              title: lesson.title,
              time: timeText,
              tone: _PlannerTone.lesson,
            ),
            formatDay(lesson.startsAt),
            formatClock(lesson.startsAt),
          );
        case AssignmentItem assignment:
          final due = assignment.dueAt;
          final dueValue = due.isPresent ? due.value : null;
          final timing = assignment.timingText;
          final timingValue = timing.isPresent ? timing.value ?? '' : '';
          switch (assignment.dueKind) {
            case AssignmentItemDueKindEnum.exact when dueValue != null:
              final clock = formatClock(dueValue);
              place(
                _PlannerEntry(
                  key: assignment.id,
                  source: '作业',
                  title: assignment.title,
                  time: clock,
                  tone: _PlannerTone.assignment,
                ),
                formatDay(dueValue),
                clock,
              );
            case AssignmentItemDueKindEnum.dateOnly when dueValue != null:
              place(
                _PlannerEntry(
                  key: assignment.id,
                  source: '作业',
                  title: assignment.title,
                  time: '全天',
                  tone: _PlannerTone.assignment,
                ),
                formatDay(dueValue),
                null,
              );
            default:
              // `relative` / `unknown` 只有来源原文，绝不折算成时刻。
              undated.add(
                _PlannerEntry(
                  key: assignment.id,
                  source: '作业',
                  title: assignment.title,
                  time: timingValue.isEmpty ? '时间未定' : timingValue,
                  tone: _PlannerTone.assignment,
                ),
              );
          }
        case TodoItem todo:
          final color = todo.color;
          final tone = _PlannerTone.forTodoColor(
            color.isPresent ? color.value : null,
          );
          final due = todo.dueAt;
          final dueValue = due.isPresent ? due.value : null;
          final date = todo.dueDate;
          final dateValue = date.isPresent ? date.value : null;
          if (todo.dueKind == TodoItemDueKindEnum.exact && dueValue != null) {
            final clock = formatClock(dueValue);
            place(
              _PlannerEntry(
                key: todo.id,
                source: '待办',
                title: todo.title,
                time: todo.completed
                    ? clock
                    : '$clock · ${_countdown(dueValue, now)}',
                tone: tone,
                completed: todo.completed,
              ),
              formatDay(dueValue),
              clock,
            );
          } else if (dateValue != null) {
            place(
              _PlannerEntry(
                key: todo.id,
                source: '待办',
                title: todo.title,
                time: '全天',
                tone: tone,
                completed: todo.completed,
              ),
              formatDateOnly(dateValue),
              null,
            );
          } else {
            undated.add(
              _PlannerEntry(
                key: todo.id,
                source: '待办',
                title: todo.title,
                time: '时间未定',
                tone: tone,
                completed: todo.completed,
              ),
            );
          }
        default:
          break;
      }
    }

    final sortedSlots = slots.toList()..sort();
    for (final day in days) {
      day.allDay.sort((a, b) => a.title.compareTo(b.title));
      for (final entries in day.timed.values) {
        entries.sort((a, b) => a.title.compareTo(b.title));
      }
    }
    undated.sort((a, b) => a.title.compareTo(b.title));

    return _PlannerWeek(days: days, slots: sortedSlots, undated: undated);
  }
}

String _countdown(DateTime due, DateTime now) {
  final left = due.difference(now);
  if (left.isNegative) {
    return '已逾期';
  }
  if (left.inMinutes < 1) {
    return '即将到期';
  }
  if (left.inMinutes < 60) {
    return '还剩 ${left.inMinutes} 分钟';
  }
  if (left.inHours < 24) {
    return '还剩 ${left.inHours} 小时';
  }
  return '还剩 ${left.inDays} 天';
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({required this.week, required this.now});

  final _PlannerWeek week;
  final DateTime now;

  static const double _timeColumnWidth = 56;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _gridRow(
              context,
              header: '',
              cells: [
                for (final day in week.days) _DayHeading(day: day, now: now),
              ],
              emphasize: true,
            ),
            if (week.hasAllDay)
              _gridRow(
                context,
                header: '全天',
                cells: [
                  for (final day in week.days)
                    _CellEntries(entries: day.allDay),
                ],
              ),
            for (final slot in week.slots)
              _gridRow(
                context,
                header: slot,
                cells: [
                  for (final day in week.days)
                    _CellEntries(entries: day.timed[slot] ?? const []),
                ],
              ),
            if (week.undated.isNotEmpty) _UndatedSection(entries: week.undated),
          ],
        ),
      ),
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
  const _DayHeading({required this.day, required this.now});

  final _PlannerDay day;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final date = beijingMidnight(day.start);
    final isToday = formatDay(day.start) == formatDay(now);
    final label =
        '${_weekdayLabels[date.weekday - 1]} ${date.month}/${date.day}';
    return Semantics(
      label:
          '$label，${day.allDay.length + day.timed.values.fold<int>(0, (sum, list) => sum + list.length)} 项安排',
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: isToday ? AppTheme.primary : AppTheme.muted,
          fontWeight: isToday ? FontWeight.w600 : null,
        ),
      ),
    );
  }
}

class _CellEntries extends StatelessWidget {
  const _CellEntries({required this.entries});

  final List<_PlannerEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: _EntryCard(entry: entry, compact: true),
          ),
      ],
    );
  }
}

class _DayList extends StatelessWidget {
  const _DayList({required this.week});

  final _PlannerWeek week;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (final day in week.days) _DaySection(day: day),
        if (week.undated.isNotEmpty) _UndatedSection(entries: week.undated),
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.day});

  final _PlannerDay day;

  @override
  Widget build(BuildContext context) {
    final date = beijingMidnight(day.start);
    final label =
        '${_weekdayLabels[date.weekday - 1]} ${date.month}月${date.day}日';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(label, style: Theme.of(context).textTheme.titleSmall),
          ),
          if (day.isEmpty)
            Text(
              '没有安排',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
            ),
          for (final entry in _orderedEntries(day))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _EntryCard(entry: entry),
            ),
        ],
      ),
    );
  }
}

/// 窄屏列表里一天的顺序：先全天，再按时刻。
List<_PlannerEntry> _orderedEntries(_PlannerDay day) {
  final slots = day.timed.keys.toList()..sort();
  return [...day.allDay, for (final slot in slots) ...day.timed[slot]!];
}

class _UndatedSection extends StatelessWidget {
  const _UndatedSection({required this.entries});

  final List<_PlannerEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '未定日期事项',
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.sm,
          bottom: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                '未定日期',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _EntryCard(entry: entry),
              ),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, this.compact = false});

  final _PlannerEntry entry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: entry.tone.foreground,
      decoration: entry.completed ? TextDecoration.lineThrough : null,
    );
    return Semantics(
      label: entry.semanticsLabel,
      container: true,
      excludeSemantics: true,
      child: Container(
        key: Key('planner-entry-${entry.key}'),
        decoration: BoxDecoration(
          color: entry.tone.background,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: compact ? AppSpacing.xs : AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textStyle?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              entry.time,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textStyle?.copyWith(
                fontSize: 11,
                color: entry.tone.foreground.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlannerLoading extends StatelessWidget {
  const _PlannerLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('planner-loading'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text(
            '正在读取学习日历…',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}

class _PlannerEmpty extends StatelessWidget {
  const _PlannerEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('planner-empty'),
      child: Text(
        '本周没有安排',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
      ),
    );
  }
}

class _PlannerFailure extends StatelessWidget {
  const _PlannerFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('planner-error'),
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
              key: const Key('planner-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
