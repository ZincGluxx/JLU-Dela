import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/local_migrations.dart';
import 'package:jlu_dela/app/theme.dart';
import 'package:jlu_dela/core/models/assignment.dart';
import 'package:jlu_dela/core/models/lesson.dart';
import 'package:jlu_dela/core/models/local_date.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/models/todo.dart';
import 'package:jlu_dela/core/source/campus_login.dart';
import 'package:jlu_dela/core/source/chaoxing_access.dart';
import 'package:jlu_dela/core/source/source_context.dart';
import 'package:jlu_dela/core/source/source_portal.dart';
import 'package:jlu_dela/core/source/source_session.dart';
import 'package:jlu_dela/core/storage/course_store.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
import 'package:jlu_dela/core/storage/local_draft_store.dart';
import 'package:jlu_dela/core/storage/local_workspace.dart';
import 'package:jlu_dela/core/storage/queries.dart';
import 'package:jlu_dela/core/storage/source_snapshot_store.dart';
import 'package:jlu_dela/core/storage/todo_store.dart';
import 'package:jlu_dela/features/planner/calendar_page.dart';

final DateTime _now = DateTime.utc(2026, 11, 12, 2);

Lesson _lesson() {
  return Lesson(
    id: 'l1',
    courseOfferingId: 'c1',
    title: '高等数学',
    startsAtUtc: DateTime.utc(2026, 11, 9),
    endsAtUtc: DateTime.utc(2026, 11, 9, 1, 40),
    location: '逸夫楼201',
    periodStart: 1,
    periodEnd: 2,
  );
}

Assignment _assignment({
  String id = 'a1',
  String title = '第三章习题',
  AssignmentDueKind dueKind = AssignmentDueKind.relative,
  LocalDate? dueDate,
  DateTime? dueAtUtc,
  String? timingText = '3 天后截止',
}) {
  return Assignment(
    id: id,
    title: title,
    sourceStatus: 'pending',
    dueKind: dueKind,
    dueDate: dueDate,
    dueAtUtc: dueAtUtc,
    timingText: timingText,
    observedAtUtc: DateTime.utc(2026, 11, 11, 1),
  );
}

class _FakeLessonQuery implements LessonQuery {
  _FakeLessonQuery({this.lessons = const [], this.error});

  List<Lesson> lessons;
  Object? error;
  Completer<List<Lesson>>? pending;
  final List<(LocalDate, LocalDate)> calls = [];

  @override
  Future<List<Lesson>> lessonsBetween(LocalDate from, LocalDate to) {
    calls.add((from, to));
    final waiting = pending;
    if (waiting != null) {
      return waiting.future;
    }
    final failure = error;
    if (failure != null) {
      return Future.error(failure);
    }
    return Future.value(lessons);
  }
}

class _FakeAssignmentQuery implements AssignmentQuery {
  _FakeAssignmentQuery({this.assignments = const []});

  List<Assignment> assignments;
  final List<({LocalDate? from, LocalDate? to, bool includeUndated})> calls =
      [];

  @override
  Future<List<Assignment>> list({
    String? courseId,
    bool includeUndated = true,
    LocalDate? from,
    LocalDate? to,
  }) {
    calls.add((from: from, to: to, includeUndated: includeUndated));
    return Future.value(assignments);
  }
}

class _CalendarHarness {
  _CalendarHarness._({
    required this.database,
    required this.workspace,
    required this.snapshots,
    required this.sessions,
    required this.lessonQuery,
    required this.assignmentQuery,
    required this.login,
  });

  final LocalDatabase database;
  final LocalWorkspace workspace;
  final SourceSnapshotStore snapshots;
  final SourceSessionRegistry sessions;
  final _FakeLessonQuery lessonQuery;
  final _FakeAssignmentQuery assignmentQuery;
  final FakeCampusLogin login;

