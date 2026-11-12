import '../../core/models/local_date.dart';
import '../../core/models/school_time.dart';

const List<String> calendarWeekdayLabels = [
  '周一',
  '周二',
  '周三',
  '周四',
  '周五',
  '周六',
  '周日',
];

String calendarWeekdayLabel(LocalDate date) {
  return calendarWeekdayLabels[date.weekday - 1];
}

String calendarDateLabel(LocalDate date) {
  return '${date.year}年${date.month}月${date.day}日';
}

String calendarShortDateLabel(LocalDate date) {
  return '${date.month}月${date.day}日';
}

String calendarMonthLabel(LocalDate date) {
  return '${date.year}年${date.month}月';
}

String calendarWeekLabel(LocalDate monday) {
  final sunday = monday.addDays(6);
  final tail = monday.year == sunday.year
      ? calendarShortDateLabel(sunday)
      : calendarDateLabel(sunday);
  return '${calendarDateLabel(monday)} – $tail';
}

String calendarClockRangeLabel(DateTime start, DateTime end) {
  return '${formatSchoolClock(start)}–${formatSchoolClock(end)}';
}

String calendarTimestampLabel(DateTime instant) {
  return '${calendarDateLabel(schoolDateOf(instant))} '
      '${formatSchoolClock(instant)}';
}
