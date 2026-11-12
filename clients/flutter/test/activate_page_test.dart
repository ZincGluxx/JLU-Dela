import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/theme.dart';
import 'package:jlu_dela/core/api/api_failure.dart';
import 'package:jlu_dela/core/auth/session_controller.dart';
import 'package:jlu_dela/core/auth/session_models.dart';
import 'package:jlu_dela/features/auth/activate_page.dart';

import 'support/session_test_support.dart';

void main() {
  SessionController buildSession({FakeAuthGateway? gateway}) {
    return SessionController(
      gateway: gateway ?? FakeAuthGateway(),
      refreshTokenStore: MemoryRefreshTokenStore(),
    );
  }

  Future<void> pumpActivatePage(
    WidgetTester tester,
    SessionController session,
    FakeAccountGateway accountGateway,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ActivatePage(session: session, accountGateway: accountGateway),
      ),
    );
    await tester.pump();
  }

  String? fieldText(WidgetTester tester, String key) {
    return tester.widget<TextFormField>(find.byKey(Key(key))).controller?.text;
  }

  testWidgets('validates the invitation, password length and confirmation', (
    tester,
  ) async {
    final session = buildSession();
    addTearDown(session.dispose);
    final accountGateway = FakeAccountGateway();
    await pumpActivatePage(tester, session, accountGateway);

    await tester.tap(find.byKey(const Key('activate-submit')));
    await tester.pump();

    expect(find.text('请输入邀请码'), findsOneWidget);
    expect(find.text('密码长度需为 12–128 个字符'), findsOneWidget);
    expect(find.text('请再次输入密码'), findsOneWidget);
    expect(accountGateway.activateCount, 0);

    await tester.enterText(
      find.byKey(const Key('activate-invite-field')),
      'inv_test_token',
    );
    await tester.enterText(
      find.byKey(const Key('activate-password-field')),
      'E2e-Flow-Password-2026',
    );
    await tester.enterText(
      find.byKey(const Key('activate-confirm-field')),
      'E2e-Flow-Password-2027',
    );
    await tester.tap(find.byKey(const Key('activate-submit')));
    await tester.pump();

    expect(find.text('两次输入的密码不一致'), findsOneWidget);
    expect(accountGateway.activateCount, 0);
  });

  testWidgets('keeps the invitation, clears both passwords and explains an '
      'invalid invitation', (tester) async {
    final session = buildSession();
    addTearDown(session.dispose);
    final accountGateway = FakeAccountGateway(
      onActivate: (_, _) async => throw const ApiFailure(
        kind: ApiFailureKind.server,
        technicalMessage: 'invalid invitation',
        code: 'INVALID_INVITE',
        statusCode: 401,
      ),
    );
    await pumpActivatePage(tester, session, accountGateway);

    await tester.enterText(
      find.byKey(const Key('activate-invite-field')),
      'inv_test_token',
    );
    await tester.enterText(
      find.byKey(const Key('activate-password-field')),
      'E2e-Flow-Password-2026',
    );
    await tester.enterText(
      find.byKey(const Key('activate-confirm-field')),
      'E2e-Flow-Password-2026',
    );
    await tester.tap(find.byKey(const Key('activate-submit')));
    await tester.pumpAndSettle();

    expect(fieldText(tester, 'activate-invite-field'), 'inv_test_token');
    expect(fieldText(tester, 'activate-password-field'), isEmpty);
    expect(fieldText(tester, 'activate-confirm-field'), isEmpty);
    expect(find.text('邀请码无效、已过期或已使用，请联系管理员重新获取。'), findsOneWidget);
    expect(find.textContaining('E2e-Flow-Password-2026'), findsNothing);
    expect(session.phase, isNot(SessionPhase.authenticated));
  });

  testWidgets('activates the account, clears all inputs and signs in', (
    tester,
  ) async {
    final session = buildSession(
      gateway: FakeAuthGateway(
        onFetchMe: (_) async => testUser(displayName: '闭环用户'),
      ),
    );
    addTearDown(session.dispose);
    final accountGateway = FakeAccountGateway(
      onActivate: (_, _) async => testCredentials(),
    );
    await pumpActivatePage(tester, session, accountGateway);

    await tester.enterText(
      find.byKey(const Key('activate-invite-field')),
      'inv_test_token',
    );
    await tester.enterText(
      find.byKey(const Key('activate-password-field')),
      'E2e-Flow-Password-2026',
    );
    await tester.enterText(
      find.byKey(const Key('activate-confirm-field')),
      'E2e-Flow-Password-2026',
    );
    await tester.tap(find.byKey(const Key('activate-submit')));
    await tester.pumpAndSettle();

    expect(session.phase, SessionPhase.authenticated);
    expect(session.currentUser?.displayName, '闭环用户');
    expect(fieldText(tester, 'activate-invite-field'), isEmpty);
    expect(fieldText(tester, 'activate-password-field'), isEmpty);
    expect(fieldText(tester, 'activate-confirm-field'), isEmpty);
    expect(accountGateway.lastInviteToken, 'inv_test_token');
    expect(accountGateway.lastPassword, 'E2e-Flow-Password-2026');
  });

  testWidgets('a disposed page cannot sign in after the activation returns', (
    tester,
  ) async {
    final activationStarted = Completer<void>();
    final releaseActivation = Completer<SessionCredentials>();
    final authGateway = FakeAuthGateway(
      onFetchMe: (_) async => testUser(displayName: '迟到的激活'),
    );
    final session = SessionController(
      gateway: authGateway,
      refreshTokenStore: MemoryRefreshTokenStore(),
    );
    addTearDown(session.dispose);
    final accountGateway = FakeAccountGateway(
      onActivate: (_, _) {
        activationStarted.complete();
        return releaseActivation.future;
      },
    );
    await pumpActivatePage(tester, session, accountGateway);

    await tester.enterText(
      find.byKey(const Key('activate-invite-field')),
      'inv_test_token',
    );
    await tester.enterText(
      find.byKey(const Key('activate-password-field')),
      'E2e-Flow-Password-2026',
    );
    await tester.enterText(
      find.byKey(const Key('activate-confirm-field')),
      'E2e-Flow-Password-2026',
    );
    await tester.tap(find.byKey(const Key('activate-submit')));
    await tester.pump();
    await activationStarted.future;

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    releaseActivation.complete(testCredentials());
    await tester.pumpAndSettle();

    expect(session.phase, isNot(SessionPhase.authenticated));
    expect(session.currentUser, isNull);
    expect(authGateway.fetchMeCount, 0);
  });
}
