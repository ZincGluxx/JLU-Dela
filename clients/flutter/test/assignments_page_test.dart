import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/local_workbench.dart';
import 'package:jlu_dela/app/theme.dart';
import 'package:jlu_dela/core/source/campus_login.dart';
import 'package:jlu_dela/core/storage/local_workspace.dart';
import 'package:jlu_dela/features/assignments/assignments_page.dart';
import 'package:jlu_dela/features/assignments/chaoxing_store.dart';

import 'support/chaoxing_test_support.dart';

class _PageFixture {
  _PageFixture(this.workspace, this.store);

  final LocalWorkspace workspace;
  final ChaoxingStore store;
}

Future<_PageFixture> _fixture(
  ChaoxingHarness harness, {
  CampusLogin? login,
}) async {
  final data = buildWorkbenchData(
    database: harness.database,
    userId: 'user-a',
    sessions: harness.sessions,
    http: harness.http,
    campusLogin: login ?? FakeCampusLogin(),
    browser: harness.browser,
    now: () => DateTime.utc(2026, 11, 3, 2),
  );
  addTearDown(data.dispose);
  final store = ChaoxingStore(
    harness.database,
    'user-a',
    data.workspace.sources,
    data.workspace.courses,
    source: data.workspace.source,
    now: () => DateTime.utc(2026, 11, 3, 2),
  );
  return _PageFixture(data.workspace, store);
}

Future<void> _pump(
  WidgetTester tester,
  _PageFixture fixture, {
  Size size = const Size(1280, 900),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: AssignmentsPage(
          workspace: fixture.workspace,
          store: fixture.store,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  testWidgets('shows the disconnected source without fabricating data', (
    tester,
  ) async {
    final harness = await ChaoxingHarness.create(connected: false);
    final fixture = await _fixture(
      harness,
      login: FakeCampusLogin(connected: false, message: '设备端校园登录尚未接入'),
    );
    await _pump(tester, fixture);

    expect(find.byKey(const Key('assignments-empty-courses')), findsOneWidget);
    expect(find.textContaining('学习通未连接'), findsOneWidget);
    final refresh = tester.widget<OutlinedButton>(
      find.byKey(const Key('assignments-refresh')),
    );
    expect(refresh.onPressed, isNull);

    await tester.tap(find.byKey(const Key('assignments-login')));
    await tester.pumpAndSettle();
    expect(find.textContaining('设备端校园登录尚未接入'), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('refreshes, groups and marks assignments from the source', (
    tester,
  ) async {
    final harness = await ChaoxingHarness.create(
      now: () => DateTime.utc(2026, 11, 3, 2),
    );
    configureSingleCourse(harness.http);
    final fixture = await _fixture(harness);
    await _pump(tester, fixture);

    await tester.tap(find.byKey(const Key('assignments-refresh')));
    await tester.pumpAndSettle();

    final assignments = await fixture.store.list();
    expect(assignments, hasLength(2));
    expect(find.text('示例作业一'), findsOneWidget);
    expect(find.text('示例作业二'), findsNothing);
    expect(find.byKey(const Key('assignment-section-soon')), findsOneWidget);
    expect(find.textContaining('示例课程甲'), findsWidgets);

    final work = assignments.firstWhere((item) => item.title == '示例作业一');
    await tester.tap(find.byKey(Key('assignment-read-${work.id}')));
    await tester.pumpAndSettle();
    final marked = (await fixture.store.byId(work.id))!;
    expect(marked.readAtUtc, isNotNull);
    expect(find.text('已读'), findsWidgets);

    await tester.tap(find.byKey(Key('assignment-open-${work.id}')));
    await tester.pumpAndSettle();
    expect(harness.browser.opened, hasLength(1));
    expect(harness.browser.opened.single.queryParameters['workId'], 'work-1');

    await tester.tap(find.byKey(const Key('assignments-filter-all')));
    await tester.pumpAndSettle();
    expect(find.text('示例作业二'), findsOneWidget);

    await tester.tap(find.byKey(const Key('assignments-filter-ignored')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assignments-empty-filter')), findsOneWidget);
    await _dispose(tester);
  });

  testWidgets('fallback dialog keeps the validated source address visible', (
    tester,
  ) async {
    final harness = await ChaoxingHarness.create(
      browser: FakeSourcePageOpener(available: false),
    );
    configureSingleCourse(harness.http);
    final fixture = await _fixture(harness);
    await _pump(tester, fixture);
    await tester.tap(find.byKey(const Key('assignments-refresh')));
    await tester.pumpAndSettle();

    final work = (await fixture.store.list()).firstWhere(
      (item) => item.title == '示例作业一',
    );
    await tester.tap(find.byKey(Key('assignment-open-${work.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assignment-source-url')), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    await _dispose(tester);
  });

  testWidgets('manages course retention and remarks', (tester) async {
    final harness = await ChaoxingHarness.create();
    configureSingleCourse(harness.http);
    final fixture = await _fixture(harness);
    await _pump(tester, fixture);
    await tester.tap(find.byKey(const Key('assignments-refresh')));
    await tester.pumpAndSettle();

    final offering = (await fixture.store.listCourses()).single;
    await tester.tap(find.byKey(const Key('assignments-manage-courses')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('course-row-${offering.id}')), findsOneWidget);

    await tester.tap(find.byKey(Key('course-retained-${offering.id}')));
    await tester.pumpAndSettle();
    expect((await fixture.store.listCourses()).single.retained, isFalse);

    await tester.tap(find.byKey(Key('course-remark-${offering.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('course-remark-field')), '安卓课');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect((await fixture.store.listCourses()).single.remark, '安卓课');
    await tester.tap(find.widgetWithText(TextButton, '完成'));
    await tester.pumpAndSettle();
    expect(find.text('安卓课'), findsWidgets);
    await _dispose(tester);
  });

  testWidgets('keeps the board usable on a narrow screen', (tester) async {
    final harness = await ChaoxingHarness.create();
    configureSingleCourse(harness.http);
    final fixture = await _fixture(harness);
    await _pump(tester, fixture, size: const Size(390, 844));
    await tester.tap(find.byKey(const Key('assignments-refresh')));
    await tester.pumpAndSettle();

    expect(find.text('示例作业一'), findsOneWidget);
    expect(find.byKey(const Key('assignments-manage-courses')), findsOneWidget);
    await tester.tap(find.byKey(const Key('assignments-manage-courses')));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '完成'));
    await tester.pumpAndSettle();
    await _dispose(tester);
  });
}
