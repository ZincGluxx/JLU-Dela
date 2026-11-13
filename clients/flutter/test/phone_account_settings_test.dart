import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlu_dela/app/theme.dart';
import 'package:jlu_dela/core/auth/account_gateway.dart';
import 'package:jlu_dela/core/auth/account_validation.dart';
import 'package:jlu_dela/core/auth/profile_gateway.dart';
import 'package:jlu_dela/core/auth/session_controller.dart';
import 'package:jlu_dela/core/api/api_failure.dart';
import 'package:jlu_dela/features/auth/phone_login_form.dart';
import 'package:jlu_dela/features/settings/account_settings_form.dart';
import 'package:jlu_dela_api/api.dart';

import 'support/session_test_support.dart';

class FixtureProfileGateway implements ProfileGateway {
  Future<void> Function()? onVerify;
  Future<void> Function()? onUpdate;
  String? username;
  String? password;
  String? reportCode;

  @override
  Future<void> updateAccount({
    required String accessToken,
    String? username,
    String? displayName,
    String? password,
  }) async {
    this.username = username;
    this.password = password;
    await onUpdate?.call();
  }

  @override
  Future<void> verifyStudentReport({
    required String accessToken,
    required String reportCode,
  }) async {
    this.reportCode = reportCode;
    await onVerify?.call();
  }
}

