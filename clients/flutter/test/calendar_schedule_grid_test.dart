import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/theme.dart';
import 'package:jlu_dela/core/models/assignment.dart';
import 'package:jlu_dela/core/models/lesson.dart';
import 'package:jlu_dela/core/models/local_date.dart';
import 'package:jlu_dela/core/models/todo.dart';
import 'package:jlu_dela/features/planner/calendar_entries.dart';
import 'package:jlu_dela/features/planner/calendar_grid.dart';
import 'package:jlu_dela/features/planner/calendar_schedule_grid.dart';
import 'package:jlu_dela/features/planner/calendar_views.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('HarmonyOS Sans SC')..addFont(
          rootBundle.load('assets/fonts/HarmonyOS_Sans_SC_Regular.ttf'),
        ))
        .load();
  });
  final monday = LocalDate(2026, 11, 9);
  final now = DateTime.utc(2026, 11, 9, 5);
  final todo = Todo(
    id: 'deadline',
    userId: 'test',
    notes: '',
    completed: false,
    title: '提交实验报告',
    dueKind: TodoDueKind.exact,
    dueAtUtc: DateTime.utc(2026, 11, 9, 5, 15),
    showInCalendar: true,
    createdAtUtc: now,
    updatedAtUtc: now,
    revision: 1,
  );
  final midnight = CalendarEntry.forAssignment(
    Assignment(
      id: 'midnight',
      title: '零点截止',
      sourceStatus: 'pending',
      observedAtUtc: now,
      dueKind: AssignmentDueKind.exact,
      dueAtUtc: DateTime.utc(2026, 11, 8, 16),
    ),
  );
  final late = CalendarEntry.forAssignment(
    Assignment(
      id: 'late',
      title: '深夜作业',
      sourceStatus: 'pending',
      observedAtUtc: now,
      dueKind: AssignmentDueKind.exact,
      dueAtUtc: DateTime.utc(2026, 11, 9, 15, 59),
    ),
  );
  final course = CalendarEntry.forLesson(
    Lesson(
      id: 'course',
      courseOfferingId: 'c',
      title: '课程',
      startsAtUtc: DateTime.utc(2026, 11, 9, 5),
      endsAtUtc: DateTime.utc(2026, 11, 9, 6, 30),
    ),
  );
  final allDay = CalendarEntry.forAssignment(
    Assignment(
      id: 'all-day',
      title: '全天任务',
      sourceStatus: 'pending',
      observedAtUtc: now,
      dueKind: AssignmentDueKind.dateOnly,
      dueDate: monday,
    ),
  );
  final week = CalendarWeek.build(
    [CalendarEntry.forTodo(todo), midnight, late, course, allDay],
    [for (var day = 0; day < 7; day++) monday.addDays(day)],
  );

  Future<void> pump(
    WidgetTester tester,
    double width,
    double scale, {
    bool narrowList = false,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('capture'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: narrowList
                ? SingleChildScrollView(
                    child: CalendarDayList(
                      week: week,
                      today: monday,
                      onTap: (_) {},
                    ),
                  )
                : CalendarScheduleGrid(
                    week: week,
                    now: () => now,
                    onTap: (_) {},
                  ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'places real deadlines at 13:15, 23:59 and midnight without duration',
    (tester) async {
      await pump(tester, 1280, 1);
      final axis = tester
          .getTopLeft(find.byKey(const Key('calendar-schedule-axis')))
          .dy;
      Rect rect(String id) =>
          tester.getRect(find.byKey(Key('calendar-schedule-$id')));
      final deadline = rect('todo:deadline');
      expect(deadline.top - axis, closeTo((13 * 60 + 15) / 60 * 72, 0.01));
      expect(rect('assignment:midnight').top - axis, closeTo(0, 0.01));
      expect(rect('assignment:late').top - axis, closeTo(1439 / 60 * 72, 0.01));
      expect(deadline.height, CalendarScheduleGrid.deadlineHeight);
      expect(rect('lesson:course').height, 90 / 60 * 72);
      expect(rect('lesson:course').right, lessThanOrEqualTo(deadline.left));
      expect(find.text('全天任务'), findsOneWidget);
      expect(find.textContaining('空档'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const Key('calendar-entry-assignment:late')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getRect(find.byKey(const Key('calendar-entry-assignment:late')))
            .bottom,
        lessThanOrEqualTo(900),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'many all-day tasks stay bounded and clock advances each minute',
    (tester) async {
      var clock = now;
      final busy = CalendarWeek.build(
        [
          for (var i = 0; i < 12; i++)
            CalendarEntry(
              id: 'all-$i',
              kind: CalendarEntryKind.todo,
              title: '全天 $i',
              timeLabel: '全天',
              date: monday,
            ),
        ],
        [for (var day = 0; day < 7; day++) monday.addDays(day)],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarScheduleGrid(
              week: busy,
              now: () => clock,
              onTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = tester
          .getTopLeft(find.byKey(const Key('calendar-current-time')))
          .dy;
      clock = clock.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      final after = tester
          .getTopLeft(find.byKey(const Key('calendar-current-time')))
          .dy;
      expect(after - before, closeTo(72 / 60, 0.01));
      expect(
        tester
            .getSize(find.byKey(const Key('calendar-schedule-scroll')))
            .height,
        greaterThan(200),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final width in [390.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('schedule capture $width text $scale', (tester) async {
        await pump(tester, width, scale, narrowList: width < 768);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('capture')),
        );
        final image = (await tester.runAsync(() => boundary.toImage()))!;
        final bytes = await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.png),
        );
        await tester.runAsync(() async {
          final file = File(
            '../../.local/research/schedule-${width.toInt()}-${scale.toInt()}x.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        });
        image.dispose();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
