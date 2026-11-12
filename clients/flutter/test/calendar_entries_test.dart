import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/models/assignment.dart';
import 'package:jlu_dela/core/models/lesson.dart';
import 'package:jlu_dela/core/models/local_date.dart';
import 'package:jlu_dela/core/models/todo.dart';
import 'package:jlu_dela/features/planner/calendar_entries.dart';
import 'package:jlu_dela/features/planner/calendar_grid.dart';

Lesson _lesson({
  String id = 'l1',
  String title = '高等数学',
  DateTime? startsAtUtc,
  DateTime? endsAtUtc,
  String? location = '逸夫楼201',
}) {
  return Lesson(
    id: id,
    courseOfferingId: 'c1',
    title: title,
    startsAtUtc: startsAtUtc ?? DateTime.utc(2026, 11, 9),
    endsAtUtc: endsAtUtc ?? DateTime.utc(2026, 11, 9, 1, 40),
    location: location,
    periodStart: 1,
    periodEnd: 2,
  );
}

Assignment _assignment({
  String id = 'a1',
  String title = '第三章习题',
  AssignmentDueKind dueKind = AssignmentDueKind.relative,
  LocalDate? dueDate,
  DateTime? dueAtUtc,
  String? timingText = '3 天后截止',
  DateTime? readAtUtc,
  DateTime? mutedAtUtc,
}) {
  return Assignment(
    id: id,
    title: title,
    sourceStatus: 'pending',
    dueKind: dueKind,
    dueDate: dueDate,
    dueAtUtc: dueAtUtc,
    timingText: timingText,
    observedAtUtc: DateTime.utc(2026, 11, 11, 1),
    readAtUtc: readAtUtc,
    mutedAtUtc: mutedAtUtc,
  );
}

Todo _todo({
  String id = 't1',
  String title = '交实验报告',
  TodoDueKind dueKind = TodoDueKind.exact,
  LocalDate? dueDate,
  DateTime? dueAtUtc,
  CalendarColor? color,
  bool showInCalendar = true,
  bool completed = false,
  String notes = '',
}) {
  return Todo(
    id: id,
    userId: 'user-a',
    title: title,
    notes: notes,
    dueKind: dueKind,
    dueDate: dueDate,
    dueAtUtc: dueAtUtc ?? DateTime.utc(2026, 11, 11, 2),
    color: color,
    showInCalendar: showInCalendar,
    completed: completed,
    revision: 1,
    createdAtUtc: DateTime.utc(2026, 11, 1),
    updatedAtUtc: DateTime.utc(2026, 11, 1),
  );
}

