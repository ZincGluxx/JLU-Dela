import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/local_date.dart';
import '../../core/models/school_time.dart';
import 'calendar_entries.dart';
import 'calendar_grid.dart';
import 'calendar_time.dart';
import 'calendar_views.dart';

class CalendarScheduleGrid extends StatefulWidget {
  const CalendarScheduleGrid({
    super.key,
    required this.week,
    required this.now,
    required this.onTap,
  });

  final CalendarWeek week;
  final DateTime Function() now;
  final ValueChanged<CalendarEntry> onTap;

  static const hourHeight = 72.0;
  static const axisWidth = 64.0;
  static const deadlineHeight = 48.0;

  @override
  State<CalendarScheduleGrid> createState() => _CalendarScheduleGridState();
}

class _CalendarScheduleGridState extends State<CalendarScheduleGrid> {
  final _scroll = ScrollController();
  bool _positioned = false;
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final hourHeight = CalendarScheduleGrid.hourHeight * scale;
    final axisWidth = CalendarScheduleGrid.axisWidth * scale;
    final markerHeight = CalendarScheduleGrid.deadlineHeight * scale;
    final today = schoolDateOf(widget.now());
    if (!_positioned) {
      _positioned = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          final inWeek = widget.week.days.any((day) => day.date == today);
          final schoolNow = widget.now().toUtc().add(schoolUtcOffset);
          final hour = inWeek
              ? (schoolNow.hour + schoolNow.minute / 60 - 1).clamp(0, 23)
              : 8;
          _scroll.jumpTo(
            (hour * hourHeight).clamp(0, _scroll.position.maxScrollExtent),
          );
        }
      });
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final contentWidth = (axisWidth + 7 * 112 * scale).clamp(
          width,
          double.infinity,
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(width: axisWidth),
                    for (final day in widget.week.days)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          color: day.date == today ? AppTheme.blueSoft : null,
                          child: Text(
                            '${calendarWeekdayLabel(day.date)} ${day.date.month}/${day.date.day}${day.date == today ? ' · 今天' : ''}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: day.date == today
                                      ? AppTheme.primary
                                      : null,
                                ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (widget.week.hasAllDay)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 144),
                    child: SingleChildScrollView(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: axisWidth, child: const Text('全天')),
                          for (final day in widget.week.days)
                            Expanded(
                              child: Column(
                                children: [
                                  for (final entry in day.allDay)
                                    Padding(
                                      padding: const EdgeInsets.all(
                                        AppSpacing.xs,
                                      ),
                                      child: CalendarEntryCard(
                                        entry: entry,
                                        onTap: widget.onTap,
                                        compact: true,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: Scrollbar(
                    controller: _scroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      key: const Key('calendar-schedule-scroll'),
                      controller: _scroll,
                      child: SizedBox(
                        key: const Key('calendar-schedule-axis'),
                        height: 24 * hourHeight + markerHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: axisWidth,
                              child: Stack(
                                children: [
                                  for (var hour = 0; hour <= 24; hour++)
                                    Positioned(
                                      top: hour * hourHeight,
                                      left: AppSpacing.xs,
                                      child: Text(
                                        '${hour.toString().padLeft(2, '0')}:00',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            for (final day in widget.week.days)
                              Expanded(
                                child: _day(
                                  context,
                                  day,
                                  today,
                                  hourHeight,
                                  markerHeight,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _day(
    BuildContext context,
    CalendarDay day,
    LocalDate today,
    double hourHeight,
    double markerHeight,
  ) {
    final entries = [for (final slot in day.timed.values) ...slot]
      ..sort((a, b) => a.slot!.compareTo(b.slot!));
    final lanes = <List<({CalendarEntry entry, double top, double height})>>[];
    for (final entry in entries) {
      final clock = entry.slot!.split(':');
      final minute = int.parse(clock[0]) * 60 + int.parse(clock[1]);
      final lesson = entry.lesson;
      final height = lesson == null
          ? markerHeight
          : lesson.endsAtUtc.difference(lesson.startsAtUtc).inMinutes /
                60 *
                hourHeight;
      final top = minute / 60 * hourHeight;
      final lane = lanes.indexWhere(
        (lane) => lane.last.top + lane.last.height <= top,
      );
      final item = (entry: entry, top: top, height: height);
      if (lane < 0) {
        lanes.add([item]);
      } else {
        lanes[lane].add(item);
      }
    }
    final schoolNow = widget.now().toUtc().add(schoolUtcOffset);
    final nowTop = (schoolNow.hour * 60 + schoolNow.minute) / 60 * hourHeight;
    return Container(
      color: day.date == today
          ? AppTheme.blueSoft.withValues(alpha: 0.25)
          : null,
      child: Stack(
        children: [
          for (var hour = 0; hour <= 24; hour++)
            Positioned(
              top: hour * hourHeight,
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
                        for (final item in lane)
                          Positioned(
                            top: item.top,
                            left: AppSpacing.xs,
                            right: AppSpacing.xs,
                            height: item.height,
                            child: _entry(context, item.entry),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (day.date == today)
            Positioned(
              key: const Key('calendar-current-time'),
              top: nowTop,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(height: 2, color: AppTheme.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _entry(BuildContext context, CalendarEntry entry) {
    final tone = CalendarTone.of(entry);
    final deadline = entry.lesson == null;
    return Tooltip(
      message: '${deadline ? '截止时间 · ' : ''}${entry.semanticsLabel}',
      child: Material(
        color: deadline
            ? Theme.of(context).colorScheme.surface
            : tone.background,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: InkWell(
          key: Key('calendar-entry-${entry.id}'),
          onTap: () => widget.onTap(entry),
          child: Container(
            key: Key('calendar-schedule-${entry.id}'),
            decoration: deadline
                ? BoxDecoration(
                    border: Border(
                      top: BorderSide(color: tone.foreground, width: 2),
                    ),
                  )
                : null,
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deadline ? '● ${entry.slot}' : entry.timeLabel,
                    maxLines: deadline ? 1 : null,
                    overflow: deadline ? TextOverflow.ellipsis : null,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: tone.foreground),
                  ),
                  Text(
                    entry.title,
                    maxLines: deadline ? 1 : null,
                    overflow: deadline ? TextOverflow.ellipsis : null,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: tone.foreground,
                      decoration: entry.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
