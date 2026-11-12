import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/theme.dart';
import 'package:jlu_dela/app/widgets/teaching_timeline.dart';
import 'package:jlu_dela/core/models/lesson.dart';
import 'package:jlu_dela/core/models/local_date.dart';
import 'package:jlu_dela/core/models/teaching_timeline.dart';

const periods = [
  TeachingPeriod(period: 4, campus: '前卫', startMinute: 655, endMinute: 700),
  TeachingPeriod(period: 5, campus: '前卫', startMinute: 810, endMinute: 855),
];

Lesson lesson(String id, int hour, int minute, int endHour, int endMinute) =>
    Lesson(
      id: id,
      courseOfferingId: 'course',
      title: id,
      startsAtUtc: DateTime.utc(2026, 11, 9, hour - 8, minute),
      endsAtUtc: DateTime.utc(2026, 11, 9, endHour - 8, endMinute),
    );

void main() {
  test('keeps actual periods and gaps without inventing missing periods', () {
    final timeline = TeachingTimeline(periods: periods, lessons: []);
    expect(timeline.boundaries, [655, 700, 810, 855]);
    expect(timeline.gaps, [(700, 810)]);
  });

  test('compresses only empty breaks and preserves lunchtime lessons', () {
    final empty = TeachingTimeline(periods: periods, lessons: []);
    expect(empty.displayMinute(810) - empty.displayMinute(700), 4);
    final occupied = TeachingTimeline(
      periods: periods,
      lessons: [lesson('午间课程', 11, 40, 13, 30)],
    );
    expect(occupied.gaps, isEmpty);
    expect(occupied.displayMinute(810) - occupied.displayMinute(700), 110);
  });

  test('extends bounds to actual early and late courses', () {
    final timeline = TeachingTimeline(
      periods: periods,
      lessons: [lesson('早课', 7, 20, 8, 0), lesson('晚课', 22, 0, 23, 0)],
    );
    expect(timeline.boundaries.first, 440);
    expect(timeline.boundaries.last, 1380);
    expect(TeachingTimeline(periods: [], lessons: []).boundaries, isEmpty);
  });

  testWidgets('keeps shifted campus axes separate at 2x text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: TeachingTimelineGrid(
              days: [LocalDate(2026, 11, 9)],
              today: LocalDate(2026, 11, 9),
              periods: [
                ...periods,
                const TeachingPeriod(
                  period: 4,
                  campus: '南岭',
                  startMinute: 660,
                  endMinute: 705,
                ),
              ],
              lessons: [],
              lessonBuilder: (_) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    final first = tester.getRect(find.textContaining('前卫 · 第 4 节'));
    final second = tester.getRect(find.textContaining('南岭 · 第 4 节'));
    expect(first.right, lessThanOrEqualTo(second.left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses exact course duration and separates concurrent lessons', (
    tester,
  ) async {
    final first = lesson('A', 10, 55, 11, 40);
    final second = lesson('B', 11, 0, 11, 30);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: TeachingTimelineGrid(
              days: [LocalDate(2026, 11, 9)],
              today: LocalDate(2026, 11, 9),
              periods: periods,
              lessons: [first, second],
              lessonBuilder: (item) => Container(key: Key(item.id)),
            ),
          ),
        ),
      ),
    );
    final a = tester.getRect(find.byKey(const Key('A')));
    final b = tester.getRect(find.byKey(const Key('B')));
    expect(a.height, 45 * TeachingTimelineGrid.minuteHeight);
    expect(b.top - a.top, 5 * TeachingTimelineGrid.minuteHeight);
    expect(a.right, lessThanOrEqualTo(b.left));
    expect(find.textContaining('第 4 节'), findsOneWidget);
    expect(find.textContaining('空档'), findsNothing);
    final fourth = tester.getTopLeft(find.textContaining('第 4 节'));
    final fifth = tester.getTopLeft(find.textContaining('第 5 节'));
    expect(fifth.dy - fourth.dy, (45 + 4) * TeachingTimelineGrid.minuteHeight);
    expect(tester.takeException(), isNull);
  });
}