  static Future<_CalendarHarness> create({
    List<Lesson> lessons = const [],
    List<Assignment> assignments = const [],
    bool delayLessons = false,
    bool failLessons = false,
  }) async {
    final database = await LocalDatabase.openInMemory(
      migrations: appLocalMigrations,
    );
    addTearDown(database.close);
    final sessions = SourceSessionRegistry();
    final snapshots = SourceSnapshotStore(database, 'user-a');
    final lessonQuery = _FakeLessonQuery(
      lessons: lessons,
      error: failLessons ? Exception('课程读取失败') : null,
    );
    if (delayLessons) {
      lessonQuery.pending = Completer<List<Lesson>>();
    }
    final assignmentQuery = _FakeAssignmentQuery(assignments: assignments);
    final login = FakeCampusLogin();
    final http = UnavailableSourceHttpClient(sessions: sessions);
    const browser = UnsupportedSourcePageOpener();
    final workspace = LocalWorkspace(
      userId: 'user-a',
      database: database,
      now: () => _now,
      todos: TodoStore(database, 'user-a', now: () => _now),
      drafts: LocalDraftStore(database, 'user-a'),
      courses: CourseStore(database, 'user-a', now: () => _now),
      sources: snapshots,
      lessons: lessonQuery,
      assignments: assignmentQuery,
      chaoxing: const UnavailableChaoxingAccess(),
      sessions: sessions,
      http: http,
      campusLogin: login,
      browser: browser,
      source: SourceContext(
        sessions: sessions,
        http: http,
        campusLogin: login,
        browser: browser,
      ),
    );
    return _CalendarHarness._(
      database: database,
      workspace: workspace,
      snapshots: snapshots,
      sessions: sessions,
      lessonQuery: lessonQuery,
      assignmentQuery: assignmentQuery,
      login: login,
    );
  }
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 3; index++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Future<void> _pumpCalendar(
  WidgetTester tester,
  _CalendarHarness harness, {
  Size size = const Size(1280, 900),
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: CalendarPage(workspace: harness.workspace)),
    ),
  );
  await tester.pump();
  if (settle) {
    await _pumpFrames(tester);
  }
}

