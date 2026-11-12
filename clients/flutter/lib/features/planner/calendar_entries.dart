import '../../core/models/assignment.dart';
import '../../core/models/lesson.dart';
import '../../core/models/local_date.dart';
import '../../core/models/school_time.dart';
import '../../core/models/todo.dart';
import 'calendar_time.dart';

/// 日历条目的日期归位与未定日期规则参考
/// `codex/E02-calendar-aggregation` 的 `planner_page.dart`（GPL-3.0-or-later）。

enum CalendarEntryKind {
  lesson('课程'),
  assignment('作业'),
  todo('待办');

  const CalendarEntryKind(this.label);

  final String label;
}

String calendarColorLabel(CalendarColor? color) {
  return switch (color) {
    CalendarColor.rose => '玫红',
    CalendarColor.peach => '杏橙',
    CalendarColor.sand => '沙黄',
    CalendarColor.sage => '草绿',
    CalendarColor.teal => '湖青',
    CalendarColor.blue => '雾蓝',
    CalendarColor.lilac => '藕紫',
    CalendarColor.slate || null => '石墨',
  };
}

class CalendarEntry {
  const CalendarEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.timeLabel,
    this.date,
    this.slot,
    this.completed = false,
    this.lesson,
    this.assignment,
    this.todo,
  });

  final String id;
  final CalendarEntryKind kind;
  final String title;
  final String timeLabel;
  final LocalDate? date;
  final String? slot;
  final bool completed;
  final Lesson? lesson;
  final Assignment? assignment;
  final Todo? todo;

  bool get isUndated => date == null;

  String get semanticsLabel {
    final suffix = completed ? '，已完成' : '';
    return '${kind.label}：$title，$timeLabel$suffix';
  }

  factory CalendarEntry.forLesson(Lesson lesson) {
    final location = lesson.location?.trim();
    final time = calendarClockRangeLabel(lesson.startsAtUtc, lesson.endsAtUtc);
    return CalendarEntry(
      id: 'lesson:${lesson.id}',
      kind: CalendarEntryKind.lesson,
      title: lesson.title,
      timeLabel: location == null || location.isEmpty
          ? time
          : '$time · $location',
      date: schoolDateOf(lesson.startsAtUtc),
      slot: formatSchoolClock(lesson.startsAtUtc),
      lesson: lesson,
    );
  }

  factory CalendarEntry.forAssignment(Assignment assignment) {
    final readSuffix = assignment.readAtUtc == null ? '' : ' · 已读';
    final dueAt = assignment.dueAtUtc;
    final dueDate = assignment.dueDate;
    final entry = switch (assignment.dueKind) {
      AssignmentDueKind.exact when dueAt != null => CalendarEntry(
        id: 'assignment:${assignment.id}',
        kind: CalendarEntryKind.assignment,
        title: assignment.title,
        timeLabel: '截止 ${formatSchoolClock(dueAt)}$readSuffix',
        date: schoolDateOf(dueAt),
        slot: formatSchoolClock(dueAt),
        assignment: assignment,
      ),
      AssignmentDueKind.dateOnly when dueDate != null => CalendarEntry(
        id: 'assignment:${assignment.id}',
        kind: CalendarEntryKind.assignment,
        title: assignment.title,
        timeLabel: '全天$readSuffix',
        date: dueDate,
        assignment: assignment,
      ),
      _ => CalendarEntry(
        id: 'assignment:${assignment.id}',
        kind: CalendarEntryKind.assignment,
        title: assignment.title,
        timeLabel: _assignmentTimingText(assignment, readSuffix),
        assignment: assignment,
      ),
    };
    return entry;
  }

  factory CalendarEntry.forTodo(Todo todo) {
    final entry = switch (todo.dueKind) {
      TodoDueKind.exact when todo.dueAtUtc != null => CalendarEntry(
        id: 'todo:${todo.id}',
        kind: CalendarEntryKind.todo,
        title: todo.title,
        timeLabel: formatSchoolClock(todo.dueAtUtc!),
        date: schoolDateOf(todo.dueAtUtc!),
        slot: formatSchoolClock(todo.dueAtUtc!),
        completed: todo.completed,
        todo: todo,
      ),
      TodoDueKind.dateOnly when todo.dueDate != null => CalendarEntry(
        id: 'todo:${todo.id}',
        kind: CalendarEntryKind.todo,
        title: todo.title,
        timeLabel: '全天',
        date: todo.dueDate,
        completed: todo.completed,
        todo: todo,
      ),
      _ => CalendarEntry(
        id: 'todo:${todo.id}',
        kind: CalendarEntryKind.todo,
        title: todo.title,
        timeLabel: '未设置截止',
        completed: todo.completed,
        todo: todo,
      ),
    };
    return entry;
  }
}

String _assignmentTimingText(Assignment assignment, String readSuffix) {
  final timing = assignment.timingText?.trim();
  final base = timing == null || timing.isEmpty ? '截止时间待确认' : timing;
  return '$base$readSuffix';
}

List<CalendarEntry> buildCalendarEntries({
  required Iterable<Lesson> lessons,
  required Iterable<Assignment> assignments,
  required Iterable<Todo> todos,
}) {
  return [
    for (final lesson in lessons) CalendarEntry.forLesson(lesson),
    for (final assignment in assignments)
      if (assignment.mutedAtUtc == null)
        CalendarEntry.forAssignment(assignment),
    for (final todo in todos)
      if (todo.showInCalendar) CalendarEntry.forTodo(todo),
  ];
}

List<CalendarEntry> filterCalendarEntries(
  Iterable<CalendarEntry> entries, {
  required Set<CalendarEntryKind> kinds,
  required bool showCompleted,
}) {
  return [
    for (final entry in entries)
      if (kinds.contains(entry.kind) && (showCompleted || !entry.completed))
        entry,
  ];
}

List<CalendarEntry> sortedCalendarEntries(Iterable<CalendarEntry> entries) {
  final sorted = entries.toList()..sort(compareCalendarEntries);
  return sorted;
}

int compareCalendarEntries(CalendarEntry a, CalendarEntry b) {
  final aDate = a.date;
  final bDate = b.date;
  if (aDate == null && bDate != null) {
    return 1;
  }
  if (aDate != null && bDate == null) {
    return -1;
  }
  if (aDate != null && bDate != null) {
    final byDate = aDate.compareTo(bDate);
    if (byDate != 0) {
      return byDate;
    }
  }

  final aSlot = a.slot;
  final bSlot = b.slot;
  if (aSlot == null && bSlot != null) {
    return -1;
  }
  if (aSlot != null && bSlot == null) {
    return 1;
  }
  if (aSlot != null && bSlot != null) {
    final bySlot = aSlot.compareTo(bSlot);
    if (bySlot != 0) {
      return bySlot;
    }
  }

  final byTitle = a.title.compareTo(b.title);
  if (byTitle != 0) {
    return byTitle;
  }
  return a.id.compareTo(b.id);
}
