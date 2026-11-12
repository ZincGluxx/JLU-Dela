import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlu_dela/app/theme.dart';
import 'package:jlu_dela/core/api/diagnostics_service.dart';
import 'package:jlu_dela/core/auth/session_controller.dart';
import 'package:jlu_dela/core/auth/session_models.dart';
import 'package:jlu_dela/features/settings/settings_page.dart';

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

  Future<void> pumpSettings(
    WidgetTester tester,
    SessionController session,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SettingsPage(
            diagnosticsService: fakeDiagnostics(),
            session: session,
            glassEnabled: true,
            onGlassEnabledChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the current user and signs out locally', (tester) async {
    final store = MemoryRefreshTokenStore();
    final gateway = FakeAuthGateway(
      onFetchMe: (_) async => testUser(),
      onRevoke: (_, _) async {},
    );
    final session = SessionController(
      gateway: gateway,
      refreshTokenStore: store,
    );
    addTearDown(session.dispose);
    await session.signIn(testCredentials());

    await pumpSettings(tester, session);

    expect(find.text('已登录'), findsOneWidget);
    expect(find.text('当前用户：测试用户'), findsOneWidget);
    expect(find.byKey(const Key('session-sign-out')), findsOneWidget);

    await tester.tap(find.byKey(const Key('session-sign-out')));
    await tester.pumpAndSettle();

    expect(session.phase, SessionPhase.signedOut);
    expect(store.token, isNull);
    expect(find.text('未登录'), findsOneWidget);
    expect(find.byKey(const Key('session-sign-out-notice')), findsNothing);
  });

  testWidgets('reports an unconfirmed remote sign-out', (tester) async {
    final store = MemoryRefreshTokenStore();
    final gateway = FakeAuthGateway(
      onFetchMe: (_) async => testUser(),
      onRevoke: (_, _) async => throw http.ClientException('offline'),
    );
    final session = SessionController(
      gateway: gateway,
      refreshTokenStore: store,
    );
    addTearDown(session.dispose);
    await session.signIn(testCredentials());

    await pumpSettings(tester, session);
    await tester.tap(find.byKey(const Key('session-sign-out')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('session-sign-out-notice')), findsOneWidget);
    expect(
      find.text(SessionController.remoteSignOutUnconfirmedMessage),
      findsOneWidget,
    );
    expect(session.phase, SessionPhase.signedOut);
    expect(store.token, isNull);
  });

  testWidgets('offers retry and local session clearing when unavailable', (
    tester,
  ) async {
    final store = MemoryRefreshTokenStore();
    final gateway = FakeAuthGateway(
      onFetchMe: (_) async => testUser(),
      onRefresh: (_) async => throw http.ClientException('offline'),
      onRevoke: (_, _) async {},
    );
    final session = SessionController(
      gateway: gateway,
      refreshTokenStore: store,
    );
    addTearDown(session.dispose);
    await session.signIn(testCredentials());
    await session.refreshSession();

    await pumpSettings(tester, session);

    expect(find.text('会话状态暂不可用'), findsOneWidget);
    expect(find.text('当前用户：测试用户'), findsOneWidget);
    expect(find.byKey(const Key('session-retry')), findsOneWidget);
    expect(find.byKey(const Key('session-clear-local')), findsOneWidget);

    await tester.tap(find.byKey(const Key('session-clear-local')));
    await tester.pumpAndSettle();

    expect(session.phase, SessionPhase.signedOut);
    expect(store.token, isNull);
    expect(find.text('未登录'), findsOneWidget);
  });

  testWidgets('retries the session restore from the settings card', (
    tester,
  ) async {
    final store = MemoryRefreshTokenStore('refresh-a');
    final gateway = FakeAuthGateway(
      onRefresh: (_) async => throw http.ClientException('offline'),
    );
    final session = SessionController(
      gateway: gateway,
      refreshTokenStore: store,
    );
    addTearDown(session.dispose);
    await session.restore();

    await pumpSettings(tester, session);

    expect(find.text('会话状态暂不可用'), findsOneWidget);
    expect(find.byKey(const Key('session-user')), findsNothing);

    gateway.onRefresh = (_) async =>
        testTokenPair(accessToken: 'access-b', refreshToken: 'refresh-b');
    gateway.onFetchMe = (_) async => testUser();

    await tester.tap(find.byKey(const Key('session-retry')));
    await tester.pumpAndSettle();

    expect(session.phase, SessionPhase.authenticated);
    expect(find.text('已登录'), findsOneWidget);
    expect(find.text('当前用户：测试用户'), findsOneWidget);
  });
}