void main() {
  testWidgets('加载态之后显示课程、作业、待办与真实来源状态', (tester) async {
    final harness = await _CalendarHarness.create(
      lessons: [_lesson()],
      assignments: [_assignment()],
      delayLessons: true,
    );
    await harness.workspace.todos.create(
      title: '交实验报告',
      due: TodoDue.exact(DateTime.utc(2026, 11, 11, 2)),
      showInCalendar: true,
    );

    await _pumpCalendar(tester, harness, settle: false);
    expect(find.byKey(const Key('calendar-loading')), findsOneWidget);

    harness.lessonQuery.pending!.complete([_lesson()]);
    await _pumpFrames(tester);
    expect(find.byKey(const Key('calendar-loading')), findsNothing);
    expect(find.text('高等数学'), findsOneWidget);
    expect(find.text('第三章习题'), findsOneWidget);
    expect(find.text('交实验报告'), findsOneWidget);
    expect(find.text('08:00–09:40 · 逸夫楼201'), findsOneWidget);
    expect(find.text('教务系统：未登录来源'), findsOneWidget);
    expect(find.text('学习通：未登录来源'), findsOneWidget);
    expect(find.byKey(const Key('calendar-login-jluIedu')), findsOneWidget);
    expect(find.byKey(const Key('calendar-login-chaoxing')), findsOneWidget);
  });

  testWidgets('空库引导连接来源或新建待办', (tester) async {
    final harness = await _CalendarHarness.create();
    await _pumpCalendar(tester, harness);

    expect(find.byKey(const Key('calendar-empty')), findsOneWidget);
    expect(find.text('还没有可显示的安排'), findsOneWidget);
    expect(find.textContaining('新建待办'), findsOneWidget);
    expect(find.byKey(const Key('calendar-login-jluIedu')), findsOneWidget);
  });

  testWidgets('已登录但尚未同步与上次成功可区分', (tester) async {
    final harness = await _CalendarHarness.create();
    harness.sessions.save(SourceAuthGroup.jluCampus, const [
      SourceCookie(name: 'JSESSIONID', value: 'memory', domain: 'jlu.edu.cn'),
    ]);
    harness.sessions.save(SourceAuthGroup.chaoxing, const [
      SourceCookie(name: 'cookie', value: 'memory', domain: 'chaoxing.com'),
    ]);
    await harness.snapshots.recordSuccess(
      SourceKind.chaoxing,
      'assignments',
      observedAt: DateTime.utc(2026, 11, 12, 2),
    );

    await _pumpCalendar(tester, harness);

    expect(find.text('教务系统：已登录 · 尚未同步'), findsOneWidget);
    expect(find.text('学习通：上次成功 2026年11月12日 10:00'), findsOneWidget);
    expect(find.byKey(const Key('calendar-login-jluIedu')), findsNothing);
  });

  testWidgets('读取失败显示错误并可重试', (tester) async {
    final harness = await _CalendarHarness.create(
      lessons: [_lesson()],
      failLessons: true,
    );
    await _pumpCalendar(tester, harness);

    expect(find.byKey(const Key('calendar-error')), findsOneWidget);
    expect(find.text('高等数学'), findsNothing);

    harness.lessonQuery.error = null;
    await tester.tap(find.byKey(const Key('calendar-retry')));
    await _pumpFrames(tester);

    expect(find.byKey(const Key('calendar-error')), findsNothing);
    expect(find.text('高等数学'), findsOneWidget);
  });

  testWidgets('周/月/列表三种视图切换并重新读取范围', (tester) async {
    final harness = await _CalendarHarness.create(
      lessons: [_lesson()],
      assignments: [
        _assignment(
          id: 'a2',
          title: '实验预习',
          dueKind: AssignmentDueKind.dateOnly,
          dueDate: const LocalDate(2026, 11, 10),
          timingText: null,
        ),
      ],
    );
    await _pumpCalendar(tester, harness);

    expect(find.text('周一 11/9'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('calendar-range-label'))).data,
      '2026年11月9日 – 11月15日',
    );
    expect(harness.lessonQuery.calls.last, (
      const LocalDate(2026, 11, 9),
      const LocalDate(2026, 11, 16),
    ));

    await tester.tap(find.byKey(const Key('calendar-view-month')));
    await _pumpFrames(tester);
    expect(find.text('周一'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('calendar-range-label'))).data,
      '2026年11月',
    );
    expect(harness.lessonQuery.calls.last, (
      const LocalDate(2026, 10, 26),
      const LocalDate(2026, 12, 7),
    ));

    await tester.tap(find.byKey(const Key('calendar-view-list')));
    await _pumpFrames(tester);
    expect(find.textContaining('2026年11月9日'), findsOneWidget);
    expect(find.textContaining('2026年11月10日'), findsOneWidget);
    expect(harness.lessonQuery.calls.last, (
      const LocalDate(2026, 11, 1),
      const LocalDate(2026, 12, 1),
    ));
  });

  testWidgets('来源筛选隐藏对应条目', (tester) async {
    final harness = await _CalendarHarness.create(
      lessons: [_lesson()],
      assignments: [_assignment()],
    );
    await _pumpCalendar(tester, harness);

    expect(find.text('高等数学'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar-filter-lesson')));
    await tester.pump();
    expect(find.text('高等数学'), findsNothing);
    expect(find.text('第三章习题'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-filter-lesson')));
    await tester.pump();
    expect(find.text('高等数学'), findsOneWidget);
  });

  testWidgets('显示已完成开关控制完成待办', (tester) async {
    final harness = await _CalendarHarness.create();
    final todo = await harness.workspace.todos.create(
      title: '已完成待办',
      due: TodoDue.exact(DateTime.utc(2026, 11, 11, 2)),
      showInCalendar: true,
    );
    await harness.workspace.todos.setCompleted(
      todo.id,
      revision: todo.revision,
      completed: true,
    );

    await _pumpCalendar(tester, harness);
    expect(find.text('已完成待办'), findsNothing);

    await tester.tap(find.byKey(const Key('calendar-show-completed')));
    await tester.pump();
    expect(find.text('已完成待办'), findsOneWidget);
  });

  testWidgets('点击课程、作业、待办显示只读详情', (tester) async {
    final harness = await _CalendarHarness.create(
      lessons: [_lesson()],
      assignments: [
        _assignment(
          id: 'relative',
          title: '第三章习题',
          dueKind: AssignmentDueKind.relative,
          timingText: '3 天后截止',
        ),
      ],
    );
    await harness.workspace.todos.create(
      title: '交实验报告',
      notes: '带笔记本',
      due: TodoDue.exact(DateTime.utc(2026, 11, 11, 2)),
      color: CalendarColor.teal,
      showInCalendar: true,
    );
    final todo = (await harness.workspace.todos.list()).single;
    await _pumpCalendar(tester, harness);

    await tester.ensureVisible(
      find.byKey(const Key('calendar-entry-lesson:l1')),
    );
    await tester.tap(find.byKey(const Key('calendar-entry-lesson:l1')));
    await tester.pumpAndSettle();
    expect(find.text('教务课表 · 只读'), findsOneWidget);
    expect(find.text('第 1–2 节'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar-detail-close')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('calendar-entry-assignment:relative')),
    );
    await tester.tap(
      find.byKey(const Key('calendar-entry-assignment:relative')),
    );
    await tester.pumpAndSettle();
    expect(find.text('平台原文'), findsOneWidget);
    expect(find.text('截止时间待确认'), findsOneWidget);
    expect(find.text('学习通 · 只读'), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar-detail-close')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(Key('calendar-entry-todo:${todo.id}')),
    );
    await tester.tap(find.byKey(Key('calendar-entry-todo:${todo.id}')));
    await tester.pumpAndSettle();
    expect(find.text('带笔记本'), findsOneWidget);
    expect(find.text('湖青'), findsOneWidget);
    expect(find.textContaining('在「待办」页编辑'), findsOneWidget);
  });

  testWidgets('待办详情可切换完成状态', (tester) async {
    final harness = await _CalendarHarness.create();
    final todo = await harness.workspace.todos.create(
      title: '交实验报告',
      due: TodoDue.exact(DateTime.utc(2026, 11, 11, 2)),
      showInCalendar: true,
    );
    await _pumpCalendar(tester, harness);

    await tester.tap(find.byKey(Key('calendar-entry-todo:${todo.id}')));
    await tester.pumpAndSettle();
    expect(find.text('标记为完成'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-todo-toggle')));
    await tester.pumpAndSettle();

    final updated = (await harness.workspace.todos.list()).single;
    expect(updated.completed, isTrue);
    expect(find.text('标记为未完成'), findsOneWidget);
  });

  testWidgets('待办 revision 冲突时提示并刷新', (tester) async {
    final harness = await _CalendarHarness.create();
    final todo = await harness.workspace.todos.create(
      title: '交实验报告',
      due: TodoDue.exact(DateTime.utc(2026, 11, 11, 2)),
      showInCalendar: true,
    );
    await _pumpCalendar(tester, harness);

    await tester.tap(find.byKey(Key('calendar-entry-todo:${todo.id}')));
    await tester.pumpAndSettle();

    final current = (await harness.workspace.todos.list()).single;
    await harness.workspace.todos.setCompleted(
      current.id,
      revision: current.revision,
      completed: true,
    );

    await tester.tap(find.byKey(const Key('calendar-todo-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar-todo-conflict')), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(find.text('标记为未完成'), findsOneWidget);
  });

  testWidgets('登录入口调用 CampusLogin 并反馈结果', (tester) async {
    final harness = await _CalendarHarness.create();
    await _pumpCalendar(tester, harness);

    await tester.tap(find.byKey(const Key('calendar-login-jluIedu')));
    await tester.pump();

    expect(harness.login.attempted, [SourceKind.jluIedu]);
    expect(find.text('教务系统已连接'), findsOneWidget);
  });

  testWidgets('320 宽下三种视图都不溢出', (tester) async {
    final harness = await _CalendarHarness.create(
      lessons: [_lesson()],
      assignments: [_assignment()],
    );
    await harness.workspace.todos.create(
      title: '交实验报告',
      due: TodoDue.exact(DateTime.utc(2026, 11, 11, 2)),
      showInCalendar: true,
    );
    await _pumpCalendar(tester, harness, size: const Size(320, 700));

    expect(tester.takeException(), isNull);
    expect(find.text('周一 11月9日'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-view-month')));
    await _pumpFrames(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('calendar-view-list')));
    await _pumpFrames(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('加载中可区分，数据到达后替换占位', (tester) async {
    final harness = await _CalendarHarness.create(
      lessons: [_lesson()],
      delayLessons: true,
    );
    await _pumpCalendar(tester, harness, settle: false);

    expect(find.byKey(const Key('calendar-loading')), findsOneWidget);
    harness.lessonQuery.pending!.complete([_lesson()]);
    await _pumpFrames(tester);

    expect(find.byKey(const Key('calendar-loading')), findsNothing);
    expect(find.text('高等数学'), findsOneWidget);
  });
}
