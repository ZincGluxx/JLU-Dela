import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jlu_dela/core/auth/auth_gateway.dart';
import 'package:jlu_dela/core/auth/session_controller.dart';
import 'package:jlu_dela/core/auth/session_models.dart';
import 'package:jlu_dela_api/api.dart';

import 'support/session_test_support.dart';
import 'support/test_http_server.dart';

void main() {
  test('restores the stored session and loads the current user', () async {
    late Map<String, dynamic> refreshBody;
    final server = await TestHttpServer.start((request, raw) async {
      if (request.path == '/api/v1/auth/refresh') {
        refreshBody = jsonDecode(request.body) as Map<String, dynamic>;
        await jsonResponse(raw, tokenPairBody('access-2', 'refresh-2'));
      } else if (request.path == '/api/v1/me') {
        expect(request.authorization, 'Bearer access-2');
        await jsonResponse(raw, meBody());
      } else {
        await jsonResponse(raw, errorBody('NOT_FOUND'), status: 404);
      }
    });
    addTearDown(server.close);

    final store = MemoryRefreshTokenStore('refresh-1');
    final controller = SessionController(
      gateway: HttpAuthGateway(baseUri: server.baseUri),
      refreshTokenStore: store,
    );
    addTearDown(controller.dispose);

    await controller.restore();

    expect(controller.phase, SessionPhase.authenticated);
    expect(controller.currentUser?.id, 'user-a');
    expect(controller.currentUser?.studentVerified, isFalse);
    expect(controller.currentUser?.college, isNull);
    expect(controller.accessToken, 'access-2');
    expect(store.token, 'refresh-2');
    expect(controller.identityRevision, 1);
    expect(refreshBody, {'refresh_token': 'refresh-1'});
  });

  test(
    'refresh replaces student and college information from the server',
    () async {
      final gateway = FakeAuthGateway(
        onFetchMe: (_) async => testUser(
          studentVerified: true,
          college: College(id: 'fixture-college', name: '测试学院'),
        ),
        onRefresh: (_) async => testTokenPair(),
        onRevoke: (_, _) async {},
      );
      final controller = SessionController(
        gateway: gateway,
        refreshTokenStore: MemoryRefreshTokenStore(),
      );
      addTearDown(controller.dispose);
      await controller.signIn(testCredentials());
      expect(controller.currentUser?.studentVerified, isTrue);
      expect(controller.currentUser?.college?.id, 'fixture-college');

      gateway.onFetchMe = (_) async => testUser();
      expect(await controller.refreshSession(), SessionRefreshResult.refreshed);
      expect(controller.currentUser?.studentVerified, isFalse);
      expect(controller.currentUser?.college, isNull);
      expect(gateway.fetchMeCount, 2);

      await controller.signOut();
      expect(controller.currentUser, isNull);
    },
  );

  test(
    'failed current-user refresh retains rotated token but is not online',
    () async {
      final store = MemoryRefreshTokenStore();
      final gateway = FakeAuthGateway(
        onFetchMe: (_) async => testUser(),
        onRefresh: (_) async => testTokenPair(refreshToken: 'rotated-refresh'),
      );
      final controller = SessionController(
        gateway: gateway,
        refreshTokenStore: store,
      );
      addTearDown(controller.dispose);
      await controller.signIn(testCredentials());
      gateway.onFetchMe = (_) async => throw http.ClientException('offline');
      expect(
        await controller.refreshSession(),
        SessionRefreshResult.networkFailure,
      );
      expect(controller.phase, SessionPhase.unavailable);
      expect(store.token, 'rotated-refresh');
      expect(controller.currentUser?.studentVerified, isFalse);
      gateway.onFetchMe = (_) async => testUser();
      await controller.retryRestore();
      expect(controller.phase, SessionPhase.authenticated);
    },
  );

  test('sign-out discards a delayed current-user refresh', () async {
    final gateway = FakeAuthGateway(
      onFetchMe: (_) async => testUser(),
      onRefresh: (_) async => testTokenPair(),
      onRevoke: (_, _) async {},
    );
    final controller = SessionController(
      gateway: gateway,
      refreshTokenStore: MemoryRefreshTokenStore(),
    );
    addTearDown(controller.dispose);
    await controller.signIn(testCredentials());
    final started = Completer<void>();
    final result = Completer<Me>();
    gateway.onFetchMe = (_) {
      started.complete();
      return result.future;
    };
    final refresh = controller.refreshSession();
    await started.future;
    await controller.signOut();
    result.complete(
      testUser(
        studentVerified: true,
        college: College(id: 'fixture', name: '测试学院'),
      ),
    );
    expect(await refresh, SessionRefreshResult.cancelled);
    expect(controller.currentUser, isNull);
    expect(controller.phase, SessionPhase.signedOut);
  });

  test('signs out locally when no refresh token is stored', () async {
    final server = await TestHttpServer.start((request, raw) async {
      await jsonResponse(raw, errorBody('UNEXPECTED'), status: 500);
    });
    addTearDown(server.close);

    final store = MemoryRefreshTokenStore();
    final controller = SessionController(
      gateway: HttpAuthGateway(baseUri: server.baseUri),
      refreshTokenStore: store,
    );
    addTearDown(controller.dispose);

    await controller.restore();

    expect(controller.phase, SessionPhase.signedOut);
    expect(controller.currentUser, isNull);
    expect(controller.accessToken, isNull);
    expect(store.token, isNull);
    expect(server.requests, isEmpty);
  });

  test('clears the stored token when the refresh token is rejected', () async {
    final server = await TestHttpServer.start((request, raw) async {
      if (request.path == '/api/v1/auth/refresh') {
        await jsonResponse(raw, errorBody('INVALID_TOKEN'), status: 401);
      } else {
        await jsonResponse(raw, errorBody('NOT_FOUND'), status: 404);
      }
    });
    addTearDown(server.close);

    final store = MemoryRefreshTokenStore('refresh-1');
    final controller = SessionController(
      gateway: HttpAuthGateway(baseUri: server.baseUri),
      refreshTokenStore: store,
    );
    addTearDown(controller.dispose);

    await controller.restore();

    expect(controller.phase, SessionPhase.signedOut);
    expect(controller.currentUser, isNull);
    expect(controller.accessToken, isNull);
    expect(store.token, isNull);
    expect(store.clearCount, greaterThan(0));
  });

  test(
    'keeps the refresh token on a network failure and retries restore',
    () async {
      final server = await TestHttpServer.start((request, raw) async {
        if (request.path == '/api/v1/auth/refresh') {
          await jsonResponse(raw, tokenPairBody('access-2', 'refresh-2'));
        } else if (request.path == '/api/v1/me') {
          await jsonResponse(raw, meBody());
        } else {
          await jsonResponse(raw, errorBody('NOT_FOUND'), status: 404);
        }
      });
      addTearDown(server.close);

      final store = MemoryRefreshTokenStore('refresh-1');
      final gateway = _FlakyAuthGateway(
        HttpAuthGateway(baseUri: server.baseUri),
      )..refreshFailuresRemaining = 1;
      final controller = SessionController(
        gateway: gateway,
        refreshTokenStore: store,
      );
      addTearDown(controller.dispose);

      await controller.restore();

      expect(controller.phase, SessionPhase.unavailable);
      expect(controller.currentUser, isNull);
      expect(store.token, 'refresh-1');

      await controller.retryRestore();

      expect(controller.phase, SessionPhase.authenticated);
      expect(controller.currentUser?.id, 'user-a');
      expect(store.token, 'refresh-2');
    },
  );

  test(
    'marks an authenticated session unavailable on a 5xx refresh and recovers',
    () async {
      var refreshFails = true;
      final server = await TestHttpServer.start((request, raw) async {
        if (request.path == '/api/v1/auth/refresh') {
          if (refreshFails) {
            await jsonResponse(raw, errorBody('INTERNAL'), status: 503);
          } else {
            await jsonResponse(raw, tokenPairBody('access-2', 'refresh-2'));
          }
        } else if (request.path == '/api/v1/me') {
          await jsonResponse(raw, meBody());
        } else {
          await jsonResponse(raw, errorBody('NOT_FOUND'), status: 404);
        }
      });
      addTearDown(server.close);

      final store = MemoryRefreshTokenStore();
      final controller = SessionController(
        gateway: HttpAuthGateway(baseUri: server.baseUri),
        refreshTokenStore: store,
      );
      addTearDown(controller.dispose);
      await controller.signIn(testCredentials());

      final result = await controller.refreshSession();

      expect(result, SessionRefreshResult.unavailable);
      expect(controller.phase, SessionPhase.unavailable);
      expect(controller.currentUser?.id, 'user-a');
      expect(controller.accessToken, 'access-a');
      expect(store.token, 'refresh-a');

      refreshFails = false;
      await controller.retryRestore();

      expect(controller.phase, SessionPhase.authenticated);
      expect(controller.currentUser?.id, 'user-a');
      expect(controller.accessToken, 'access-2');
      expect(store.token, 'refresh-2');
    },
  );

  test(
    'marks an authenticated session unavailable on a network refresh and recovers',
    () async {
      final server = await TestHttpServer.start((request, raw) async {
        if (request.path == '/api/v1/auth/refresh') {
          await jsonResponse(raw, tokenPairBody('access-2', 'refresh-2'));
        } else if (request.path == '/api/v1/me') {
          await jsonResponse(raw, meBody());
        } else {
          await jsonResponse(raw, errorBody('NOT_FOUND'), status: 404);
        }
      });
      addTearDown(server.close);

      final store = MemoryRefreshTokenStore();
      final gateway = _FlakyAuthGateway(
        HttpAuthGateway(baseUri: server.baseUri),
      );
      final controller = SessionController(
        gateway: gateway,
        refreshTokenStore: store,
      );
      addTearDown(controller.dispose);
      await controller.signIn(testCredentials());

      gateway.refreshFailuresRemaining = 1;
      final result = await controller.refreshSession();

      expect(result, SessionRefreshResult.networkFailure);
      expect(controller.phase, SessionPhase.unavailable);
      expect(controller.currentUser?.id, 'user-a');
      expect(store.token, 'refresh-a');

      await controller.retryRestore();

      expect(controller.phase, SessionPhase.authenticated);
      expect(store.token, 'refresh-2');
    },
  );

  test('does not write a stale refresh result back after sign-out', () async {
    final refreshStarted = Completer<void>();
    final releaseRefresh = Completer<void>();
    final server = await TestHttpServer.start((request, raw) async {
      if (request.path == '/api/v1/auth/refresh') {
        refreshStarted.complete();
        await releaseRefresh.future;
        await jsonResponse(raw, tokenPairBody('stale-access', 'stale-refresh'));
      } else if (request.path == '/api/v1/me') {
        await jsonResponse(raw, meBody());
      } else if (request.path == '/api/v1/auth/logout') {
        await emptyResponse(raw);
      } else {
        await jsonResponse(raw, errorBody('NOT_FOUND'), status: 404);
      }
    });
    addTearDown(server.close);

    final store = MemoryRefreshTokenStore();
    final controller = SessionController(
      gateway: HttpAuthGateway(baseUri: server.baseUri),
      refreshTokenStore: store,
    );
    addTearDown(controller.dispose);
    await controller.signIn(testCredentials());

    final refreshFuture = controller.refreshSession();
    await refreshStarted.future;

    final result = await controller.signOut();
    expect(result.remoteRevoked, isTrue);

    releaseRefresh.complete();
    expect(await refreshFuture, SessionRefreshResult.cancelled);

    expect(controller.phase, SessionPhase.signedOut);
    expect(controller.accessToken, isNull);
    expect(store.token, isNull);
    expect(store.writeCount, 1);
  });

  test(
    'clears private caches and bumps the revision when the account changes',
    () async {
      final server = await TestHttpServer.start((request, raw) async {
        if (request.path == '/api/v1/me') {
          if (request.authorization == 'Bearer access-a') {
            await jsonResponse(raw, meBody(id: 'user-a', displayName: '用户甲'));
          } else if (request.authorization == 'Bearer access-b') {
            await jsonResponse(raw, meBody(id: 'user-b', displayName: '用户乙'));
          } else {
            await jsonResponse(raw, errorBody('AUTH_REQUIRED'), status: 401);
          }
        } else {
          await jsonResponse(raw, errorBody('NOT_FOUND'), status: 404);
        }
      });
      addTearDown(server.close);

      final store = MemoryRefreshTokenStore();
      final controller = SessionController(
        gateway: HttpAuthGateway(baseUri: server.baseUri),
        refreshTokenStore: store,
      );
      addTearDown(controller.dispose);

      await controller.signIn(testCredentials());
      var clears = 0;
      controller.registerPrivateCache(() => clears++);
      final firstRevision = controller.identityRevision;

      await controller.signIn(
        testCredentials(accessToken: 'access-b', refreshToken: 'refresh-b'),
      );

      expect(controller.currentUser?.id, 'user-b');
      expect(controller.currentUser?.displayName, '用户乙');
      expect(controller.accessToken, 'access-b');
      expect(store.token, 'refresh-b');
      expect(clears, 1);
      expect(controller.identityRevision, firstRevision + 1);
    },
  );

  test('keeps the current identity when sign-in fails', () async {
    final server = await TestHttpServer.start((request, raw) async {
      if (request.path == '/api/v1/me') {
        if (request.authorization == 'Bearer access-a') {
          await jsonResponse(raw, meBody(id: 'user-a', displayName: '用户甲'));
        } else {
          await jsonResponse(raw, errorBody('INTERNAL'), status: 500);
        }
      } else {
        await jsonResponse(raw, errorBody('NOT_FOUND'), status: 404);
      }
    });
    addTearDown(server.close);

    final store = MemoryRefreshTokenStore();
    final controller = SessionController(
      gateway: HttpAuthGateway(baseUri: server.baseUri),
      refreshTokenStore: store,
    );
    addTearDown(controller.dispose);
    await controller.signIn(testCredentials());
    var clears = 0;
    controller.registerPrivateCache(() => clears++);
    final revision = controller.identityRevision;

    await expectLater(
      controller.signIn(
        testCredentials(accessToken: 'access-b', refreshToken: 'refresh-b'),
      ),
      throwsA(isA<ApiException>()),
    );

    expect(controller.phase, SessionPhase.authenticated);
    expect(controller.currentUser?.id, 'user-a');
    expect(controller.accessToken, 'access-a');
    expect(store.token, 'refresh-a');
    expect(clears, 0);
    expect(controller.identityRevision, revision);
  });

  test(
    'refreshes an expired access token before revoking on sign-out',
    () async {
      final logoutBodies = <Map<String, dynamic>>[];
      var refreshCount = 0;
      final server = await TestHttpServer.start((request, raw) async {
        if (request.path == '/api/v1/me') {
          await jsonResponse(raw, meBody());
        } else if (request.path == '/api/v1/auth/refresh') {
          refreshCount++;
          await jsonResponse(raw, tokenPairBody('access-b', 'refresh-b'));
        } else if (request.path == '/api/v1/auth/logout') {
          logoutBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          if (request.authorization == 'Bearer access-b') {
            await emptyResponse(raw);
          } else {
            await jsonResponse(raw, errorBody('TOKEN_EXPIRED'), status: 401);
          }
        } else {
          await jsonResponse(raw, errorBody('NOT_FOUND'), status: 404);
        }
      });
      addTearDown(server.close);

      final store = MemoryRefreshTokenStore();
      final controller = SessionController(
        gateway: HttpAuthGateway(baseUri: server.baseUri),
        refreshTokenStore: store,
      );
      addTearDown(controller.dispose);
      await controller.signIn(testCredentials());

      final result = await controller.signOut();

      expect(result.remoteRevoked, isTrue);
      expect(refreshCount, 1);
      expect(logoutBodies, [
        {'refresh_token': 'refresh-a'},
        {'refresh_token': 'refresh-b'},
      ]);
      expect(store.token, isNull);
      expect(controller.phase, SessionPhase.signedOut);
    },
  );

  test(
    'treats revoked identity codes as a confirmed remote sign-out',
    () async {
      for (final code in [
        'SESSION_REVOKED',
        'INVALID_TOKEN',
        'AUTH_REQUIRED',
      ]) {
        var refreshCount = 0;
        final server = await TestHttpServer.start((request, raw) async {
          if (request.path == '/api/v1/me') {
            await jsonResponse(raw, meBody());
          } else if (request.path == '/api/v1/auth/refresh') {
            refreshCount++;
            await jsonResponse(raw, tokenPairBody('access-b', 'refresh-b'));
          } else if (request.path == '/api/v1/auth/logout') {
            await jsonResponse(raw, errorBody(code), status: 401);
          } else {
            await jsonResponse(raw, errorBody('NOT_FOUND'), status: 404);
          }
        });
        final store = MemoryRefreshTokenStore();
        final controller = SessionController(
          gateway: HttpAuthGateway(baseUri: server.baseUri),
          refreshTokenStore: store,
        );
        await controller.signIn(testCredentials());

        final result = await controller.signOut();

        expect(result.remoteRevoked, isTrue, reason: code);
        expect(refreshCount, 0, reason: code);
        expect(store.token, isNull, reason: code);
        controller.dispose();
        await server.close();
      }
    },
  );

  test('reports an unconfirmed remote sign-out on a network failure', () async {
    final store = MemoryRefreshTokenStore();
    final gateway = FakeAuthGateway(
      onFetchMe: (_) async => testUser(),
      onRevoke: (_, _) async {
        throw http.ClientException('network unavailable');
      },
    );
    final controller = SessionController(
      gateway: gateway,
      refreshTokenStore: store,
    );
    addTearDown(controller.dispose);
    await controller.signIn(testCredentials());

    final result = await controller.signOut();

    expect(result.remoteRevoked, isFalse);
    expect(result.message, SessionController.remoteSignOutUnconfirmedMessage);
    expect(store.token, isNull);
    expect(controller.phase, SessionPhase.signedOut);
  });

  test(
    'refreshes before revoking when only a refresh token is available',
    () async {
      var refreshCount = 0;
      var logoutCount = 0;
      final server = await TestHttpServer.start((request, raw) async {
        if (request.path == '/api/v1/auth/refresh') {
          refreshCount++;
          await jsonResponse(raw, tokenPairBody('access-b', 'refresh-b'));
        } else if (request.path == '/api/v1/auth/logout') {
          logoutCount++;
          await emptyResponse(raw);
        } else if (request.path == '/api/v1/me') {
          await jsonResponse(raw, meBody());
        } else {
          await jsonResponse(raw, errorBody('NOT_FOUND'), status: 404);
        }
      });
      addTearDown(server.close);

      final store = MemoryRefreshTokenStore('refresh-a');
      final gateway = _FlakyAuthGateway(
        HttpAuthGateway(baseUri: server.baseUri),
      )..refreshFailuresRemaining = 1;
      final controller = SessionController(
        gateway: gateway,
        refreshTokenStore: store,
      );
      addTearDown(controller.dispose);

      await controller.restore();
      expect(controller.phase, SessionPhase.unavailable);
      expect(controller.accessToken, isNull);

      final result = await controller.signOut();

      expect(result.remoteRevoked, isTrue);
      expect(refreshCount, 1);
      expect(logoutCount, 1);
      expect(store.token, isNull);
      expect(controller.phase, SessionPhase.signedOut);
    },
  );

  test(
    'a delayed sign-in cannot restore identity after the session is invalidated',
    () async {
      final meStarted = Completer<void>();
      final releaseMe = Completer<void>();
      final gateway = FakeAuthGateway(
        onFetchMe: (_) async {
          meStarted.complete();
          await releaseMe.future;
          return testUser();
        },
      );
      final store = MemoryRefreshTokenStore();
      final controller = SessionController(
        gateway: gateway,
        refreshTokenStore: store,
      );
      addTearDown(controller.dispose);

      final signInFuture = controller.signIn(testCredentials());
      await meStarted.future;
      await controller.invalidateSession();
      releaseMe.complete();

      expect(await signInFuture, SignInOutcome.cancelled);
      expect(controller.phase, SessionPhase.signedOut);
      expect(controller.currentUser, isNull);
      expect(controller.accessToken, isNull);
      expect(store.token, isNull);
      expect(store.writeCount, 0);
    },
  );

  test(
    'the latest sign-in wins when two sign-ins return out of order',
    () async {
      final gates = <String, Completer<Me>>{
        'access-a': Completer<Me>(),
        'access-b': Completer<Me>(),
      };
      final gateway = FakeAuthGateway(
        onFetchMe: (accessToken) => gates[accessToken]!.future,
      );
      final store = MemoryRefreshTokenStore();
      final controller = SessionController(
        gateway: gateway,
        refreshTokenStore: store,
      );
      addTearDown(controller.dispose);

      final first = controller.signIn(testCredentials());
      final second = controller.signIn(
        testCredentials(accessToken: 'access-b', refreshToken: 'refresh-b'),
      );
      gates['access-b']!.complete(testUser(id: 'user-b', displayName: '用户乙'));
      gates['access-a']!.complete(testUser());

      expect(await second, SignInOutcome.signedIn);
      expect(await first, SignInOutcome.cancelled);
      expect(controller.currentUser?.id, 'user-b');
      expect(controller.accessToken, 'access-b');
      expect(store.token, 'refresh-b');
    },
  );

  test(
    'a sign-out during a delayed token write leaves the session signed out',
    () async {
      final store = ControlledRefreshTokenStore();
      final writeGate = Completer<void>();
      store.writeGates[0] = writeGate;
      final controller = SessionController(
        gateway: FakeAuthGateway(onFetchMe: (_) async => testUser()),
        refreshTokenStore: store,
      );
      addTearDown(controller.dispose);

      final signInFuture = controller.signIn(testCredentials());
      await _waitUntil(
        () =>
            store.operations.any((operation) => operation.startsWith('write:')),
      );
      final signOutFuture = controller.signOut();
      writeGate.complete();

      expect(await signInFuture, SignInOutcome.cancelled);
      final result = await signOutFuture;
      expect(result.remoteRevoked, isFalse);
      expect(controller.phase, SessionPhase.signedOut);
      expect(controller.currentUser, isNull);
      expect(store.token, isNull);
    },
  );

  test(
    'a stale sign-in write cannot overwrite the newer session token',
    () async {
      final store = ControlledRefreshTokenStore();
      final writeGate = Completer<void>();
      store.writeGates[0] = writeGate;
      final controller = SessionController(
        gateway: FakeAuthGateway(onFetchMe: (_) async => testUser()),
        refreshTokenStore: store,
      );
      addTearDown(controller.dispose);

      final first = controller.signIn(testCredentials());
      await _waitUntil(() => store.operations.contains('write:refresh-a'));
      final second = controller.signIn(
        testCredentials(accessToken: 'access-b', refreshToken: 'refresh-b'),
      );
      writeGate.complete();

      expect(await first, SignInOutcome.cancelled);
      expect(await second, SignInOutcome.signedIn);
      expect(controller.accessToken, 'access-b');
      expect(controller.currentUser?.id, 'user-a');
      expect(store.token, 'refresh-b');
      expect(store.operations.last, 'write:refresh-b');
    },
  );

  test('a stale clear cannot delete the newer session token', () async {
    final store = ControlledRefreshTokenStore();
    final writeGate = Completer<void>();
    store.writeGates[0] = writeGate;
    final controller = SessionController(
      gateway: FakeAuthGateway(onFetchMe: (_) async => testUser()),
      refreshTokenStore: store,
    );
    addTearDown(controller.dispose);

    final first = controller.signIn(testCredentials());
    await _waitUntil(() => store.operations.contains('write:refresh-a'));
    final signOutFuture = controller.signOut();
    final second = controller.signIn(
      testCredentials(accessToken: 'access-b', refreshToken: 'refresh-b'),
    );
    writeGate.complete();

    expect(await first, SignInOutcome.cancelled);
    await signOutFuture;
    expect(await second, SignInOutcome.signedIn);
    expect(controller.phase, SessionPhase.authenticated);
    expect(controller.accessToken, 'access-b');
    expect(store.token, 'refresh-b');
  });

  test(
    'sessionRevision changes on login and sign-out but not on token rotation',
    () async {
      var refreshCount = 0;
      final gateway = FakeAuthGateway(
        onFetchMe: (_) async => testUser(),
        onRevoke: (_, _) async {},
        onRefresh: (_) async {
          refreshCount++;
          return testTokenPair(
            accessToken: 'access-rotated',
            refreshToken: 'refresh-rotated',
          );
        },
      );
      final store = MemoryRefreshTokenStore();
      final controller = SessionController(
        gateway: gateway,
        refreshTokenStore: store,
      );
      addTearDown(controller.dispose);

      final signedOutRevision = controller.sessionRevision;
      expect(
        await controller.signIn(testCredentials()),
        SignInOutcome.signedIn,
      );
      final signedInRevision = controller.sessionRevision;
      expect(signedInRevision, isNot(signedOutRevision));

      expect(await controller.refreshSession(), SessionRefreshResult.refreshed);
      expect(refreshCount, 1);
      expect(controller.sessionRevision, signedInRevision);
      expect(controller.accessToken, 'access-rotated');

      await controller.signOut();
      expect(controller.sessionRevision, isNot(signedInRevision));
    },
  );

  test('sensitive session objects never reveal tokens in toString', () {
    const credentials = SessionCredentials(
      accessToken: 'secret-access-token',
      refreshToken: 'secret-refresh-token',
      expiresIn: 900,
    );
    final text = credentials.toString();

    expect(text, isNot(contains('secret-access-token')));
    expect(text, isNot(contains('secret-refresh-token')));
    expect(text, contains('redacted'));

    const result = SignOutResult(remoteRevoked: false, message: '未确认');
    expect(result.toString(), isNot(contains('secret')));
  });

  test('the session layer does not print tokens', () {
    final files = Directory(
      'lib/core/auth',
    ).listSync(recursive: true).whereType<File>().toList();

    expect(files, isNotEmpty);
    for (final file in files) {
      final source = file.readAsStringSync();
      expect(RegExp(r'\bprint\(').hasMatch(source), isFalse, reason: file.path);
      expect(source.contains('debugPrint('), isFalse, reason: file.path);
    }
  });
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    if (predicate()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('condition was not met before the timeout');
}

class _FlakyAuthGateway implements AuthGateway {
  _FlakyAuthGateway(this._delegate);

  final AuthGateway _delegate;
  int refreshFailuresRemaining = 0;

  @override
  Future<TokenPair> refresh(String refreshToken) {
    if (refreshFailuresRemaining > 0) {
      refreshFailuresRemaining--;
      throw http.ClientException('network unavailable');
    }
    return _delegate.refresh(refreshToken);
  }

  @override
  Future<Me> fetchMe(String accessToken) => _delegate.fetchMe(accessToken);

  @override
  Future<void> revoke({
    required String accessToken,
    required String refreshToken,
  }) {
    return _delegate.revoke(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
}
