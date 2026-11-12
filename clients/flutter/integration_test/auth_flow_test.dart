import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:jlu_dela/app/app.dart';
import 'package:jlu_dela/core/api/api_failure.dart';
import 'package:jlu_dela/core/api/diagnostics_service.dart';
import 'package:jlu_dela/core/auth/account_gateway.dart';
import 'package:jlu_dela/core/auth/auth_gateway.dart';
import 'package:jlu_dela/core/auth/refresh_token_store.dart';
import 'package:jlu_dela/core/auth/session_controller.dart';
import 'package:jlu_dela/core/auth/session_models.dart';
import 'package:jlu_dela/core/config/app_config.dart';

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
const _inviteToken = String.fromEnvironment('TEST_INVITE_TOKEN');
const _login = String.fromEnvironment('TEST_LOGIN');
const _password = String.fromEnvironment('TEST_PASSWORD');
const _expectedDisplayName = String.fromEnvironment(
  'TEST_DISPLAY_NAME',
  defaultValue: '闭环用户',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final configured =
      _apiBaseUrl.isNotEmpty &&
      _inviteToken.isNotEmpty &&
      _login.isNotEmpty &&
      _password.isNotEmpty;

  testWidgets('activates the invitation, signs out, logs in and restores', (
    tester,
  ) async {
    final baseUri = AppConfig.resolveApiBaseUri(_apiBaseUrl);
    final store = SecureRefreshTokenStore();
    await store.clear();
    addTearDown(store.clear);

    final authGateway = HttpAuthGateway(baseUri: baseUri);
    final accountGateway = HttpAccountGateway(baseUri: baseUri);
    final session = SessionController(
      gateway: authGateway,
      refreshTokenStore: store,
    );
    addTearDown(session.dispose);
    await session.restore();
    expect(session.phase, SessionPhase.signedOut);

    final diagnostics = DiagnosticsService(
      apiBaseUri: baseUri,
      httpClient: http.Client(),
    );
    await tester.pumpWidget(
      JluDelaApp(
        diagnosticsService: diagnostics,
        session: session,
        accountGateway: accountGateway,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-page')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('login-activate-entry')));
    await tester.tap(find.byKey(const Key('login-activate-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activate-page')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('activate-invite-field')),
      _inviteToken,
    );
    await tester.enterText(
      find.byKey(const Key('activate-password-field')),
      _password,
    );
    await tester.enterText(
      find.byKey(const Key('activate-confirm-field')),
      _password,
    );
    await tester.ensureVisible(find.byKey(const Key('activate-submit')));
    await tester.tap(find.byKey(const Key('activate-submit')));
    await _pumpUntil(
      tester,
      () => session.phase == SessionPhase.authenticated,
      reason: 'activation did not reach the authenticated session',
    );
    await tester.pumpAndSettle();
    expect(session.currentUser?.displayName, _expectedDisplayName);

    await _openSettings(tester);
    expect(find.text('已登录'), findsOneWidget);
    expect(find.text('当前用户：$_expectedDisplayName'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('session-sign-out')));
    await tester.tap(find.byKey(const Key('session-sign-out')));
    await _pumpUntil(
      tester,
      () => session.phase == SessionPhase.signedOut,
      reason: 'sign-out did not reach the signed-out session',
    );
    await _waitForStoredTokenCleared(store);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('destination-calendar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-page')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('login-field')), _login);
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      _password,
    );
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.tap(find.byKey(const Key('login-submit')));
    await _pumpUntil(
      tester,
      () => session.phase == SessionPhase.authenticated,
      reason: 'login did not reach the authenticated session',
    );
    await tester.pumpAndSettle();
    expect(session.currentUser?.displayName, _expectedDisplayName);

    final restarted = SessionController(
      gateway: HttpAuthGateway(baseUri: baseUri),
      refreshTokenStore: store,
    );
    addTearDown(restarted.dispose);
    await restarted.restore();
    expect(restarted.phase, SessionPhase.authenticated);
    expect(restarted.currentUser?.displayName, _expectedDisplayName);

    await tester.pumpWidget(
      JluDelaApp(
        diagnosticsService: diagnostics,
        session: restarted,
        accountGateway: accountGateway,
      ),
    );
    await tester.pumpAndSettle();
    await _openSettings(tester);
    expect(find.text('已登录'), findsOneWidget);
    expect(find.text('当前用户：$_expectedDisplayName'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('session-sign-out')));
    await tester.tap(find.byKey(const Key('session-sign-out')));
    await _pumpUntil(
      tester,
      () => restarted.phase == SessionPhase.signedOut,
      reason: 'the restored session did not sign out',
    );
    await _waitForStoredTokenCleared(store);
    await tester.pumpAndSettle();

    await expectLater(
      accountGateway.activate(inviteToken: _inviteToken, password: _password),
      throwsA(
        isA<ApiFailure>().having(
          (failure) => failure.code,
          'code',
          'INVALID_INVITE',
        ),
      ),
    );
  }, skip: !configured);
}

Future<void> _openSettings(WidgetTester tester) async {
  final destination = find.byKey(const Key('destination-settings'));
  await tester.ensureVisible(destination);
  await tester.tap(destination);
  await tester.pumpAndSettle();
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String reason,
  Duration timeout = const Duration(seconds: 45),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail(reason);
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _waitForStoredTokenCleared(
  RefreshTokenStore store, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (await store.read() != null) {
    if (DateTime.now().isAfter(deadline)) {
      fail('the secure refresh token store was not cleared');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}
