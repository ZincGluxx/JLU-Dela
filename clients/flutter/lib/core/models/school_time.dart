import 'local_date.dart';

/// 学校日历固定使用 Asia/Shanghai（UTC+8，无夏令时）。
///
/// 换算规则移植自 JLU Dela 的 `codex/E02-calendar-aggregation` 分支
/// （`school_time.dart`，GPL-3.0-or-later）。
const Duration schoolUtcOffset = Duration(hours: 8);

/// [instant] 所属的北京日历日。
LocalDate schoolDateOf(DateTime instant) {
  final school = instant.toUtc().add(schoolUtcOffset);
  return LocalDate(school.year, school.month, school.day);
}

/// [date] 北京时间零点对应的 UTC 时刻。
DateTime schoolDayStartUtc(LocalDate date) {
  return date.utcMidnight.subtract(schoolUtcOffset);
}

/// [date] 所在周的周一，周视图起点。
LocalDate schoolMondayOf(LocalDate date) {
  return date.addDays(1 - date.weekday);
}

String formatSchoolClock(DateTime instant) {
  final school = instant.toUtc().add(schoolUtcOffset);
  final hour = school.hour.toString().padLeft(2, '0');
  final minute = school.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatSchoolDate(LocalDate date) => date.toIso8601String();
