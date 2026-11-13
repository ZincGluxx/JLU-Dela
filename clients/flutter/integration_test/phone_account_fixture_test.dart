import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jlu_dela/app/theme.dart';
import 'package:jlu_dela/core/auth/account_gateway.dart';
import 'package:jlu_dela/core/auth/session_controller.dart';
import 'package:jlu_dela/features/auth/login_page.dart';
import 'package:jlu_dela/features/settings/account_settings_form.dart';

import '../test/support/session_test_support.dart';
import '../test/phone_account_settings_test.dart' show FixtureProfileGateway;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Windows isolated fixture phone failure, password switch and settings',
    (tester) async {
      final profile = FixtureProfileGateway();
      final session = SessionController(
        gateway: FakeAuthGateway(onFetchMe: (_) async => testUser()),
        refreshTokenStore: MemoryRefreshTokenStore(),
        profileGateway: profile,
      );
      addTearDown(session.dispose);
      final gateway = HttpAccountGateway(
        baseUri: Uri.parse('http://fixture.invalid'),
        httpClient: MockClient(
          (request) async => http.Response(
            '{"error":{"code":"SMS_SEND_FAILED","message":"fixture","request_id":"fixture","retryable":true,"fields":[]}}',
            503,
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: LoginPage(session: session, accountGateway: gateway),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final view = tester.view;
      debugPrint(
        'Windows fixture logical viewport: ${view.physicalSize / view.devicePixelRatio}',
      );
      expect(find.byKey(const Key('phone-field')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('phone-field')),
        '13800138000',
      );
      await tester.ensureVisible(find.byKey(const Key('send-phone-code')));
      await tester.tap(find.byKey(const Key('send-phone-code')));
      await tester.pumpAndSettle();
      expect(find.text('验证码发送失败，请稍后重试。'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('login-method-toggle')));
      await tester.tap(find.byKey(const Key('login-method-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login-password-field')), findsOneWidget);
      await session.signIn(testCredentials());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AccountSettingsForm(session: session),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('用户名：未设置'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('account-username')),
        'fixture1',
      );
      await tester.ensureVisible(find.byKey(const Key('account-save')));
      await tester.tap(find.byKey(const Key('account-save')));
      await tester.pumpAndSettle();
      expect(profile.username, 'fixture1');
      expect(find.text('账号设置已保存。'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
