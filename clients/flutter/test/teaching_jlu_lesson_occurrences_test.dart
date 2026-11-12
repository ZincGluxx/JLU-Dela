import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/features/teaching/jlu_lesson_occurrences.dart';
import 'package:jlu_dela/features/teaching/jlu_timetable_parser.dart';

JluTimetable timetable({
  List<JluLesson> lessons = const <JluLesson>[],
  String semesterStart = '2026-09-14',
}) => JluTimetable(
  semesterStart: semesterStart,
  totalWeeks: 20,
  lessons: lessons,
  warnings: const <String>[],
);

JluLesson lesson({
  String sourceId = 'course:0',
  String kbId = 'course',
  int weekday = 1,
  int startPeriod = 1,
  int endPeriod = 2,
  int startMinute = 550,
  int endMinute = 650,
  List<int> weekNumbers = const <int>[1],
  String? note,
}) => JluLesson(
  sourceId: sourceId,
  kbId: kbId,
  courseCode: 'TEST001',
  courseName: '示例课程',
  className: null,
  teacher: '教师甲',
  campus: null,
  classroom: '示例教室',
  weekday: weekday,
  startPeriod: startPeriod,
  endPeriod: endPeriod,
  periodsText: '$startPeriod–$endPeriod节',
  weeksText: '${weekNumbers.join('、')}周',
  weekNumbers: weekNumbers,
  credits: 2,
  note: note,
  startMinute: startMinute,
  endMinute: endMinute,
);

void main() {
  test('expands teaching weeks into Beijing-local UTC instants', () {
    final occurrences = expandJluLessonOccurrences(
      timetable(lessons: <JluLesson>[lesson()]),
    );
    final occurrence = occurrences.single;
    expect(occurrence.weekNumber, 1);
    expect(occurrence.startsAtUtc, DateTime.utc(2026, 9, 14, 1, 10));
    expect(occurrence.endsAtUtc, DateTime.utc(2026, 9, 14, 2, 50));
  });

  test('handles the last teaching week and Sunday', () {
    final occurrences = expandJluLessonOccurrences(
      timetable(
        lessons: <JluLesson>[
          lesson(
            weekday: 7,
            startPeriod: 3,
            endPeriod: 3,
            startMinute: 660,
            endMinute: 705,
            weekNumbers: <int>[20],
          ),
        ],
      ),
    );
    expect(occurrences.single.startsAtUtc, DateTime.utc(2027, 1, 31, 3));
    expect(occurrences.single.endsAtUtc, DateTime.utc(2027, 1, 31, 3, 45));
  });

  test('uses the Monday of the week containing the semester start', () {
    final occurrences = expandJluLessonOccurrences(
      timetable(
        semesterStart: '2026-09-16',
        lessons: <JluLesson>[
          lesson(weekday: 1),
          lesson(weekday: 3, sourceId: 'course:1'),
        ],
      ),
    );
    expect(occurrences.map((occurrence) => occurrence.startsAtUtc), <DateTime>[
      DateTime.utc(2026, 9, 14, 1, 10),
      DateTime.utc(2026, 9, 16, 1, 10),
    ]);
  });

  test('expands every week and sorts by start time', () {
    final occurrences = expandJluLessonOccurrences(
      timetable(
        lessons: <JluLesson>[
          lesson(weekNumbers: <int>[3, 1], weekday: 2),
          lesson(sourceId: 'course:1', weekday: 1, weekNumbers: <int>[2]),
        ],
      ),
    );
    expect(occurrences, hasLength(3));
    expect(occurrences.map((occurrence) => occurrence.startsAtUtc), <DateTime>[
      DateTime.utc(2026, 9, 15, 1, 10),
      DateTime.utc(2026, 9, 21, 1, 10),
      DateTime.utc(2026, 9, 29, 1, 10),
    ]);
  });

  test('keeps a deterministic id across duplicate source rows', () {
    final first = expandJluLessonOccurrences(
      timetable(lessons: <JluLesson>[lesson(sourceId: 'course:0')]),
    ).single;
    final second = expandJluLessonOccurrences(
      timetable(
        lessons: <JluLesson>[
          lesson(sourceId: 'course:9'),
          lesson(sourceId: 'course:10'),
        ],
      ),
    );
    expect(second, hasLength(1));
    expect(second.single.id, first.id);
  });

  test('separates rescheduled occurrences from the regular slot', () {
    final occurrences = expandJluLessonOccurrences(
      timetable(
        lessons: <JluLesson>[
          lesson(weekNumbers: <int>[1, 3]),
          lesson(weekday: 3, weekNumbers: <int>[2], note: '教务调课'),
        ],
      ),
    );
    expect(occurrences, hasLength(3));
    expect(
      occurrences.map((occurrence) => occurrence.id).toSet(),
      hasLength(3),
    );
  });

  test('rejects an invalid semester start', () {
    expect(
      () => expandJluLessonOccurrences(timetable(semesterStart: '2026-02-30')),
      throwsA(isA<JluParseException>()),
    );
  });
}
