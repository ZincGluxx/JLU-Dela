import '../../core/models/local_date.dart';
import '../../core/models/school_time.dart';
import 'calendar_entries.dart';

/// 周/月网格的日期范围与分槽结构移植自
/// `codex/E02-calendar-aggregation` 的 `planner_page.dart`（GPL-3.0-or-later），
/// 改为按本地 `LocalWorkspace` 的纯模型构建。

class CalendarDateRange {
  const CalendarDateRange(this.from, this.to);

  final LocalDate from;
  final LocalDate to;

  int get lengthInDays => to.differenceInDays(from);

  bool contains(LocalDate date) {
    return date.compareTo(from) >= 0 && date.compareTo(to) < 0;
  }

  List<LocalDate> get days {
    return [
      for (var index = 0; index < lengthInDays; index++) from.addDays(index),
    ];
  }
}

CalendarDateRange weekRangeOf(LocalDate anchor) {
  final monday = schoolMondayOf(anchor);
  return CalendarDateRange(monday, monday.addDays(7));
}

LocalDate firstOfMonth(LocalDate date) {
  return LocalDate(date.year, date.month, 1);
}

LocalDate shiftMonthStart(LocalDate date, int delta) {
  final monthIndex = date.year * 12 + date.month - 1 + delta;
  return LocalDate(monthIndex ~/ 12, monthIndex % 12 + 1, 1);
}

CalendarDateRange monthRangeOf(LocalDate anchor) {
  final first = firstOfMonth(anchor);
  return CalendarDateRange(first, shiftMonthStart(first, 1));
}

CalendarDateRange monthGridRangeOf(LocalDate anchor) {
  final first = firstOfMonth(anchor);
  final next = shiftMonthStart(first, 1);
  final gridStart = schoolMondayOf(first);
  final gridEnd = schoolMondayOf(next).addDays(7);
  return CalendarDateRange(gridStart, gridEnd);
}

class CalendarDay {
  CalendarDay(this.date);

  final LocalDate date;
  final List<CalendarEntry> allDay = [];
  final Map<String, List<CalendarEntry>> timed = {};

  bool get isEmpty => allDay.isEmpty && timed.isEmpty;

  int get entryCount {
    return allDay.length +
        timed.values.fold<int>(0, (sum, entries) => sum + entries.length);
  }

  List<CalendarEntry> get orderedEntries {
    final slots = timed.keys.toList()..sort();
    return [...allDay, for (final slot in slots) ...timed[slot]!];
  }
}

class CalendarWeek {
  const CalendarWeek._({
    required this.days,
    required this.slots,
    required this.undated,
  });

  final List<CalendarDay> days;
  final List<String> slots;
  final List<CalendarEntry> undated;

  bool get isEmpty => undated.isEmpty && days.every((day) => day.isEmpty);

  bool get hasAllDay => days.any((day) => day.allDay.isNotEmpty);

  factory CalendarWeek.build(
    Iterable<CalendarEntry> entries,
    List<LocalDate> visibleDays,
  ) {
    final byDate = <LocalDate, CalendarDay>{
      for (final date in visibleDays) date: CalendarDay(date),
    };
    final undated = <CalendarEntry>[];

    for (final entry in sortedCalendarEntries(entries)) {
      final date = entry.date;
      if (date == null) {
        undated.add(entry);
        continue;
      }
      final day = byDate[date];
      if (day == null) {
        continue;
      }
      final slot = entry.slot;
      if (slot == null) {
        day.allDay.add(entry);
      } else {
        day.timed.putIfAbsent(slot, () => []).add(entry);
      }
    }

    final slots = <String>{
      for (final day in byDate.values) ...day.timed.keys,
    }.toList()..sort();

    return CalendarWeek._(
      days: [for (final date in visibleDays) byDate[date]!],
      slots: slots,
      undated: undated,
    );
  }
}

Map<LocalDate, List<CalendarEntry>> groupCalendarEntriesByDate(
  Iterable<CalendarEntry> entries,
) {
  final grouped = <LocalDate, List<CalendarEntry>>{};
  for (final entry in sortedCalendarEntries(entries)) {
    final date = entry.date;
    if (date == null) {
      continue;
    }
    grouped.putIfAbsent(date, () => []).add(entry);
  }
  return grouped;
}

List<CalendarEntry> undatedCalendarEntries(Iterable<CalendarEntry> entries) {
  return [
    for (final entry in sortedCalendarEntries(entries))
      if (entry.date == null) entry,
  ];
}