void main() {
  group('条目日期语义', () {
    test('exact 作业按北京时间落格', () {
      final entry = CalendarEntry.forAssignment(
        _assignment(
          id: 'exact',
          dueKind: AssignmentDueKind.exact,
          dueAtUtc: DateTime.utc(2026, 11, 12, 1, 30),
          timingText: null,
        ),
      );
      expect(entry.date, const LocalDate(2026, 11, 12));
      expect(entry.slot, '09:30');
      expect(entry.timeLabel, '截止 09:30');
      expect(entry.isUndated, isFalse);
    });

    test('UTC 16:30 的截止属于北京次日 00:30', () {
      final entry = CalendarEntry.forAssignment(
        _assignment(
          dueKind: AssignmentDueKind.exact,
          dueAtUtc: DateTime.utc(2026, 11, 12, 16, 30),
          timingText: null,
        ),
      );
      expect(entry.date, const LocalDate(2026, 11, 13));
      expect(entry.slot, '00:30');
    });

    test('dateOnly 占用全天且不带时刻', () {
      final entry = CalendarEntry.forAssignment(
        _assignment(
          dueKind: AssignmentDueKind.dateOnly,
          dueDate: const LocalDate(2026, 11, 10),
          timingText: null,
        ),
      );
      expect(entry.date, const LocalDate(2026, 11, 10));
      expect(entry.slot, isNull);
      expect(entry.timeLabel, '全天');
    });

    test('relative 保留来源原文且不落格', () {
      final entry = CalendarEntry.forAssignment(_assignment());
      expect(entry.date, isNull);
      expect(entry.slot, isNull);
      expect(entry.timeLabel, '3 天后截止');
    });

    test('unknown 没有原文时明确标成待确认', () {
      final entry = CalendarEntry.forAssignment(
        _assignment(dueKind: AssignmentDueKind.unknown, timingText: '  '),
      );
      expect(entry.timeLabel, '截止时间待确认');
    });

    test('已读作业带标记', () {
      final entry = CalendarEntry.forAssignment(
        _assignment(readAtUtc: DateTime.utc(2026, 11, 11, 3)),
      );
      expect(entry.timeLabel, '3 天后截止 · 已读');
    });

    test('dateOnly 待办是全天，无截止待办进入未定日期', () {
      final allDay = CalendarEntry.forTodo(
        _todo(
          dueKind: TodoDueKind.dateOnly,
          dueDate: const LocalDate(2026, 11, 10),
        ),
      );
      expect(allDay.slot, isNull);
      expect(allDay.timeLabel, '全天');

      final undated = CalendarEntry.forTodo(
        _todo(dueKind: TodoDueKind.none, dueAtUtc: null),
      );
      expect(undated.date, isNull);
      expect(undated.timeLabel, '未设置截止');
    });
  });

  group('条目收集与筛选', () {
    test('忽略的作业与未开启日历的待办不进入条目', () {
      final entries = buildCalendarEntries(
        lessons: [_lesson()],
        assignments: [
          _assignment(),
          _assignment(id: 'muted', mutedAtUtc: DateTime.utc(2026, 11, 11, 2)),
        ],
        todos: [
          _todo(),
          _todo(id: 'hidden', showInCalendar: false),
        ],
      );
      expect(entries.map((entry) => entry.title), ['高等数学', '第三章习题', '交实验报告']);
    });

    test('来源筛选与显示已完成开关', () {
      final entries = buildCalendarEntries(
        lessons: [_lesson()],
        assignments: [_assignment()],
        todos: [_todo(completed: true)],
      );

      final lessonsOnly = filterCalendarEntries(
        entries,
        kinds: {CalendarEntryKind.lesson},
        showCompleted: false,
      );
      expect(lessonsOnly.single.kind, CalendarEntryKind.lesson);

      final todosHidden = filterCalendarEntries(
        entries,
        kinds: {CalendarEntryKind.todo},
        showCompleted: false,
      );
      expect(todosHidden, isEmpty);

      final todosShown = filterCalendarEntries(
        entries,
        kinds: {CalendarEntryKind.todo},
        showCompleted: true,
      );
      expect(todosShown.single.completed, isTrue);
    });

    test('排序：日期、全天、时刻、标题', () {
      final entries = [
        CalendarEntry.forTodo(
          _todo(
            id: 'late',
            title: '晚',
            dueAtUtc: DateTime.utc(2026, 11, 10, 9),
          ),
        ),
        CalendarEntry.forTodo(
          _todo(
            id: 'all-day',
            title: '全天',
            dueKind: TodoDueKind.dateOnly,
            dueDate: const LocalDate(2026, 11, 10),
          ),
        ),
        CalendarEntry.forTodo(
          _todo(
            id: 'early',
            title: '早',
            dueAtUtc: DateTime.utc(2026, 11, 10, 1),
          ),
        ),
        CalendarEntry.forTodo(
          _todo(id: 'undated', title: '未定', dueAtUtc: null),
        ),
      ];

      final sorted = sortedCalendarEntries(entries);
      expect(sorted.map((entry) => entry.title), ['全天', '早', '晚', '未定']);
    });
  });

  group('周网格', () {
    test('按日与时刻归位，未定日期单列', () {
      final entries = buildCalendarEntries(
        lessons: [_lesson()],
        assignments: [
          _assignment(
            id: 'all-day',
            title: '实验预习',
            dueKind: AssignmentDueKind.dateOnly,
            dueDate: const LocalDate(2026, 11, 10),
            timingText: null,
          ),
          _assignment(),
        ],
        todos: [
          _todo(
            id: 'todo',
            title: '交报告',
            dueAtUtc: DateTime.utc(2026, 11, 11, 2),
          ),
        ],
      );
      final days = weekRangeOf(const LocalDate(2026, 11, 12)).days;
      final week = CalendarWeek.build(entries, days);

      expect(week.days, hasLength(7));
      expect(week.days.first.date, const LocalDate(2026, 11, 9));
      expect(week.slots, ['08:00', '10:00']);
      expect(week.days[0].timed['08:00']!.single.title, '高等数学');
      expect(week.days[1].allDay.single.title, '实验预习');
      expect(week.days[2].timed['10:00']!.single.title, '交报告');
      expect(week.undated.single.title, '第三章习题');
    });

    test('跨周课程按 starts_at 归日，不重复出现在下一周', () {
      final lesson = _lesson(
        id: 'cross-week',
        title: '跨周课程',
        startsAtUtc: DateTime.utc(2026, 11, 15, 15, 30),
        endsAtUtc: DateTime.utc(2026, 11, 15, 16, 30),
        location: null,
      );
      final entry = CalendarEntry.forLesson(lesson);
      expect(entry.date, const LocalDate(2026, 11, 15));
      expect(entry.slot, '23:30');

      final thisWeek = CalendarWeek.build([
        entry,
      ], weekRangeOf(const LocalDate(2026, 11, 12)).days);
      expect(thisWeek.days.last.timed['23:30']!.single.title, '跨周课程');

      final nextWeek = CalendarWeek.build([
        entry,
      ], weekRangeOf(const LocalDate(2026, 11, 19)).days);
      expect(nextWeek.isEmpty, isTrue);
    });

    test('月网格按日分组，组内保持全天优先', () {
      final entries = buildCalendarEntries(
        lessons: [
          _lesson(
            startsAtUtc: DateTime.utc(2026, 11, 10, 1),
            endsAtUtc: DateTime.utc(2026, 11, 10, 2),
          ),
        ],
        assignments: [
          _assignment(
            id: 'all-day',
            title: '实验预习',
            dueKind: AssignmentDueKind.dateOnly,
            dueDate: const LocalDate(2026, 11, 10),
            timingText: null,
          ),
        ],
        todos: [],
      );
      final grouped = groupCalendarEntriesByDate(entries);
      expect(grouped.keys, [const LocalDate(2026, 11, 10)]);
      expect(grouped.values.single.map((entry) => entry.title), [
        '实验预习',
        '高等数学',
      ]);
    });
  });
}
