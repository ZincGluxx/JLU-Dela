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

    for (final outcome in ['refreshed', 'network', 'revoked', 'switch']) {
      test(
        '${action.key} waits for in-flight rotation on INVALID_TOKEN ($outcome)',
        () async {
          final fixture = await _signedInSession();
          final refreshStarted = Completer<void>();
          final rotation = Completer<TokenPair>();
          final requestFailed = Completer<void>();
          final requestTokens = <String>[];
          final latest = testUser(displayName: '刷新后的昵称');
          fixture.auth.onRefresh = (_) {
            refreshStarted.complete();
            return rotation.future;
          };
          fixture.auth.onFetchMe = (token) async {
            if (token == 'access-a') {
              requestFailed.complete();
              throw _apiError(401, 'INVALID_TOKEN');
            }
            return token == 'access-b' ? testUser(id: 'user-b') : latest;
          };
          fixture.profile.onRequest = (token) async {
            requestTokens.add(token);
            if (token == 'access-a') {
              requestFailed.complete();
              throw _apiError(401, 'INVALID_TOKEN');
            }
          };
          final refresh = fixture.session.refreshSession();
          await refreshStarted.future;
          var settled = false;
          final request = action.value(fixture.session).then((result) {
            settled = true;
            return result;
          });
          await requestFailed.future;
          await Future<void>.value();

          expect(settled, isFalse);
          expect(fixture.session.phase, SessionPhase.authenticated);
          expect(fixture.session.accessToken, 'access-a');
          expect(fixture.store.token, 'refresh-a');
          expect(fixture.store.clearCount, 0);
          expect(fixture.cacheClears, 0);

          if (outcome == 'switch') {
            await fixture.session.signIn(
              testCredentials(
                accessToken: 'access-b',
                refreshToken: 'refresh-b',
              ),
            );
          }
          switch (outcome) {
            case 'network':
              rotation.completeError(http.ClientException('offline'));
            case 'revoked':
              rotation.completeError(_apiError(401, 'SESSION_REVOKED'));
            default:
              rotation.complete(
                testTokenPair(
                  accessToken: 'access-rotated',
                  refreshToken: 'refresh-rotated',
                ),
              );
          }

          expect(await request, outcome == 'refreshed');
          expect(await refresh, switch (outcome) {
            'network' => SessionRefreshResult.networkFailure,
            'revoked' => SessionRefreshResult.signedOut,
            'switch' => SessionRefreshResult.cancelled,
            _ => SessionRefreshResult.refreshed,
          });
          expect(fixture.auth.refreshCount, 1);
          if (action.key != 'refreshCurrentUser') {
            expect(requestTokens, [
              'access-a',
              if (outcome == 'refreshed') 'access-rotated',
            ]);
          }
          expect(fixture.session.phase, switch (outcome) {
            'network' => SessionPhase.unavailable,
            'revoked' => SessionPhase.signedOut,
            _ => SessionPhase.authenticated,
          });
          expect(fixture.session.accessToken, switch (outcome) {
            'network' => 'access-a',
            'revoked' => null,
            'switch' => 'access-b',
            _ => 'access-rotated',
          });
          expect(fixture.store.token, switch (outcome) {
            'network' => 'refresh-a',
            'revoked' => null,
            'switch' => 'refresh-b',
            _ => 'refresh-rotated',
          });
          expect(fixture.store.clearCount, outcome == 'revoked' ? 1 : 0);
          expect(
            fixture.cacheClears,
            outcome == 'revoked' || outcome == 'switch' ? 1 : 0,
          );
          if (outcome == 'refreshed') {
            expect(fixture.session.currentUser, same(latest));
          } else if (outcome == 'switch') {
            expect(fixture.session.currentUser?.id, 'user-b');
          }
        },
      );
    }

    test(
      '${action.key} does not defer SESSION_REVOKED during rotation',
      () async {
        final fixture = await _signedInSession();
        final refreshStarted = Completer<void>();
        final rotation = Completer<TokenPair>();
        fixture.auth.onRefresh = (_) {
          refreshStarted.complete();
          return rotation.future;
        };
        fixture.auth.onFetchMe = (_) async =>
            throw _apiError(401, 'SESSION_REVOKED');
        fixture.profile.onRequest = (_) async =>
            throw _apiError(401, 'SESSION_REVOKED');
        final refresh = fixture.session.refreshSession();
        await refreshStarted.future;

        expect(await action.value(fixture.session), isFalse);
        expect(fixture.session.phase, SessionPhase.signedOut);
        expect(fixture.session.accessToken, isNull);
        expect(fixture.store.token, isNull);
        rotation.complete(
          testTokenPair(
            accessToken: 'access-rotated',
            refreshToken: 'refresh-rotated',
          ),
        );
        expect(await refresh, SessionRefreshResult.cancelled);
        expect(fixture.store.token, isNull);
        expect(fixture.store.clearCount, 1);
        expect(fixture.cacheClears, 1);
      },
    );

    test('${action.key} rejects a revoked rotated token', () async {
      final fixture = await _signedInSession();
      final refreshStarted = Completer<void>();
      final requestFailed = Completer<void>();
      final rotation = Completer<TokenPair>();
      fixture.auth.onRefresh = (_) {
        refreshStarted.complete();
        return rotation.future;
      };
      fixture.auth.onFetchMe = (token) async {
        if (token == 'access-a') {
          requestFailed.complete();
          throw _apiError(401, 'INVALID_TOKEN');
        }
        if (action.key == 'refreshCurrentUser') {
          throw _apiError(401, 'SESSION_REVOKED');
        }
        return testUser();
      };
      final requestTokens = <String>[];
      fixture.profile.onRequest = (token) async {
        requestTokens.add(token);
        if (token == 'access-a') requestFailed.complete();
        throw _apiError(
          401,
          token == 'access-a' ? 'INVALID_TOKEN' : 'SESSION_REVOKED',
        );
      };
      final refresh = fixture.session.refreshSession();
      await refreshStarted.future;
      final request = action.value(fixture.session);
      await requestFailed.future;
      await Future<void>.value();
      rotation.complete(
        testTokenPair(
          accessToken: 'access-rotated',
          refreshToken: 'refresh-rotated',
        ),
      );

      expect(await request, isFalse);
      expect(
        await refresh,
        action.key == 'refreshCurrentUser'
            ? SessionRefreshResult.signedOut
            : SessionRefreshResult.refreshed,
      );
      if (action.key != 'refreshCurrentUser') {
        expect(requestTokens, ['access-a', 'access-rotated']);
      }
      expect(fixture.session.phase, SessionPhase.signedOut);
      expect(fixture.session.accessToken, isNull);
      expect(fixture.store.token, isNull);
      expect(fixture.store.clearCount, 1);
      expect(fixture.cacheClears, 1);
      expect(fixture.auth.refreshCount, 1);
    });

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
