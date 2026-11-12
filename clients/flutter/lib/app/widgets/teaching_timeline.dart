import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/lesson.dart';
import '../../core/models/local_date.dart';
import '../../core/models/school_time.dart';
import '../../core/models/teaching_timeline.dart';

class TeachingTimelineGrid extends StatelessWidget {
  const TeachingTimelineGrid({
    super.key,
    required this.days,
    required this.today,
    required this.periods,
    required this.lessons,
    required this.lessonBuilder,
  });

  final List<LocalDate> days;
  final LocalDate today;
  final List<TeachingPeriod> periods;
  final List<Lesson> lessons;
  final Widget Function(Lesson lesson) lessonBuilder;

  static const axisWidth = 112.0;
  static const minuteHeight = 2.0;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final rowMinuteHeight = minuteHeight * scale;
    final campusNames = periods.map((period) => period.campus).toSet().toList();
    if (campusNames.isEmpty) campusNames.add('');
    final campusAxisWidth = axisWidth * scale;
    final timeline = TeachingTimeline(periods: periods, lessons: lessons);
    final boundaries = timeline.boundaries;
    if (boundaries.isEmpty) return const SizedBox.shrink();
    final start = boundaries.first;
    final end = boundaries.last;
    double offset(int minute) =>
        (timeline.displayMinute(minute) - timeline.displayMinute(start)) *
        rowMinuteHeight;
    final grouped = <(int, int, int), List<String>>{};
    for (final period in periods) {
      grouped
          .putIfAbsent((
            period.period,
            period.startMinute,
            period.endMinute,
          ), () => [])
          .add(period.campus);
    }
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (periods.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              '尚未同步节次时间，按已存课程时间显示',
              style: TextStyle(color: AppTheme.muted),
            ),
          ),
        Row(
          children: [
            SizedBox(width: campusAxisWidth * campusNames.length),
            for (final day in days)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    '周${'一二三四五六日'[day.weekday - 1]} '
                    '${day.month}/${day.day}${day == today ? ' · 今天' : ''}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: day == today ? AppTheme.primary : AppTheme.muted,
                      fontWeight: day == today ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(
          height: offset(end) + AppSpacing.lg,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final campus in campusNames)
                SizedBox(
                  width: campusAxisWidth,
                  child: Stack(
                    children: [
                      for (final entry in grouped.entries)
                        if (entry.value.contains(campus))
                          Positioned(
                            top: offset(entry.key.$2),
                            left: 0,
                            right: AppSpacing.sm,
                            child: Text(
                              '${campus.isEmpty ? '' : '$campus · '}第 ${entry.key.$1} 节\n'
                              '${teachingClock(entry.key.$2)}–${teachingClock(entry.key.$3)}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                      if (periods.isEmpty)
                        Positioned(top: 0, child: Text(teachingClock(start))),
                    ],
                  ),
                ),
              for (final day in days)
                Expanded(child: _day(context, day, offset)),
            ],
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final minimumWidth =
            campusAxisWidth * campusNames.length +
            days.length * AppSpacing.xxl * 2 * scale;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: constraints.maxWidth < minimumWidth
                ? minimumWidth
                : constraints.maxWidth,
            child: content,
          ),
        );
      },
    );
  }

  Widget _day(
    BuildContext context,
    LocalDate day,
    double Function(int minute) offset,
  ) {
    final dayLessons =
        lessons
            .where((lesson) => schoolDateOf(lesson.startsAtUtc) == day)
            .toList()
          ..sort((a, b) => a.startsAtUtc.compareTo(b.startsAtUtc));
    final lanes = <List<Lesson>>[];
    for (final lesson in dayLessons) {
      final available = lanes.indexWhere(
        (lane) => !lane.last.endsAtUtc.isAfter(lesson.startsAtUtc),
      );
      if (available < 0) {
        lanes.add([lesson]);
      } else {
        lanes[available].add(lesson);
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: day == today ? AppTheme.blueSoft.withValues(alpha: 0.3) : null,
        border: const Border(left: BorderSide(color: AppTheme.border)),
      ),
      child: Stack(
        children: [
          for (final period in periods)
            Positioned(
              top: offset(period.startMinute),
              left: 0,
              right: 0,
              child: const Divider(height: 1),
            ),
          Positioned.fill(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final lane in lanes)
                  Expanded(
                    child: Stack(
                      children: [
                        for (final lesson in lane)
                          Positioned(
                            top: offset(
                              teachingMinuteOfDay(lesson.startsAtUtc),
                            ),
                            left: AppSpacing.xs,
                            right: AppSpacing.xs,
                            height:
                                offset(teachingMinuteOfDay(lesson.endsAtUtc)) -
                                offset(teachingMinuteOfDay(lesson.startsAtUtc)),
                            child: Tooltip(
                              message:
                                  '${lesson.title}\n'
                                  '${formatSchoolClock(lesson.startsAtUtc)}–${formatSchoolClock(lesson.endsAtUtc)}'
                                  '${lesson.location == null ? '' : '\n${lesson.location}'}',
                              child: lessonBuilder(lesson),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
