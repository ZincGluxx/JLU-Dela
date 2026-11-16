import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlu_dela/core/api/diagnostics_service.dart';
import 'package:jlu_dela/core/auth/session_controller.dart';
import 'package:jlu_dela/core/auth/session_models.dart';
import 'package:jlu_dela/core/models/course.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/storage/course_store.dart';
import 'package:jlu_dela/features/assignments/course_binding_store.dart';

import 'support/local_app_test_support.dart';
import 'support/session_test_support.dart';

void main() {
  late LocalAppHarness harness;
  late SessionController session;
  late FakeAuthGateway gateway;
  late CourseOffering platform;
  late CourseOffering teaching;

  Future<void> openDialog(WidgetTester tester, String dialog) async {
    harness = await LocalAppHarness.create();
    gateway = FakeAuthGateway(
      onFetchMe: (token) async =>
          testUser(id: token == 'access-b' ? 'user-b' : 'user-a'),
      onRevoke: (_, _) async {},
      onRefresh: (_) async => throw http.ClientException('fixture offline'),
    );
    session = SessionController(
      gateway: gateway,
      refreshTokenStore: MemoryRefreshTokenStore(),
    );
    addTearDown(session.dispose);
    await session.signIn(testCredentials());
    final courses = CourseStore(harness.database, 'user-a');
    platform = await courses.upsert(
      const SourceCourse(
        source: SourceKind.chaoxing,
        sourceScope: 'default',
        sourceId: 'private-platform-id',
        name: '账号A私人平台课',
        teacher: '账号A私人平台教师',
      ),
    );
    await courses.updatePreferences(platform.id, remark: '账号A私人备注');
    teaching = await courses.upsert(
      const SourceCourse(
        source: SourceKind.jluIedu,
        sourceScope: '2026-2027-1',
        sourceId: 'private-teaching-id',
        semesterId: 'teaching:user-a:2026-2027-1',
        name: '账号A私人教务课',
        teacher: '账号A私人教务教师',
      ),
    );
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      harness.buildApp(
        diagnosticsService: DiagnosticsService(
          apiBaseUri: Uri.parse('http://127.0.0.1:8080'),
          httpClient: MockClient((_) async => http.Response('', 404)),
          clientVersionLoader: () async => 'fixture',
        ),
        session: session,
        accountGateway: FakeAccountGateway(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('destination-assignments')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assignments-manage-courses')));
    await tester.pumpAndSettle();
    expect(find.text('账号A私人备注'), findsOneWidget);
    if (dialog == 'binding') {
      await tester.tap(find.byKey(Key('course-binding-${platform.id}')));
      await tester.pumpAndSettle();
      expect(find.text('账号A私人教务课'), findsOneWidget);
    } else if (dialog == 'remark') {
      await tester.tap(find.byKey(Key('course-remark-${platform.id}')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('course-remark-field')),
        '账号A未保存备注',
      );
    }
  }

  void expectNoPrivateContent({bool dialogsOnly = false}) {
    for (final text in [
      '账号A',
      'private-platform-id',
      'private-teaching-id',
      '2026-2027-1',
    ]) {
      final matches = find.textContaining(text, skipOffstage: false);
      expect(
        dialogsOnly
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
      find.byKey(Key('binding-target-${teaching.id}'), skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byKey(Key('course-binding-${platform.id}'), skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byKey(Key('course-retained-${platform.id}'), skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byKey(const Key('course-remark-field'), skipOffstage: false),
      findsNothing,
    );
  }

  for (final dialog in ['courses', 'binding', 'remark']) {
    testWidgets('signout clears $dialog and every underlying course dialog', (
      tester,
    ) async {
      await openDialog(tester, dialog);
      await session.signOut();
      await tester.pumpAndSettle();
      expectNoPrivateContent();
      for (var level = 0; level < (dialog == 'courses' ? 1 : 2); level++) {
        await tester.tap(find.widgetWithText(TextButton, '关闭').last);
        await tester.pumpAndSettle();
        expectNoPrivateContent();
      }
      expect(find.byKey(const Key('login-page')), findsOneWidget);
      final courses = CourseStore(harness.database, 'user-a');
      expect((await courses.byId(platform.id))!.remark, '账号A私人备注');
      expect(
        await CourseBindingStore(harness.database, 'user-a', courses).list(),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final change in ['invalidate', 'switch-account', 'signout-signin']) {
    testWidgets('$change invalidates the open binding stack', (tester) async {
      await openDialog(tester, 'binding');
      if (change == 'invalidate') {
        await session.invalidateSession();
      } else if (change == 'switch-account') {
        await session.signIn(
          testCredentials(accessToken: 'access-b', refreshToken: 'refresh-b'),
        );
      } else {
        await session.signOut();
        await session.signIn(testCredentials());
      }
      await tester.pumpAndSettle();
      expectNoPrivateContent(dialogsOnly: change == 'signout-signin');
      await tester.tap(find.widgetWithText(TextButton, '关闭').last);
      await tester.pumpAndSettle();
      expectNoPrivateContent(dialogsOnly: change == 'signout-signin');
      await tester.tap(find.widgetWithText(TextButton, '关闭').last);
      await tester.pumpAndSettle();
      if (change == 'switch-account') {
        expectNoPrivateContent();
        expect(harness.builtUserIds, ['user-a', 'user-b']);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('same-account network failure keeps cached binding usable', (
    tester,
  ) async {
    await openDialog(tester, 'binding');
    await session.refreshSession();
    await tester.pumpAndSettle();
    expect(session.phase, SessionPhase.unavailable);
    expect(find.text('账号A私人教务课'), findsOneWidget);
    await tester.tap(find.byKey(Key('binding-target-${teaching.id}')));
    await tester.pumpAndSettle();
    final courses = CourseStore(harness.database, 'user-a');
    expect(
      (await CourseBindingStore(
        harness.database,
        'user-a',
        courses,
      ).list()).single.matchesTeaching(teaching),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
