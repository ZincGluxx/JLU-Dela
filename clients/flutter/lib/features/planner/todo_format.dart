import 'package:flutter/material.dart';

import '../../core/models/local_date.dart';
import '../../core/models/school_time.dart';
import '../../core/models/todo.dart';
import '../../core/storage/todo_store.dart';

DateTime schoolWallTime(DateTime instant) =>
    instant.toUtc().add(schoolUtcOffset);

DateTime utcFromSchoolWallTime(
  int year,
  int month,
  int day,
  int hour,
  int minute,
) {
  return DateTime.utc(year, month, day, hour, minute).subtract(schoolUtcOffset);
}

String formatTodoDue(Todo todo, DateTime nowUtc) {
  switch (todo.dueKind) {
    case TodoDueKind.none:
      return '无截止';
    case TodoDueKind.dateOnly:
      return '${_dayLabel(todo.dueDate!, schoolDateOf(nowUtc))} · 全天';
    case TodoDueKind.exact:
      final wall = schoolWallTime(todo.dueAtUtc!);
      final date = LocalDate(wall.year, wall.month, wall.day);
      return '${_dayLabel(date, schoolDateOf(nowUtc))} '
          '${formatSchoolClock(todo.dueAtUtc!)}';
  }
}

bool isTodoOverdue(Todo todo, DateTime nowUtc) {
  if (todo.completed) {
    return false;
  }
  switch (todo.dueKind) {
    case TodoDueKind.none:
      return false;
    case TodoDueKind.dateOnly:
      return schoolDateOf(nowUtc).differenceInDays(todo.dueDate!) > 0;
    case TodoDueKind.exact:
      return !nowUtc.toUtc().isBefore(todo.dueAtUtc!.toUtc());
  }
}

String describeTodoError(Object error) {
  final message = error is TodoValidationException
      ? error.message
      : error.toString();
  final singleLine = message.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (singleLine.length <= 180) {
    return singleLine;
  }
  return '${singleLine.substring(0, 180)}…';
}

String _dayLabel(LocalDate date, LocalDate today) {
  final difference = date.differenceInDays(today);
  if (difference == 0) {
    return '今天';
  }
  if (difference == 1) {
    return '明天';
  }
  if (difference == -1) {
    return '昨天';
  }
  if (date.year == today.year) {
    return '${date.month}月${date.day}日';
  }
  return '${date.year}年${date.month}月${date.day}日';
}

/// 8 个日历颜色的中文名与柔和色板；颜色语义来自 `CalendarColor`，不另建设计 token。
extension CalendarColorPresentation on CalendarColor {
  String get label => switch (this) {
    CalendarColor.rose => '玫瑰',
    CalendarColor.peach => '蜜桃',
    CalendarColor.sand => '沙丘',
    CalendarColor.sage => '鼠尾草',
    CalendarColor.teal => '青碧',
    CalendarColor.blue => '湖蓝',
    CalendarColor.lilac => '丁香',
    CalendarColor.slate => '石墨',
  };

  Color get fill => switch (this) {
    CalendarColor.rose => const Color(0xFFF6DDE2),
    CalendarColor.peach => const Color(0xFFFBE7D4),
    CalendarColor.sand => const Color(0xFFF1E8D6),
    CalendarColor.sage => const Color(0xFFDDEDE4),
    CalendarColor.teal => const Color(0xFFD7EAEA),
    CalendarColor.blue => const Color(0xFFDCE8F8),
    CalendarColor.lilac => const Color(0xFFE7E1F5),
    CalendarColor.slate => const Color(0xFFE3E5E9),
  };

  Color get accent => switch (this) {
    CalendarColor.rose => const Color(0xFFB45366),
    CalendarColor.peach => const Color(0xFFA9682F),
    CalendarColor.sand => const Color(0xFF8A7440),
    CalendarColor.sage => const Color(0xFF3F7A60),
    CalendarColor.teal => const Color(0xFF2F7275),
    CalendarColor.blue => const Color(0xFF2E63A7),
    CalendarColor.lilac => const Color(0xFF6B55A3),
    CalendarColor.slate => const Color(0xFF555B66),
  };
}
