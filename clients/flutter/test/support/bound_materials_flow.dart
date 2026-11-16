import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlu_dela/app/app.dart';
import 'package:jlu_dela/app/local_workbench.dart';
import 'package:jlu_dela/core/api/diagnostics_service.dart';
import 'package:jlu_dela/core/auth/session_controller.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/source_page_opener_impl.dart';
import 'package:jlu_dela/core/source/source.dart';
import 'package:jlu_dela/core/source/source_session.dart';
import 'package:jlu_dela/core/storage/course_store.dart';
import 'package:jlu_dela/core/storage/local_identity_store.dart';
import 'package:jlu_dela/features/assignments/course_binding_store.dart';

import '../source_fakes.dart';
import '../teaching_test_support.dart' as teaching;
import 'chaoxing_test_support.dart';
import 'session_test_support.dart';

Future<void> exerciseBoundMaterialsFlow(
  WidgetTester tester, {
  String privacy = '',
  String accountChange = 'switch',
  String bindingCase = 'bound',
  bool fromTeaching = false,
  Future<void> Function(String name)? onCapture,
}) async {
  final harness = await ChaoxingHarness.create();
  final session = SessionController(
    gateway: FakeAuthGateway(
      onFetchMe: (token) async =>
          testUser(id: token == 'access-b' ? 'user-b' : 'user-a'),
      onRevoke: (_, _) async {},
    ),
    refreshTokenStore: MemoryRefreshTokenStore(),
  );
  addTearDown(session.dispose);
  await session.signIn(testCredentials());
  final webView = FakeSourceWebView();
  final works = <WorkbenchData>[];
  final login = RecordingCampusLogin(sessions: harness.sessions);
  final delayedHttp = _DelayedMaterialHttp(harness.http);
  WorkbenchData build(String userId) {
    final data = buildWorkbenchData(
      database: harness.database,
      userId: userId,
      sessions: harness.sessions,
      http: delayedHttp,
      campusLogin: login,
      browser: InAppWebViewSourcePageOpener(
        sessions: harness.sessions,
        webView: webView,
      ),
      now: () => DateTime.utc(2026, 9, 16, 12),
    );
    works.add(data);
    return data;
  }

  configureSingleCourse(harness.http);
  harness.http.on(materialsFrameUrl, materialListPage());
  harness.http.onWhere(
    (uri) => uri.queryParameters['dataId'] == 'folder-1',
    materialFolderPage(),
  );
  final a = build('user-a');
  expect((await a.chaoxingStore.refreshAll()).isSuccess, isTrue);
  final platform = (await a.chaoxingStore.listCourses()).single;
  final target = fromTeaching
      ? await (() async {
          await a.teachingStore.syncCurrentSemester(
            http: teaching.teachingHttp(),
          );
          await a.teachingStore.refreshSemester(
            semesterCode: '2026-2027-1',
            http: teaching.teachingHttp(
              courses: [teaching.teachingCourse(name: '教务对应课')],
            ),
          );
          return (await a.workspace.courses.list(
            source: SourceKind.jluIedu,
          )).single;
        })()
      : await a.workspace.courses.upsert(
          const SourceCourse(
            source: SourceKind.jluIedu,
            sourceScope: '2026-2027-1',
            sourceId: 'target-1',
            semesterId: 'semester-a',
            name: '教务对应课',
            teacher: '教务教师',
          ),
        );
  final otherTerm = await a.workspace.courses.upsert(
    const SourceCourse(
      source: SourceKind.jluIedu,
      sourceScope: '2025-2026-1',
      sourceId: 'target-1',
      semesterId: 'semester-old',
      name: '教务对应课',
    ),
  );
  final bindings = CourseBindingStore(
    harness.database,
    'user-a',
    a.workspace.courses,
  );
  await bindings.bind(
    platformCourseId: platform.id,
    teachingCourseId: target.id,
  );
  final second = await a.workspace.courses.upsert(
    const SourceCourse(
      source: SourceKind.chaoxing,
      sourceScope: 'default',
      sourceId: '101:200',
      name: '第二平台课',
    ),
  );
  await a.workspace.courses.upsert(
    const SourceCourse(
      source: SourceKind.chaoxing,
      sourceScope: 'default',
      sourceId: '102:200',
      name: '同名但未绑定平台课',
    ),
  );
  await bindings.bind(platformCourseId: second.id, teachingCourseId: target.id);
  expect(
    (await bindings.list()).where((binding) => binding.matchesTeaching(target)),
    hasLength(2),
  );
  expect(
    (await bindings.list()).any(
      (binding) => binding.matchesTeaching(otherTerm),
    ),
    isFalse,
  );
  if (bindingCase == 'unbound' || bindingCase == 'none') {
    await bindings.unbind(platform.sourceRef);
  }
  if (bindingCase == 'none') await bindings.unbind(second.sourceRef);
  if (bindingCase == 'missing') {
    await harness.database.database.delete(
      'course_offerings',
      where: 'id = ? AND user_id = ?',
      whereArgs: [target.id, 'user-a'],
    );
  }
  var initialWorkbench = true;
  await tester.pumpWidget(
    JluDelaApp(
      diagnosticsService: DiagnosticsService(
        apiBaseUri: Uri.parse('http://127.0.0.1:8080'),
        httpClient: MockClient((_) async => http.Response('', 404)),
        clientVersionLoader: () async => 'fixture',
      ),
      session: session,
      accountGateway: FakeAccountGateway(),
      identityStore: LocalIdentityStore(harness.database),
      workbenchBuilder: (userId) {
        if (initialWorkbench) {
          initialWorkbench = false;
          return a;
        }
        return build(userId);
      },
    ),
  );
  await tester.pumpAndSettle();
  if (fromTeaching) {
    await tester.tap(find.byKey(const Key('destination-teaching')));
    await tester.pumpAndSettle();
    final lesson = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key as ValueKey<String>).value.startsWith('teaching-lesson-'),
    );
    await tester.tap(lesson.first);
    await tester.pumpAndSettle();
    await onCapture?.call('teaching-entry');
    await tester.tap(find.byKey(const Key('teaching-course-materials')));
    await tester.pumpAndSettle();
  } else {
    await tester.tap(find.byKey(const Key('destination-assignments')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assignments-manage-courses')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('course-materials-${platform.id}')));
    await tester.pumpAndSettle();
  }
  if (fromTeaching && bindingCase == 'none') {
    expect(find.textContaining('该教务课程暂无可用的学习通绑定'), findsOneWidget);
    expect(find.text('讲义.pdf'), findsNothing);
    await tester.tap(find.byKey(const Key('destination-assignments')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('destination-materials')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('materials-course')), findsOneWidget);
    await tester.tap(find.byKey(const Key('materials-course')));
    await tester.pumpAndSettle();
    expect(find.text('同名但未绑定平台课'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    return;
  }
  if (fromTeaching && bindingCase == 'unbound') {
    // A second platform remains bound; only that course is available.
    expect(find.textContaining('第二平台课'), findsWidgets);
    expect(find.textContaining('来源 ID：100:200'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    return;
  }
  expect(find.byKey(const Key('materials-course-binding')), findsOneWidget);
  expect(
    find.textContaining(
      bindingCase == 'missing'
          ? '绑定的教务课程不在当前缓存'
          : bindingCase == 'unbound'
          ? '未绑定教务课程'
          : '教务：教务对应课 · 2026-2027-1',
    ),
    findsOneWidget,
  );
  expect(find.textContaining('2025-2026-1'), findsNothing);
  await tester.tap(find.byKey(const Key('materials-refresh')));
  await tester.pumpAndSettle();
  expect(find.text('讲义.pdf'), findsOneWidget);
  expect(find.textContaining('不代表完整目录'), findsOneWidget);
  final snapshot = await a.contentStore.materialSnapshot(platform.id);
  await onCapture?.call('materials-root');
  if (bindingCase == 'bound' && privacy.isEmpty) {
    await tester.tap(find.byKey(const Key('materials-course')));
    await tester.pumpAndSettle();
    if (fromTeaching) expect(find.text('同名但未绑定平台课'), findsNothing);
    await tester.tap(find.text('第二平台课').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('教务：教务对应课 · 2026-2027-1'), findsOneWidget);
    expect(find.text('讲义.pdf'), findsNothing);
    await tester.tap(find.byKey(const Key('materials-course')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('示例课程甲').last);
    await tester.pumpAndSettle();
    expect(find.text('讲义.pdf'), findsOneWidget);
  }
  if (privacy == 'dropdown') {
    await tester.tap(find.byKey(const Key('materials-course')));
    await tester.pumpAndSettle();
  } else {
    await tester.tap(find.byKey(const Key('material-folder-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('materials-refresh')));
    await tester.pumpAndSettle();
    expect(find.text('目录内文件.pdf'), findsOneWidget);
    await onCapture?.call('materials-nested');
    await tester.tap(find.byKey(const Key('materials-back')));
    await tester.pumpAndSettle();
    expect(find.text('讲义.pdf'), findsOneWidget);
    if (privacy.isEmpty) {
      final lastSuccess = (await a.contentStore.materialSnapshot(
        platform.id,
      )).lastSuccessAtUtc;
      delayedHttp.error = http.ClientException('fixture offline');
      await tester.tap(find.byKey(const Key('material-access-file-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('materials-error')), findsOneWidget);
      expect(find.byKey(const Key('content-access-open')), findsNothing);
      expect(
        (await a.contentStore.materialSnapshot(platform.id)).lastSuccessAtUtc,
        lastSuccess,
      );
      delayedHttp.error = const SourceException(
        SourceFailure(
          code: SourceErrorCodes.sourceAuthRequired,
          message: 'source expired',
          source: SourceKind.chaoxing,
        ),
      );
      await tester.tap(find.byKey(const Key('material-access-file-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('materials-connect')), findsOneWidget);
      delayedHttp.error = null;
      await tester.tap(find.byKey(const Key('materials-connect')));
      await tester.pumpAndSettle();
    }
    if (privacy == 'inflight') delayedHttp.gate = Completer<void>();
    await tester.tap(find.byKey(const Key('material-access-file-1')));
    if (privacy == 'inflight') {
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('content-access-open')), findsOneWidget);
    }
    if (privacy != 'access' && privacy != 'inflight') {
      await tester.tap(find.byKey(const Key('content-access-open')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('source-page-dialog')), findsOneWidget);
      expect(webView.controller.loadedUri!.host, 'download.chaoxing.com');
    }
  }
  if (privacy.isNotEmpty) {
    if (accountChange == 'signout') {
      await session.signOut();
    } else if (accountChange == 'relogin') {
      await session.signOut();
      await session.signIn(testCredentials());
    } else {
      await session.signIn(
        testCredentials(accessToken: 'access-b', refreshToken: 'refresh-b'),
      );
    }
    await tester.pumpAndSettle();
    if (privacy == 'inflight') {
      delayedHttp.gate!.complete();
      await tester.pumpAndSettle();
    }
    for (final text in [
      '讲义.pdf',
      '目录内文件.pdf',
      '教务对应课',
      'download.chaoxing.com',
    ]) {
      final matches = find.textContaining(text, skipOffstage: false);
      expect(
        accountChange == 'relogin'
            ? find.descendant(
                of: find.byType(AlertDialog, skipOffstage: false),
                matching: matches,
                skipOffstage: false,
              )
            : matches,
        findsNothing,
      );
    }
    expect(
      find.byKey(const Key('source-page-dialog'), skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byKey(const Key('content-access-open'), skipOffstage: false),
      findsNothing,
    );
    if (accountChange == 'switch') {
      expect(works.last.workspace.userId, 'user-b');
      expect(await works.last.contentStore.loadMaterials(platform.id), isEmpty);
    }
  } else {
    await tester.tap(find.byKey(const Key('source-page-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('content-access-close')));
    await tester.pumpAndSettle();

    harness.http.routes.clear();
    harness.http.on(baseUrl, '', statusCode: 503);
    await tester.tap(find.byKey(const Key('materials-refresh')));
    await tester.pumpAndSettle();
    expect(find.text('讲义.pdf'), findsOneWidget);
    expect(
      (await a.contentStore.materialSnapshot(platform.id)).lastSuccessAtUtc,
      snapshot.lastSuccessAtUtc,
    );
    expect(find.byKey(const Key('materials-connect')), findsNothing);
    harness.http.routes.clear();
    harness.http.on(baseUrl, loginPage());
    await tester.tap(find.byKey(const Key('materials-refresh')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('materials-connect')), findsOneWidget);
    harness.http.routes.clear();
    configureSingleCourse(harness.http);
    harness.http.on(materialsFrameUrl, materialListPage());
    await tester.tap(find.byKey(const Key('materials-connect')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('materials-refresh')));
    await tester.pumpAndSettle();
    expect(find.text('讲义.pdf'), findsOneWidget);
    expect(find.byKey(const Key('materials-connect')), findsNothing);
  }
  await tester.pumpWidget(const SizedBox());
}

class _DelayedMaterialHttp implements SourceHttpClient {
  _DelayedMaterialHttp(this.inner);
  final SourceHttpClient inner;
  Completer<void>? gate;
  Exception? error;

  @override
  Future<SourceResponse> send(SourceRequest request) async {
    final failure = error;
    if (failure != null) throw failure;
    final pending = gate;
    if (pending != null) {
      await pending.future;
      gate = null;
    }
    return inner.send(request);
  }
}
