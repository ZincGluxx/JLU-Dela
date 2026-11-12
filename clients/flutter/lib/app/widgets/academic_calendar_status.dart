import 'package:flutter/material.dart';

import '../../core/academic/academic_calendar_service.dart';
import '../../core/models/local_date.dart';
import '../../core/models/teaching_timeline.dart';
import '../theme.dart';

class AcademicCalendarStatus extends StatelessWidget {
  const AcademicCalendarStatus({
    super.key,
    required this.service,
    required this.date,
    required this.personalPeriods,
  });

  final AcademicCalendarService? service;
  final LocalDate date;
  final List<TeachingPeriod> personalPeriods;

  @override
  Widget build(BuildContext context) {
    final service = this.service;
    if (service == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final snapshot = service.snapshot;
        final calendar = service.currentCalendar;
        final term = calendar?.termOn(date);
        final week = term?.teachingWeekOn(date);
        final events = [
          for (final event in calendar?.events ?? <AcademicEvent>[])
            if (date.compareTo(event.startDate) >= 0 &&
                date.compareTo(event.endDate) <= 0)
              event.title,
        ];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                calendar == null
                    ? '官方校历尚未同步'
                    : '全校校历 · ${calendar.academicYear} · ${term?.name ?? '非学期内'}'
                          '${week == null ? '' : ' · 第 $week 教学周'}'
                          '${events.isEmpty ? '' : ' · ${events.join(' / ')}'}',
                key: const Key('academic-calendar-status'),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              if (personalPeriods.isEmpty && calendar != null)
                Text(
                  '节次：吉大教务处官方作息（${calendar.periodsEffectiveFromTerm}起）',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              if (personalPeriods.isNotEmpty)
                Text(
                  '节次：个人教务同步',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              if (snapshot.error != null)
                Text(
                  calendar == null ? '校历同步失败，请重试' : '校历更新失败，保留上次成功数据',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              TextButton(
                key: const Key('academic-calendar-details'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => ListenableBuilder(
                    listenable: service,
                    builder: (context, _) {
                      final calendar = service.currentCalendar;
                      return AlertDialog(
                        title: const Text('吉林大学校历'),
                        content: SizedBox(
                          width: 560,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Wrap(
                                  spacing: AppSpacing.sm,
                                  children: [
                                    for (final year in [
                                      '2025-2026',
                                      '2026-2027',
                                    ])
                                      ChoiceChip(
                                        label: Text(year),
                                        selected:
                                            service.snapshot.academicYear ==
                                            year,
                                        onSelected:
                                            service.snapshot.isRefreshing
                                            ? null
                                            : (_) => service.load(
                                                academicYear: year,
                                              ),
                                      ),
                                  ],
                                ),
                                if (service.snapshot.isRefreshing)
                                  const LinearProgressIndicator(),
                                if (service.snapshot.error != null)
                                  const Text('同步失败，保留上次成功校历'),
                                if (calendar != null) ...[
                                  for (final term in calendar.terms)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppSpacing.sm,
                                      ),
                                      child: Text(
                                        '${term.name} · ${term.startDate}–${term.endDate}\n${term.teachingWeeks} 教学周',
                                      ),
                                    ),
                                  for (final event in calendar.events)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: AppSpacing.sm,
                                      ),
                                      child: Text(
                                        '${event.title}\n${event.startDate}–${event.endDate}',
                                      ),
                                    ),
                                  for (final note in calendar.notes) Text(note),
                                  const SizedBox(height: AppSpacing.md),
                                  SelectableText(
                                    '版本：${calendar.version}\n校历来源：${calendar.sourceUrl}\n作息来源：${calendar.periodsSourceUrl}\n发布：${calendar.publishedAt}',
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('关闭'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                child: const Text('查看校历'),
              ),
              TextButton.icon(
                key: const Key('academic-calendar-refresh'),
                onPressed: snapshot.isRefreshing
                    ? null
                    : () => service.refresh(),
                icon: const Icon(Icons.sync, size: 16),
                label: Text(snapshot.isRefreshing ? '正在同步校历' : '同步官方校历'),
              ),
            ],
          ),
        );
      },
    );
  }
}
