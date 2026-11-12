import 'lesson.dart';
import 'school_time.dart';

class TeachingPeriod {
  const TeachingPeriod({
    required this.period,
    required this.campus,
    required this.startMinute,
    required this.endMinute,
  });

  final int period;
  final String campus;
  final int startMinute;
  final int endMinute;
}

int teachingMinuteOfDay(DateTime instant) {
  final school = instant.toUtc().add(schoolUtcOffset);
  return school.hour * 60 + school.minute;
}

String teachingClock(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:'
    '${(minute % 60).toString().padLeft(2, '0')}';

class TeachingTimeline {
  TeachingTimeline({required this.periods, required this.lessons});

  final List<TeachingPeriod> periods;
  final List<Lesson> lessons;

  List<int> get boundaries => <int>{
    for (final period in periods) ...[period.startMinute, period.endMinute],
    for (final lesson in lessons) ...[
      teachingMinuteOfDay(lesson.startsAtUtc),
      teachingMinuteOfDay(lesson.endsAtUtc),
    ],
  }.toList()..sort();

  List<(int, int)> get gaps {
    final occupied = <(int, int)>[
      for (final period in periods) (period.startMinute, period.endMinute),
      for (final lesson in lessons)
        (
          teachingMinuteOfDay(lesson.startsAtUtc),
          teachingMinuteOfDay(lesson.endsAtUtc),
        ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final result = <(int, int)>[];
    if (occupied.isEmpty) return result;
    var end = occupied.first.$2;
    for (final interval in occupied.skip(1)) {
      if (interval.$1 - end >= 30) result.add((end, interval.$1));
      if (interval.$2 > end) end = interval.$2;
    }
    return result;
  }

  double displayMinute(int minute) {
    var position = minute.toDouble();
    for (final gap in gaps) {
      if (minute <= gap.$1) break;
      final duration = gap.$2 - gap.$1;
      final elapsed = minute < gap.$2 ? minute - gap.$1 : duration;
      position -= elapsed * (duration - 4) / duration;
    }
    return position;
  }
}