void main() {
  test('new account validation preserves exact input and counts runes', () {
    for (final invalid in [
      'ABC123',
      'abc12',
      'abc12345678',
      ' abc123',
      'abc123 ',
      'abc_12',
      'abc123\n',
    ]) {
      expect(validateNewUsername(invalid), isNotNull);
    }
    expect(validateNewUsername('abc123'), isNull);
    expect(validateNewPassword('Abc123😀😀'), isNull);
    expect(validateNewPassword('Abc123😀'), isNotNull);
    expect(validateNewPassword('Abcdefgh'), isNotNull);
    expect(validateNewPassword(' ABC1234'), isNotNull);
    expect(validateNewPassword(' Abc1234 '), isNull);
  });

  test(
    'phone gateway uses generated endpoints and preserves credentials',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'meta': {'request_id': 'fixture'},
            'data': request.url.path.endsWith('/code')
                ? {'expires_in': 300, 'retry_after': 60}
                : {
                    'access_token': 'fixture-access',
                    'refresh_token': 'fixture-refresh',
                    'token_type': 'Bearer',
                    'expires_in': 900,
                  },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final gateway = HttpAccountGateway(
        baseUri: Uri.parse('http://fixture.invalid'),
        httpClient: client,
      );
      expect((await gateway.sendPhoneCode('13800138000')).retryAfter, 60);
      final credentials = await gateway.loginWithPhone(
        phone: '13800138000',
        smsCode: '123456',
      );
      expect(credentials.accessToken, 'fixture-access');
      expect(requests.map((request) => request.url.path), [
        '/api/v1/auth/phone/code',
        '/api/v1/auth/phone/login',
      ]);
      expect(jsonDecode(requests.last.body), {
        'phone': '13800138000',
        'sms_code': '123456',
      });
    },
  );

  test(
    'verification refreshes shared identity immediately without rotating tokens',
    () async {
      final profile = FixtureProfileGateway();
      var verified = false;
      profile.onVerify = () async {
        verified = true;
      };
      final auth = FakeAuthGateway(
        onFetchMe: (_) async => testUser(
          studentVerified: verified,
          college: verified
              ? College(id: 'fixture-college', name: '夹具学院')
              : null,
        ),
      );
      final session = SessionController(
        gateway: auth,
        refreshTokenStore: MemoryRefreshTokenStore(),
        profileGateway: profile,
      );
      addTearDown(session.dispose);
      await session.signIn(testCredentials());
      expect(await session.verifyStudentReport('fixture-report'), isTrue);
      expect(session.currentUser!.studentVerified, isTrue);
      expect(session.currentUser!.college!.id, 'fixture-college');
      expect(auth.refreshCount, 0);
      expect(session.identityRevision, 1);
    },
  );

  test(
    'account switch discards pending verification before fetching new user',
    () async {
      final pending = Completer<void>();
      final profile = FixtureProfileGateway()..onVerify = () => pending.future;
      final auth = FakeAuthGateway(
        onFetchMe: (token) async => testUser(id: token),
      );
      final session = SessionController(
        gateway: auth,
        refreshTokenStore: MemoryRefreshTokenStore(),
        profileGateway: profile,
      );
      addTearDown(session.dispose);
      await session.signIn(testCredentials());
      final verify = session.verifyStudentReport('fixture-report');
      await session.signIn(testCredentials(accessToken: 'access-b'));
      pending.complete();
      expect(await verify, isFalse);
      expect(auth.fetchMeCount, 2);
      expect(session.currentUser!.id, 'access-b');
    },
  );

  for (final action in ['account', 'report', 'me']) {
    test('$action refreshes an explicitly expired access token once', () async {
      final profile = FixtureProfileGateway();
      var calls = 0;
      final expired = ApiException(
        401,
        '{"error":{"code":"TOKEN_EXPIRED","message":"fixture","request_id":"fixture","retryable":false,"fields":[]}}',
      );
      Future<void> mutate() async {
        if (calls++ == 0) throw expired;
      }

      profile.onUpdate = mutate;
      profile.onVerify = mutate;
      final auth = FakeAuthGateway(
        onFetchMe: (_) async => testUser(),
        onRefresh: (_) async => testTokenPair(accessToken: 'rotated'),
      );
      final session = SessionController(
        gateway: auth,
        refreshTokenStore: MemoryRefreshTokenStore(),
        profileGateway: profile,
      );
      addTearDown(session.dispose);
      await session.signIn(testCredentials());
      if (action == 'me') {
        auth.onFetchMe = (_) async {
          if (calls++ == 0) throw expired;
          return testUser();
        };
      }
      final result = switch (action) {
        'account' => await session.updateAccount(username: 'abc123'),
        'report' => await session.verifyStudentReport('fixture-report'),
        _ => await session.refreshCurrentUser(),
      };
      expect(result, isTrue);
      expect(auth.refreshCount, 1);
      expect(session.accessToken, 'rotated');
      expect(calls, 2);
    });
  }

  test('late current-user response cannot replace another account', () async {
    final auth = FakeAuthGateway(onFetchMe: (_) async => testUser());
    final session = SessionController(
      gateway: auth,
      refreshTokenStore: MemoryRefreshTokenStore(),
    );
    addTearDown(session.dispose);
    await session.signIn(testCredentials());
    final pending = Completer<Me>();
    auth.onFetchMe = (_) => pending.future;
    final refresh = session.refreshCurrentUser();
    auth.onFetchMe = (_) async => testUser(id: 'fixture-b');
    await session.signIn(testCredentials(accessToken: 'access-b'));
    pending.complete(testUser(studentVerified: true));
    expect(await refresh, isFalse);
    expect(session.currentUser!.id, 'fixture-b');
  });

  testWidgets('phone send failure, countdown, expiry and resend are actionable', (
    tester,
  ) async {
    var sends = 0;
    final gateway = HttpAccountGateway(
      baseUri: Uri.parse('http://fixture.invalid'),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/code')) {
          sends++;
          if (sends == 1) {
            return http.Response(
              '{"error":{"code":"SMS_SEND_FAILED","message":"fixture","retryable":true,"request_id":"fixture","fields":[]}}',
              503,
            );
          }
          return http.Response(
            '{"data":{"expires_in":300,"retry_after":2},"meta":{"request_id":"fixture"}}',
            200,
          );
        }
        return http.Response(
          '{"error":{"code":"SMS_CODE_EXPIRED","message":"fixture","retryable":false,"request_id":"fixture","fields":[]}}',
          422,
        );
      }),
    );
    final session = SessionController(
      gateway: FakeAuthGateway(),
      refreshTokenStore: MemoryRefreshTokenStore(),
    );
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PhoneLoginForm(gateway: gateway, session: session),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('phone-field')), '13800138000');
    await tester.tap(find.byKey(const Key('send-phone-code')));
    await tester.pumpAndSettle();
    expect(find.text('验证码发送失败，请稍后重试。'), findsOneWidget);
    await tester.tap(find.byKey(const Key('send-phone-code')));
    await tester.pumpAndSettle();
    expect(find.text('2 秒后重新发送'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('sms-code-field')), '123456');
    await tester.tap(find.byKey(const Key('phone-login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('验证码已过期，请重新发送。'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('send-phone-code')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('send-phone-code')));
    await tester.pumpAndSettle();
    expect(sends, 3);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unconfigured SMS service is shown explicitly', (tester) async {
    final gateway = HttpAccountGateway(
      baseUri: Uri.parse('http://fixture.invalid'),
      httpClient: MockClient(
        (_) async => http.Response(
          '{"error":{"code":"SMS_UNAVAILABLE","message":"fixture","request_id":"fixture","retryable":false,"fields":[]}}',
          503,
        ),
      ),
    );
    final session = SessionController(
      gateway: FakeAuthGateway(),
      refreshTokenStore: MemoryRefreshTokenStore(),
    );
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PhoneLoginForm(gateway: gateway, session: session),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('phone-field')), '13800138000');
    await tester.tap(find.byKey(const Key('send-phone-code')));
    await tester.pumpAndSettle();
    expect(find.text('短信服务未配置，暂时无法发送验证码。'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final devMode in [false, true]) {
    testWidgets('phone development notice follows server dev_mode $devMode', (
      tester,
    ) async {
      final gateway = HttpAccountGateway(
        baseUri: Uri.parse('http://fixture.invalid'),
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': {
                'expires_in': 300,
                'retry_after': 60,
                'dev_mode': devMode,
              },
              'meta': {'request_id': 'fixture'},
            }),
            200,
          ),
        ),
      );
      final result = await gateway.sendPhoneCode('13800138000');
      expect(result.devMode, devMode);
      final session = SessionController(
        gateway: FakeAuthGateway(),
        refreshTokenStore: MemoryRefreshTokenStore(),
      );
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PhoneLoginForm(gateway: gateway, session: session),
          ),
        ),
      );
      expect(find.byKey(const Key('phone-development-notice')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('phone-field')),
        '13800138000',
      );
      await tester.tap(find.byKey(const Key('send-phone-code')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('phone-development-notice')),
        devMode ? findsOneWidget : findsNothing,
      );
      expect(find.textContaining('114514'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'report verification updates school and college without extra identity fields',
    (tester) async {
      var reportVerified = false;
      final profile = FixtureProfileGateway()
        ..onVerify = () async {
          reportVerified = true;
        };
      final auth = FakeAuthGateway(
        onFetchMe: (_) async => testUser(
          studentVerified: reportVerified,
          college: reportVerified
              ? College(id: 'fixture-college', name: '夹具学院')
              : null,
        ),
      );
      final session = SessionController(
        gateway: auth,
        refreshTokenStore: MemoryRefreshTokenStore(),
        profileGateway: profile,
      );
      addTearDown(session.dispose);
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
      await tester.enterText(
        find.byKey(const Key('student-report-code')),
        'fixture-report',
      );
      await tester.ensureVisible(
        find.byKey(const Key('student-report-submit')),
      );
      await tester.tap(find.byKey(const Key('student-report-submit')));
      await tester.pumpAndSettle();
      expect(find.text('吉林大学学籍报告已核验，学院信息已更新。'), findsOneWidget);
      expect(session.currentUser!.studentVerified, isTrue);
      expect(session.currentUser!.college!.name, '夹具学院');
      expect(profile.reportCode, 'fixture-report');
      expect(auth.fetchMeCount, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final entry in {
    'STUDENT_REPORT_INVALID': '报告验证码无效，请检查后重试。',
    'STUDENT_REPORT_PARSE_FAILED': '暂时无法识别该报告，请稍后重试。',
    'STUDENT_NOT_ELIGIBLE': '报告中的学校不是吉林大学。',
    'STUDENT_REPORT_RESTRICTED': '学信网暂时限制服务端查询，请稍后重试。',
  }.entries) {
    testWidgets('rejected report ${entry.key} cannot show success', (
      tester,
    ) async {
      final profile = FixtureProfileGateway()
        ..onVerify = () async => throw ApiFailure(
          kind: ApiFailureKind.server,
          technicalMessage: 'fixture',
          code: entry.key,
          statusCode:
              entry.key == 'STUDENT_REPORT_RESTRICTED' ||
                  entry.key == 'STUDENT_REPORT_PARSE_FAILED'
              ? 503
              : 422,
        );
      final auth = FakeAuthGateway(onFetchMe: (_) async => testUser());
      final session = SessionController(
        gateway: auth,
        refreshTokenStore: MemoryRefreshTokenStore(),
        profileGateway: profile,
      );
      addTearDown(session.dispose);
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
      expect(find.text('核验报告中的吉林大学学校信息与学院，不核对本人身份，不限制学籍状态。'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('student-report-code')),
        'fixture-report',
      );
      await tester.ensureVisible(
        find.byKey(const Key('student-report-submit')),
      );
      await tester.tap(find.byKey(const Key('student-report-submit')));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('吉林大学学籍报告已核验，学院信息已更新。'), findsNothing);
      expect(session.currentUser!.studentVerified, isFalse);
      expect(session.accessToken, testCredentials().accessToken);
      expect(auth.fetchMeCount, 1);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'username conflict appears beside field and nullable settings are explicit',
    (tester) async {
      final profile = FixtureProfileGateway()
        ..onUpdate = () async => throw const ApiFailure(
          kind: ApiFailureKind.server,
          technicalMessage: 'fixture',
          code: 'USERNAME_TAKEN',
        );
      final session = SessionController(
        gateway: FakeAuthGateway(onFetchMe: (_) async => testUser()),
        refreshTokenStore: MemoryRefreshTokenStore(),
        profileGateway: profile,
      );
      addTearDown(session.dispose);
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
      expect(find.text('用户名：未设置'), findsOneWidget);
      expect(find.text('密码：未设置'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('account-username')),
        'abc123',
      );
      await tester.enterText(
        find.byKey(const Key('account-password')),
        ' Abc1234 ',
      );
      await tester.ensureVisible(find.byKey(const Key('account-save')));
      await tester.tap(find.byKey(const Key('account-save')));
      await tester.pumpAndSettle();
      expect(find.text('用户名已被使用，请更换'), findsOneWidget);
      expect(profile.password, ' Abc1234 ');
      expect(profile.username, 'abc123');
    },
  );
}
