import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/local_workbench.dart';
import 'package:jlu_dela/app/theme.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/source.dart';
import 'package:jlu_dela/core/source/campus_login.dart';
import 'package:jlu_dela/core/source/source_page_opener_impl.dart';
import 'package:jlu_dela/core/storage/course_store.dart';
import 'package:jlu_dela/features/assignments/assignments_page.dart';
import 'package:jlu_dela/features/assignments/course_binding_store.dart';

import '../source_fakes.dart';
import 'chaoxing_test_support.dart';

Future<void> exerciseCourseBindingFlow(WidgetTester tester) async {
  final harness = await ChaoxingHarness.create(connected: false);
  configureSingleCourse(harness.http);
  final webView = FakeSourceWebView();
  final login = RecordingCampusLogin(sessions: harness.sessions);
  final data = buildWorkbenchData(
    database: harness.database,
    userId: 'user-a',
    sessions: harness.sessions,
    http: harness.http,
    campusLogin: login,
    browser: InAppWebViewSourcePageOpener(
      sessions: harness.sessions,
      webView: webView,
    ),
    now: () => DateTime.utc(2026, 11, 3, 2),
  );
  addTearDown(data.dispose);
  final courses = data.workspace.courses;
  final target = await courses.upsert(
    const SourceCourse(
      source: SourceKind.jluIedu,
      sourceScope: '2026-2027-1',
      sourceId: 'kb-1',
      semesterId: 'teaching:user-a:2026-2027-1',
      name: '示例课程甲',
      teacher: '教务教师',
    ),
  );
  await courses.upsert(
    const SourceCourse(
      source: SourceKind.jluIedu,
      sourceScope: '2025-2026-1',
      sourceId: 'kb-1',
      semesterId: 'teaching:user-a:2025-2026-1',
      name: '示例课程甲',
      teacher: '另一学期教师',
    ),
  );
  final bindings = CourseBindingStore(harness.database, 'user-a', courses);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: AssignmentsPage(
          workspace: data.workspace,
          store: data.chaoxingStore,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.textContaining('学习通未连接'), findsOneWidget);
  await tester.tap(find.byKey(const Key('assignments-login')));
  await tester.pumpAndSettle();
  expect(login.attempted, [SourceKind.chaoxing]);
  expect(find.text('示例作业一'), findsOneWidget);
  expect(await bindings.list(), isEmpty);
  final platform = (await data.chaoxingStore.listCourses()).single;
  await tester.tap(find.byKey(const Key('assignments-manage-courses')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('course-binding-${platform.id}')));
  await tester.pumpAndSettle();
  expect(find.textContaining('2025-2026-1'), findsWidgets);
  expect(find.textContaining('2026-2027-1'), findsWidgets);
  await tester.tap(find.byKey(Key('binding-target-${target.id}')));
  await tester.pumpAndSettle();
  expect((await bindings.list()).single.matchesTeaching(target), isTrue);
  expect(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('教务：示例课程甲 · 2026-2027-1'),
    ),
    findsOneWidget,
  );
  await tester.tap(find.widgetWithText(TextButton, '完成'));
  await tester.pumpAndSettle();
  expect(find.textContaining('教务：示例课程甲 · 2026-2027-1'), findsWidgets);
  final work = (await data.chaoxingStore.list()).firstWhere(
    (item) => item.title == '示例作业一',
  );
  await tester.ensureVisible(find.byKey(Key('assignment-open-${work.id}')));
  await tester.tap(find.byKey(Key('assignment-open-${work.id}')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('source-page-dialog')), findsOneWidget);
  expect(webView.controller.calls, ['setCookies', 'load']);
  expect(webView.controller.loadedUri!.queryParameters['workId'], 'work-1');
  await tester.tap(find.byKey(const Key('source-page-close')));
  await tester.pumpAndSettle();

  harness.http.routes.clear();
  harness.http.on(baseUrl, '', statusCode: 503);
  await tester.ensureVisible(find.byKey(const Key('assignments-refresh')));
  await tester.tap(find.byKey(const Key('assignments-refresh')));
  await tester.pumpAndSettle();
  expect(await data.chaoxingStore.list(), hasLength(2));
  expect((await bindings.list()).single.matchesTeaching(target), isTrue);
  expect(find.textContaining('已保留上次的本地缓存'), findsOneWidget);

  harness.http.routes.clear();
  harness.http.on(baseUrl, loginPage());
  await tester.tap(find.byKey(const Key('assignments-refresh')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('assignments-login')), findsOneWidget);
  expect(await data.chaoxingStore.list(), hasLength(2));
  harness.http.routes.clear();
  configureSingleCourse(harness.http);
  await tester.tap(find.byKey(const Key('assignments-login')));
  await tester.pumpAndSettle();
  expect(find.textContaining('学习通已连接'), findsOneWidget);

  await data.workspace.sources.recordFailure(
    SourceKind.chaoxing,
    'assignments',
    scopeKey: platform.id,
    attemptedAt: DateTime.utc(2026, 11, 3, 3),
    code: SourceErrorCodes.sourceUnavailable,
    message: '合成断网',
  );
  // Re-enter the page to verify persisted source failures, not only the current report.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: AssignmentsPage(
          workspace: data.workspace,
          store: data.chaoxingStore,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.textContaining('本次刷新失败，保留上次数据：合成断网'), findsWidgets);
  await tester.tap(find.byKey(const Key('assignments-manage-courses')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('course-binding-${platform.id}')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('course-unbind')));
  await tester.pumpAndSettle();
  expect(await bindings.list(), isEmpty);
  expect(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('未绑定教务课程'),
    ),
    findsOneWidget,
  );
  await tester.tap(find.widgetWithText(TextButton, '完成'));
  await tester.pumpAndSettle();

  final other = buildWorkbenchData(
    database: harness.database,
    userId: 'user-b',
    sessions: sourceSessions(connected: false),
    http: harness.http,
    campusLogin: FakeCampusLogin(connected: false),
    browser: harness.browser,
  );
  addTearDown(other.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: AssignmentsPage(
          key: const ValueKey('user-b'),
          workspace: other.workspace,
          store: other.chaoxingStore,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('assignments-empty-courses')), findsOneWidget);
  expect(find.text('示例作业一'), findsNothing);
  expect(await courses.list(source: SourceKind.jluIedu), hasLength(2));
  expect(await data.chaoxingStore.list(), hasLength(2));
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}
