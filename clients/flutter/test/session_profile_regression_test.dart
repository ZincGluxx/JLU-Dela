import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jlu_dela/core/auth/profile_gateway.dart';
import 'package:jlu_dela/core/auth/session_controller.dart';
import 'package:jlu_dela/core/auth/session_models.dart';
import 'package:jlu_dela_api/api.dart';

import 'support/session_test_support.dart';

final _actions = <String, Future<bool> Function(SessionController)>{
  'updateAccount': (session) => session.updateAccount(displayName: '新昵称'),
  'verifyStudentReport': (session) =>
      session.verifyStudentReport('report-code'),
  'refreshCurrentUser': (session) => session.refreshCurrentUser(),
};

const _revokedCodes = ['SESSION_REVOKED', 'INVALID_TOKEN', 'AUTH_REQUIRED'];

void main() {
  for (final action in _actions.entries) {
    for (final code in _revokedCodes) {
      test('${action.key} clears the session on $code', () async {
        final fixture = await _signedInSession();
        final error = _apiError(401, code);
        fixture.auth.onFetchMe = (_) async => throw error;
        fixture.profile.onRequest = (_) async => throw error;

        await _settleApiFailure(action.value(fixture.session));

        expect(fixture.session.phase, SessionPhase.signedOut);
        expect(fixture.session.accessToken, isNull);
        expect(fixture.session.currentUser, isNull);
        expect(fixture.store.token, isNull);
        expect(fixture.store.clearCount, 1);
        expect(fixture.cacheClears, 1);
        expect(fixture.auth.refreshCount, 0);
      });

      test('${action.key} ignores a late $code from the old account', () async {
        final fixture = await _signedInSession();
        final started = Completer<void>();
        final pending = Completer<Me>();
        fixture.auth.onFetchMe = (token) {
          if (token == 'access-b') return Future.value(testUser(id: 'user-b'));
          started.complete();
          return pending.future;
        };
        fixture.profile.onRequest = (_) async {
          started.complete();
          await pending.future;
        };
        final oldAction = _settleApiFailure(action.value(fixture.session));
        await started.future;
        await fixture.session.signIn(
          testCredentials(accessToken: 'access-b', refreshToken: 'refresh-b'),
        );
        final clearsAfterSignIn = fixture.cacheClears;

        pending.completeError(_apiError(401, code));
        await oldAction;

        expect(fixture.session.phase, SessionPhase.authenticated);
        expect(fixture.session.currentUser?.id, 'user-b');
        expect(fixture.session.accessToken, 'access-b');
        expect(fixture.store.token, 'refresh-b');
        expect(fixture.store.clearCount, 0);
        expect(fixture.cacheClears, clearsAfterSignIn);
      });
    }

    test('${action.key} retains the session on business 503', () async {
      final fixture = await _signedInSession();
      final user = fixture.session.currentUser;
      final error = _apiError(503, 'SERVICE_UNAVAILABLE');
      fixture.auth.onFetchMe = (_) async => throw error;
      fixture.profile.onRequest = (_) async => throw error;

      await expectLater(action.value(fixture.session), throwsA(same(error)));

      expect(fixture.session.phase, SessionPhase.authenticated);
      expect(fixture.session.currentUser, same(user));
      expect(fixture.session.accessToken, 'access-a');
      expect(fixture.store.token, 'refresh-a');
      expect(fixture.cacheClears, 0);
      expect(fixture.store.clearCount, 0);
      expect(fixture.auth.refreshCount, 0);
    });

    test(
      '${action.key} clears a revoked session after TOKEN_EXPIRED',
      () async {
        final fixture = await _signedInSession();
        fixture.auth.onRefresh = (_) async => testTokenPair(
          accessToken: 'access-rotated',
          refreshToken: 'refresh-rotated',
        );
        fixture.auth.onFetchMe = (token) async {
          if (action.key == 'refreshCurrentUser') {
            throw _apiError(
              401,
              token == 'access-a' ? 'TOKEN_EXPIRED' : 'SESSION_REVOKED',
            );
          }
          return testUser();
        };
        final requestTokens = <String>[];
        fixture.profile.onRequest = (token) async {
          requestTokens.add(token);
          throw _apiError(
            401,
            token == 'access-a' ? 'TOKEN_EXPIRED' : 'SESSION_REVOKED',
          );
        };

        await _settleApiFailure(action.value(fixture.session));

        expect(fixture.auth.refreshCount, 1);
        if (action.key != 'refreshCurrentUser') {
          expect(requestTokens, ['access-a', 'access-rotated']);
        }
        expect(fixture.session.phase, SessionPhase.signedOut);
        expect(fixture.session.currentUser, isNull);
        expect(fixture.session.accessToken, isNull);
        expect(fixture.store.token, isNull);
        expect(fixture.store.clearCount, 1);
        expect(fixture.cacheClears, 1);
      },
    );
  }

  for (final refreshFirst in [true, false]) {
    for (final lateResult in ['success', 'revoked', 'network']) {
      test(
        '${refreshFirst ? 'refresh' : 'profile'} old /me $lateResult cannot replace newer ${refreshFirst ? 'profile' : 'refresh'} snapshot',
        () async {
          final fixture = await _signedInSession();
          final oldStarted = Completer<void>();
          final oldMe = Completer<Me>();
          final latest = testUser(
            displayName: '最新昵称',
            studentVerified: true,
            college: College(id: 'verified-college', name: '核验学院'),
          );
          var requests = 0;
          fixture.auth.onRefresh = (_) async => testTokenPair(
            accessToken: 'access-rotated',
            refreshToken: 'refresh-rotated',
          );
          fixture.auth.onFetchMe = (_) {
            if (requests++ == 0) {
              oldStarted.complete();
              return oldMe.future;
            }
            return Future.value(latest);
          };
          final Future<void> oldRequest;
          if (refreshFirst) {
            oldRequest = fixture.session.refreshSession().then<void>((_) {});
          } else {
            oldRequest = _settleApiFailure(
              fixture.session.verifyStudentReport('old-report'),
            );
          }
          await oldStarted.future;

          if (refreshFirst) {
            expect(
              await fixture.session.verifyStudentReport('new-report'),
              isTrue,
            );
          } else {
            expect(
              await fixture.session.refreshSession(),
              SessionRefreshResult.refreshed,
            );
          }
          expect(fixture.session.currentUser, same(latest));

          switch (lateResult) {
            case 'success':
              oldMe.complete(testUser(displayName: '旧昵称'));
            case 'revoked':
              oldMe.completeError(_apiError(401, 'SESSION_REVOKED'));
            case 'network':
              oldMe.completeError(http.ClientException('offline'));
          }
          await oldRequest;

          expect(fixture.session.phase, SessionPhase.authenticated);
          expect(fixture.session.currentUser, same(latest));
          expect(fixture.session.currentUser?.studentVerified, isTrue);
          expect(fixture.session.currentUser?.college?.id, 'verified-college');
          expect(fixture.session.accessToken, 'access-rotated');
          expect(fixture.store.token, 'refresh-rotated');
          expect(fixture.store.clearCount, 0);
          expect(fixture.cacheClears, 0);
        },
      );
    }
  }
}

