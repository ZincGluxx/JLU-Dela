import 'jlu_timetable_parser.dart';

/// 一条展开到具体日期的课次，时间为 UTC；界面按 Asia/Shanghai 显示。
class JluLessonOccurrence {
  const JluLessonOccurrence({
    required this.id,
    required this.lessonSourceId,
    required this.title,
    required this.weekNumber,
    required this.weekday,
    required this.periodStart,
    required this.periodEnd,
    required this.startsAtUtc,
    required this.endsAtUtc,
    this.location,
    this.note,
  });

  final String id;
  final String lessonSourceId;
  final String title;
  final int weekNumber;
  final int weekday;
  final int periodStart;
  final int periodEnd;
  final DateTime startsAtUtc;
  final DateTime endsAtUtc;
  final String? location;
  final String? note;
}

/// 把相对教学周课表展开为具体日期课次。
///
/// 校历开学日按校园当地日期解释（固定 UTC+8，无夏令时），
/// 教学周以包含开学日的自然周周一为第 1 周起点，与旧版 Electron 实现一致。
List<JluLessonOccurrence> expandJluLessonOccurrences(JluTimetable timetable) {
  if (!isJluCalendarDate(timetable.semesterStart)) {
    throw JluParseException('教务校历开学日期无效：${timetable.semesterStart}');
  }
  final start = DateTime.parse('${timetable.semesterStart}T00:00:00Z');
  final monday = start.subtract(Duration(days: start.weekday - 1));
  final mondayUtc = monday.subtract(const Duration(hours: 8));
  final byId = <String, JluLessonOccurrence>{};
  for (final lesson in timetable.lessons) {
    for (final week in lesson.weekNumbers) {
      final day = mondayUtc.add(
        Duration(days: (week - 1) * 7 + lesson.weekday - 1),
      );
      final occurrence = JluLessonOccurrence(
        id: _occurrenceId(timetable.semesterStart, lesson, week),
        lessonSourceId: lesson.sourceId,
        title: lesson.courseName,
        weekNumber: week,
        weekday: lesson.weekday,
        periodStart: lesson.startPeriod,
        periodEnd: lesson.endPeriod,
        startsAtUtc: day.add(Duration(minutes: lesson.startMinute)),
        endsAtUtc: day.add(Duration(minutes: lesson.endMinute)),
        location: lesson.classroom,
        note: lesson.note,
      );
      byId.putIfAbsent(occurrence.id, () => occurrence);
    }
  }
  return byId.values.toList()..sort((a, b) {
    final byStart = a.startsAtUtc.compareTo(b.startsAtUtc);
    return byStart != 0 ? byStart : a.id.compareTo(b.id);
  });
}

String _occurrenceId(String semesterStart, JluLesson lesson, int week) {
  final courseKey = lesson.kbId.isEmpty ? lesson.sourceId : lesson.kbId;
  final kind = lesson.note ?? '';
  return 'jlu:$semesterStart:$courseKey:${lesson.weekday}:'
      '${lesson.startPeriod}-${lesson.endPeriod}:$kind:$week';
}
