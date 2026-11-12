import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/theme.dart';
import 'package:jlu_dela/core/api/api_failure.dart';
import 'package:jlu_dela/core/auth/session_controller.dart';
import 'package:jlu_dela/core/auth/session_models.dart';
import 'package:jlu_dela/features/auth/login_page.dart';

import 'support/session_test_support.dart';

void main() {
  SessionController buildSession({FakeAuthGateway? gateway}) {
    return SessionController(
      gateway: gateway ?? FakeAuthGateway(),
      refreshTokenStore: MemoryRefreshTokenStore(),
    );
  }

  Future<void> pumpLoginPage(
    WidgetTester tester,
    SessionController session,
    FakeAccountGateway accountGateway,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: LoginPage(session: session, accountGateway: accountGateway),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('validates the login form before calling the gateway', (
    tester,
  ) async {
    final session = buildSession();
    addTearDown(session.dispose);
    final accountGateway = FakeAccountGateway();
    await pumpLoginPage(tester, session, accountGateway);

    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();

    expect(find.text('请输入登录名'), findsOneWidget);
    expect(find.text('请输入密码'), findsOneWidget);
    expect(accountGateway.loginCount, 0);
  });

  testWidgets('keeps the login, clears the password and explains a wrong '
      'credential', (tester) async {
    final session = buildSession();
    addTearDown(session.dispose);
    final accountGateway = FakeAccountGateway(
      onLogin: (_, _) async => throw const ApiFailure(
        kind: ApiFailureKind.server,
        technicalMessage: 'invalid',
        code: 'INVALID_CREDENTIALS',
        statusCode: 401,
      ),
    );
    await pumpLoginPage(tester, session, accountGateway);

    await tester.enterText(find.byKey(const Key('login-field')), 'e2e.user');
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'Wrong-Password-2026',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('login-field')))
          .controller
          ?.text,
      'e2e.user',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('login-password-field')))
          .controller
          ?.text,
      isEmpty,
    );
    expect(find.text('账号或密码不正确。'), findsOneWidget);
    expect(find.textContaining('Wrong-Password-2026'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('login-submit')))
          .onPressed,
      isNotNull,
    );
    expect(session.phase, isNot(SessionPhase.authenticated));
  });

  testWidgets('shows the 429 wait seconds and disables retry until they pass', (
    tester,
  ) async {
    final session = buildSession();
    addTearDown(session.dispose);
    final accountGateway = FakeAccountGateway(
      onLogin: (_, _) async => throw const ApiFailure(
        kind: ApiFailureKind.server,
        technicalMessage: 'too many attempts',
        code: 'RATE_LIMITED',
        statusCode: 429,
        retryable: true,
        retryAfter: Duration(seconds: 3),
      ),
    );
    await pumpLoginPage(tester, session, accountGateway);

    await tester.enterText(find.byKey(const Key('login-field')), 'e2e.user');
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'E2e-Flow-Password-2026',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('3 秒后重试'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('login-submit')))
          .onPressed,
      isNull,
    );

    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('2 秒后重试'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('秒后重试'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('login-submit')))
          .onPressed,
      isNotNull,
    );
    expect(accountGateway.loginCount, 1);
  });

  testWidgets('explains a network failure and allows retrying', (tester) async {
    final session = buildSession();
    addTearDown(session.dispose);
    final accountGateway = FakeAccountGateway(
      onLogin: (_, _) async => throw const ApiFailure(
        kind: ApiFailureKind.network,
        technicalMessage: 'offline',
      ),
    );
    await pumpLoginPage(tester, session, accountGateway);

    await tester.enterText(find.byKey(const Key('login-field')), 'e2e.user');
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'E2e-Flow-Password-2026',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('无法连接服务，请检查网络后重试。'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('login-submit')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('signs in with the typed credentials on success', (tester) async {
    final session = buildSession(
      gateway: FakeAuthGateway(
        onFetchMe: (_) async => testUser(displayName: '闭环用户'),
      ),
    );
    addTearDown(session.dispose);
    final accountGateway = FakeAccountGateway(
      onLogin: (_, _) async => testCredentials(),
    );
    await pumpLoginPage(tester, session, accountGateway);

    await tester.enterText(find.byKey(const Key('login-field')), 'e2e.user');
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'E2e-Flow-Password-2026',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(session.phase, SessionPhase.authenticated);
    expect(session.currentUser?.displayName, '闭环用户');
    expect(accountGateway.lastLogin, 'e2e.user');
    expect(accountGateway.lastPassword, 'E2e-Flow-Password-2026');
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('login-password-field')))
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('offers the invitation activation entry', (tester) async {
    final session = buildSession();
    addTearDown(session.dispose);
    await pumpLoginPage(tester, session, FakeAccountGateway());

    await tester.tap(find.byKey(const Key('login-activate-entry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activate-page')), findsOneWidget);
    expect(find.text('激活工作台账号'), findsOneWidget);
  });

  testWidgets(
    'a disposed page cannot sign in after the login request returns',
    (tester) async {
      final loginStarted = Completer<void>();
      final releaseLogin = Completer<SessionCredentials>();
      final authGateway = FakeAuthGateway(
        onFetchMe: (_) async => testUser(displayName: '迟到的登录'),
      );
      final session = SessionController(
        gateway: authGateway,
        refreshTokenStore: MemoryRefreshTokenStore(),
      );
      addTearDown(session.dispose);
      final accountGateway = FakeAccountGateway(
        onLogin: (_, _) {
          loginStarted.complete();
          return releaseLogin.future;
        },
      );
      await pumpLoginPage(tester, session, accountGateway);

      await tester.enterText(find.byKey(const Key('login-field')), 'e2e.user');
      await tester.enterText(
        find.byKey(const Key('login-password-field')),
        'E2e-Flow-Password-2026',
      );
      await tester.tap(find.byKey(const Key('login-submit')));
      await tester.pump();
      await loginStarted.future;

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      releaseLogin.complete(testCredentials());
      await tester.pumpAndSettle();

      expect(session.phase, isNot(SessionPhase.authenticated));
      expect(session.currentUser, isNull);
      expect(authGateway.fetchMeCount, 0);
    },
  );
}
