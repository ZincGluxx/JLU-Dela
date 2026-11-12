import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlu_dela/app/app.dart';
import 'package:jlu_dela/app/app_shell.dart';
import 'package:jlu_dela/core/api/diagnostics_service.dart';
import 'package:jlu_dela/core/auth/session_controller.dart';
import 'package:jlu_dela/core/auth/session_models.dart';

import 'support/session_test_support.dart';

void main() {
  DiagnosticsService fakeDiagnostics() {
    return DiagnosticsService(
      apiBaseUri: Uri.parse('http://127.0.0.1:8080'),
      httpClient: MockClient((request) async => http.Response('', 404)),
      clientVersionLoader: () async => '0.1.0',
      timeout: const Duration(seconds: 1),
    );
  }

  Future<void> pumpApp(
    WidgetTester tester,
    SessionController session, {
    Map<AppDestination, AppPageBuilder> pages = const {},
  }) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      JluDelaApp(
        diagnosticsService: fakeDiagnostics(),
        session: session,
        pages: pages,
      ),
    );
    await tester.pump();
  }

  testWidgets('blocks business pages while the session is restoring', (
    tester,
  ) async {
    final session = SessionController(
      gateway: FakeAuthGateway(),
      refreshTokenStore: MemoryRefreshTokenStore(),
    );
    addTearDown(session.dispose);

    await pumpApp(
      tester,
      session,
      pages: {
        AppDestination.calendar: (context) =>
            const Center(child: Text('业务模块日历页')),
      },
    );

    expect(find.byKey(const Key('session-gate-restoring')), findsOneWidget);
    expect(find.text('正在恢复会话…'), findsOneWidget);
    expect(find.text('业务模块日历页'), findsNothing);
  });

  testWidgets('shows the login placeholder while signed out', (tester) async {
    final session = SessionController(
      gateway: FakeAuthGateway(),
      refreshTokenStore: MemoryRefreshTokenStore(),
    );
    addTearDown(session.dispose);
    await session.restore();

    await pumpApp(
      tester,
      session,
      pages: {
        AppDestination.calendar: (context) =>
            const Center(child: Text('业务模块日历页')),
      },
    );

    expect(find.byKey(const Key('session-gate-signed-out')), findsOneWidget);
    expect(find.text('工作台登录尚未开放'), findsOneWidget);
    expect(find.text('业务模块日历页'), findsNothing);

    await tester.tap(find.byKey(const Key('destination-settings')));
    await tester.pumpAndSettle();

    expect(find.text('启动诊断'), findsOneWidget);
  });

  testWidgets('offers a retry when the session cannot be restored', (
    tester,
  ) async {
    final gateway = FakeAuthGateway(
      onRefresh: (_) async => throw http.ClientException('offline'),
    );
    final session = SessionController(
      gateway: gateway,
      refreshTokenStore: MemoryRefreshTokenStore('refresh-a'),
    );
    addTearDown(session.dispose);
    await session.restore();

    await pumpApp(
      tester,
      session,
      pages: {
        AppDestination.calendar: (context) =>
            const Center(child: Text('业务模块日历页')),
      },
    );

    expect(find.byKey(const Key('session-gate-unavailable')), findsOneWidget);
    expect(find.text('暂时无法恢复会话'), findsOneWidget);
    expect(find.text('业务模块日历页'), findsNothing);

    gateway.onRefresh = (_) async =>
        testTokenPair(accessToken: 'access-b', refreshToken: 'refresh-b');
    gateway.onFetchMe = (_) async => testUser();

    await tester.tap(find.byKey(const Key('session-gate-retry')));
    await tester.pumpAndSettle();

    expect(session.phase, SessionPhase.authenticated);
    expect(find.byKey(const Key('session-gate-unavailable')), findsNothing);
    expect(find.text('业务模块日历页'), findsOneWidget);
  });

  testWidgets('keeps business pages when an authenticated refresh fails', (
    tester,
  ) async {
    final gateway = FakeAuthGateway(
      onFetchMe: (_) async => testUser(),
      onRefresh: (_) async => throw http.ClientException('offline'),
    );
    final session = SessionController(
      gateway: gateway,
      refreshTokenStore: MemoryRefreshTokenStore(),
    );
    addTearDown(session.dispose);
    await session.signIn(testCredentials());
    await session.refreshSession();
    expect(session.phase, SessionPhase.unavailable);

    await pumpApp(
      tester,
      session,
      pages: {
        AppDestination.calendar: (context) =>
            const Center(child: Text('业务模块日历页')),
      },
    );

    expect(find.byKey(const Key('session-gate-unavailable')), findsNothing);
    expect(find.text('业务模块日历页'), findsOneWidget);

    await tester.tap(find.byKey(const Key('destination-settings')));
    await tester.pumpAndSettle();

    expect(find.text('会话状态暂不可用'), findsOneWidget);
    expect(find.text('当前用户：测试用户'), findsOneWidget);
    expect(find.byKey(const Key('session-retry')), findsOneWidget);
    expect(find.byKey(const Key('session-clear-local')), findsOneWidget);
  });
}