ApiException _apiError(int status, String code) => ApiException(
  status,
  jsonEncode({
    'error': {
      'code': code,
      'message': code,
      'request_id': 'profile-regression',
      'retryable': false,
      'fields': <Object>[],
    },
  }),
);

Future<void> _settleApiFailure(Future<bool> action) async {
  try {
    await action;
  } on ApiException {
    return;
  } on http.ClientException {
    return;
  }
}

Future<_SessionFixture> _signedInSession() async {
  final auth = FakeAuthGateway(onFetchMe: (_) async => testUser());
  final profile = _ProfileGateway();
  final store = MemoryRefreshTokenStore();
  final session = SessionController(
    gateway: auth,
    profileGateway: profile,
    refreshTokenStore: store,
  );
  addTearDown(session.dispose);
  await session.signIn(testCredentials());
  final fixture = _SessionFixture(session, auth, profile, store);
  session.registerPrivateCache(() => fixture.cacheClears++);
  return fixture;
}

class _SessionFixture {
  _SessionFixture(this.session, this.auth, this.profile, this.store);

  final SessionController session;
  final FakeAuthGateway auth;
  final _ProfileGateway profile;
  final MemoryRefreshTokenStore store;
  int cacheClears = 0;
}

class _ProfileGateway implements ProfileGateway {
  Future<void> Function(String token) onRequest = (_) async {};

  @override
  Future<void> updateAccount({
    required String accessToken,
    String? username,
    String? displayName,
    String? password,
  }) => onRequest(accessToken);

  @override
  Future<void> verifyStudentReport({
    required String accessToken,
    required String reportCode,
  }) => onRequest(accessToken);
}
