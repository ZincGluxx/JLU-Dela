import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlu_dela/core/api/diagnostics_service.dart';
import 'package:jlu_dela/core/auth/session_controller.dart';
import 'package:jlu_dela/core/auth/session_models.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/source_session.dart';
import 'package:jlu_dela/core/storage/local_identity_store.dart';
import 'package:jlu_dela_api/api.dart';

import 'support/local_app_test_support.dart';
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

  Future<LocalAppHarness> pumpApp(
    WidgetTester tester,
    SessionController session, {
    CachedIdentity? cachedIdentity,
  }) async {
    final harness = await LocalAppHarness.create();
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      harness.buildApp(
        diagnosticsService: fakeDiagnostics(),
        session: session,
        accountGateway: FakeAccountGateway(),
        cachedIdentity: cachedIdentity,
      ),
    );
    await tester.pumpAndSettle();
    return harness;
  }

  testWidgets('an unavailable session keeps local pages and offers retry', (
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
    expect(session.currentUser, isNotNull);

    final harness = await pumpApp(tester, session);

    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    expect(find.text('离线 · 身份未验证'), findsOneWidget);
    expect(find.text('功能迁移中，尚未接入本地课表与作业数据'), findsOneWidget);
    expect(harness.builtUserIds, ['user-a']);
    expect(find.byKey(const Key('login-page')), findsNothing);

    gateway.onRefresh = (_) async => testTokenPair();
    gateway.onFetchMe = (_) async => testUser();
    await tester.tap(find.byKey(const Key('offline-reverify')));
    await tester.pumpAndSettle();

    expect(session.phase, SessionPhase.authenticated);
    expect(find.byKey(const Key('offline-banner')), findsNothing);
    expect(harness.builtUserIds, ['user-a']);
    expect(harness.workbenches.single.disposeCount, 0);
  });

  testWidgets('a cached identity opens local data offline without a token', (
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
    expect(session.phase, SessionPhase.unavailable);
    expect(session.currentUser, isNull);
    expect(session.accessToken, isNull);

    final harness = await pumpApp(
      tester,
      session,
      cachedIdentity: CachedIdentity(
        userId: 'cached-user',
        displayName: '缓存用户',
        timezone: 'Asia/Shanghai',
        verifiedAtUtc: DateTime.utc(2026, 11, 10),
        lastUsedAtUtc: DateTime.utc(2026, 11, 10),
      ),
    );

    expect(find.byKey(const Key('offline-banner')), findsOneWidget);
    expect(find.byKey(const Key('login-page')), findsNothing);
    expect(harness.builtUserIds, ['cached-user']);
    expect(session.accessToken, isNull);

    final workspace = harness.workbenches.single.workspace;
    final todo = await workspace.todos.create(title: '离线待办');
    expect((await workspace.todos.list()).single.id, todo.id);
  });

  testWidgets('signed out never shows local business data', (tester) async {
    final session = SessionController(
      gateway: FakeAuthGateway(),
      refreshTokenStore: MemoryRefreshTokenStore(),
    );
    addTearDown(session.dispose);
    await session.restore();
    expect(session.phase, SessionPhase.signedOut);

    final harness = await pumpApp(
      tester,
      session,
      cachedIdentity: CachedIdentity(
        userId: 'cached-user',
        displayName: '缓存用户',
        timezone: 'Asia/Shanghai',
        verifiedAtUtc: DateTime.utc(2026, 11, 10),
        lastUsedAtUtc: DateTime.utc(2026, 11, 10),
      ),
    );

    expect(find.byKey(const Key('login-page')), findsOneWidget);
    expect(find.byKey(const Key('offline-banner')), findsNothing);
    expect(harness.builtUserIds, isEmpty);
    expect(find.text('功能迁移中，尚未接入本地课表与作业数据'), findsNothing);
  });

  testWidgets('changing the verified identity replaces the workspace', (
    tester,
  ) async {
    final gateway = FakeAuthGateway(onFetchMe: (_) async => testUser());
    final session = SessionController(
      gateway: gateway,
      refreshTokenStore: MemoryRefreshTokenStore(),
    );
    addTearDown(session.dispose);
    await session.signIn(testCredentials());

    final harness = await pumpApp(tester, session);
    expect(harness.builtUserIds, ['user-a']);

    harness.sessions.save(SourceAuthGroup.chaoxing, {'cookie': 'memory-only'});
    gateway.onFetchMe = (_) async => testUser(id: 'user-b', displayName: '用户乙');
    await session.signIn(testCredentials());
    await tester.pumpAndSettle();

    expect(harness.builtUserIds, ['user-a', 'user-b']);
    expect(harness.workbenches.first.disposeCount, 1);
    expect(harness.workbenches.last.workspace.userId, 'user-b');
    expect(harness.sessions.hasSession(SourceKind.chaoxing), isFalse);
  });

  testWidgets('a rejected re-verification returns to login and keeps data', (
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

    final harness = await pumpApp(tester, session);
    await harness.workbenches.single.workspace.todos.create(title: '保留的数据');

    gateway.onRefresh = (_) async => throw ApiException(401, null);
    await tester.tap(find.byKey(const Key('offline-reverify')));
    await tester.pumpAndSettle();

    expect(session.phase, SessionPhase.signedOut);
    expect(find.byKey(const Key('login-page')), findsOneWidget);
    expect(find.byKey(const Key('offline-banner')), findsNothing);
    final rows = await harness.database.database.query('todos');
    expect(rows, hasLength(1));
    expect(rows.single['title'], '保留的数据');
  });

  testWidgets('without a cached identity an unavailable session shows a gate', (
    tester,
  ) async {
    final session = SessionController(
      gateway: FakeAuthGateway(
        onRefresh: (_) async => throw http.ClientException('offline'),
      ),
      refreshTokenStore: MemoryRefreshTokenStore('refresh-a'),
    );
    addTearDown(session.dispose);
    await session.restore();

    final harness = await pumpApp(tester, session);

    expect(find.byKey(const Key('session-gate-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('offline-banner')), findsNothing);
    expect(harness.builtUserIds, isEmpty);
  });
}
