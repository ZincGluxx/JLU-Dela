import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jlu_dela/core/auth/auth_gateway.dart';
import 'package:jlu_dela/core/auth/session_controller.dart';
import 'package:jlu_dela/core/auth/session_http_client.dart';
import 'package:jlu_dela/core/auth/session_models.dart';
import 'package:jlu_dela_api/api.dart';

import 'support/session_test_support.dart';
import 'support/test_http_server.dart';

void main() {
  Future<SessionController> signIn(
    TestHttpServer server,
    MemoryRefreshTokenStore store,
  ) async {
    final controller = SessionController(
      gateway: HttpAuthGateway(baseUri: server.baseUri),
      refreshTokenStore: store,
    );
    await controller.signIn(testCredentials());
    server.requests.clear();
    return controller;
  }

  test('attaches the bearer token only to the configured origin', () async {
    final server = await TestHttpServer.start((request, raw) async {
      if (request.path == '/api/v1/me') {
        await jsonResponse(raw, meBody());
      } else {
        await jsonResponse(raw, <String, Object>{});
      }
    });
    addTearDown(server.close);
    final other = await TestHttpServer.start((request, raw) async {
      await jsonResponse(raw, <String, Object>{});
    });
    addTearDown(other.close);

    final store = MemoryRefreshTokenStore();
    final controller = await signIn(server, store);
    addTearDown(controller.dispose);
    final client = SessionHttpClient(
      baseUri: server.baseUri,
      session: controller,
    );
    addTearDown(client.close);

    final workbench = await client.get(
      Uri.parse('${server.baseUri}/api/v1/todos'),
    );
    final outside = await client.get(
      Uri.parse('${other.baseUri}/api/v1/todos'),
    );

    expect(workbench.statusCode, 200);
    expect(outside.statusCode, 200);
    expect(server.requests.single.authorization, 'Bearer access-a');
    expect(other.requests.single.authorization, isNull);
  });

  test('shares one refresh across concurrent expired requests', () async {
    final bothExpired = Completer<void>();
    var refreshCount = 0;
    var expiredCount = 0;
    var todosCount = 0;
    final server = await TestHttpServer.start((request, raw) async {
      if (request.path == '/api/v1/me') {
        await jsonResponse(raw, meBody());
        return;
      }
      if (request.path == '/api/v1/auth/refresh') {
        refreshCount++;
        await bothExpired.future;
        await jsonResponse(raw, tokenPairBody('access-b', 'refresh-b'));
        return;
      }
      if (request.path == '/api/v1/todos') {
        todosCount++;
        if (request.authorization == 'Bearer access-b') {
          await jsonResponse(raw, {'data': <Object>[]});
          return;
        }
        expiredCount++;
        if (expiredCount == 2) {
          bothExpired.complete();
        }
        await jsonResponse(raw, errorBody('TOKEN_EXPIRED'), status: 401);
        return;
      }
      await jsonResponse(raw, errorBody('NOT_FOUND'), status: 404);
    });
    addTearDown(server.close);

    final store = MemoryRefreshTokenStore();
    final controller = await signIn(server, store);
    addTearDown(controller.dispose);
    final client = SessionHttpClient(
      baseUri: server.baseUri,
      session: controller,
    );
    addTearDown(client.close);
    final todosUri = Uri.parse('${server.baseUri}/api/v1/todos');

    final responses = await Future.wait([
      client.get(todosUri),
      client.get(todosUri),
    ]);

    expect(responses.map((response) => response.statusCode), [200, 200]);
    expect(refreshCount, 1);
    expect(expiredCount, 2);
    expect(todosCount, 4);
    expect(controller.accessToken, 'access-b');
    expect(store.token, 'refresh-b');
    expect(controller.phase, SessionPhase.authenticated);
  });

  test(
    'does not refresh again when the retried request is also expired',
    () async {
      var refreshCount = 0;
      var todosCount = 0;
      final server = await TestHttpServer.start((request, raw) async {
        if (request.path == '/api/v1/me') {
          await jsonResponse(raw, meBody());
          return;
        }
        if (request.path == '/api/v1/auth/refresh') {
          refreshCount++;
          await jsonResponse(raw, tokenPairBody('access-b', 'refresh-b'));
          return;
        }
        if (request.path == '/api/v1/todos') {
          todosCount++;
          await jsonResponse(raw, errorBody('TOKEN_EXPIRED'), status: 401);
          return;
        }
        await jsonResponse(raw, errorBody('NOT_FOUND'), status: 404);
      });
      addTearDown(server.close);

      final store = MemoryRefreshTokenStore();
      final controller = await signIn(server, store);
      addTearDown(controller.dispose);
      final client = SessionHttpClient(
        baseUri: server.baseUri,
        session: controller,
      );
      addTearDown(client.close);

      final response = await client.get(
        Uri.parse('${server.baseUri}/api/v1/todos'),
      );

      expect(response.statusCode, 401);
      expect(refreshCount, 1);
      expect(todosCount, 2);
      expect(controller.accessToken, 'access-b');
    },
  );

  test('does not replay an unkeyed POST after refreshing', () async {
    var refreshCount = 0;
    var postCount = 0;
    final server = await TestHttpServer.start((request, raw) async {
      if (request.path == '/api/v1/me') {
        await jsonResponse(raw, meBody());
        return;
      }
      if (request.path == '/api/v1/auth/refresh') {
        refreshCount++;
        await jsonResponse(raw, tokenPairBody('access-b', 'refresh-b'));
        return;
      }
      if (request.path == '/api/v1/todos' && request.method == 'POST') {
        postCount++;
        await jsonResponse(raw, errorBody('TOKEN_EXPIRED'), status: 401);
        return;
      }
      await jsonResponse(raw, errorBody('NOT_FOUND'), status: 404);
    });
    addTearDown(server.close);

    final store = MemoryRefreshTokenStore();
    final controller = await signIn(server, store);
    addTearDown(controller.dispose);
    final client = SessionHttpClient(
      baseUri: server.baseUri,
      session: controller,
    );
    addTearDown(client.close);

    final response = await client.post(
      Uri.parse('${server.baseUri}/api/v1/todos'),
      headers: {'Content-Type': 'application/json'},
      body: '{"title":"todo"}',
    );

    expect(response.statusCode, 401);
    expect(refreshCount, 1);
    expect(postCount, 1);
    expect(store.token, 'refresh-b');
  });

  test('replays a POST that carries an idempotency key once', () async {
    var refreshCount = 0;
    var postCount = 0;
    final server = await TestHttpServer.start((request, raw) async {
      if (request.path == '/api/v1/me') {
        await jsonResponse(raw, meBody());
        return;
      }
      if (request.path == '/api/v1/auth/refresh') {
        refreshCount++;
        await jsonResponse(raw, tokenPairBody('access-b', 'refresh-b'));
        return;
      }
      if (request.path == '/api/v1/todos' && request.method == 'POST') {
        postCount++;
        if (request.authorization == 'Bearer access-b') {
          await jsonResponse(raw, {'data': <String, Object>{}}, status: 201);
        } else {
          await jsonResponse(raw, errorBody('TOKEN_EXPIRED'), status: 401);
        }
        return;
      }
      await jsonResponse(raw, errorBody('NOT_FOUND'), status: 404);
    });
    addTearDown(server.close);

    final store = MemoryRefreshTokenStore();
    final controller = await signIn(server, store);
    addTearDown(controller.dispose);
    final client = SessionHttpClient(
      baseUri: server.baseUri,
      session: controller,
    );
    addTearDown(client.close);

    final response = await client.post(
      Uri.parse('${server.baseUri}/api/v1/todos'),
      headers: {'Content-Type': 'application/json', 'Idempotency-Key': 'key-1'},
      body: '{"title":"todo"}',
    );

    expect(response.statusCode, 201);
    expect(refreshCount, 1);
    expect(postCount, 2);
    final posts = server.requests
        .where((request) => request.path == '/api/v1/todos')
        .toList();
    expect(posts.last.headers['idempotency-key'], 'key-1');
    expect(posts.last.authorization, 'Bearer access-b');
    expect(posts.last.body, posts.first.body);
  });

  test('never refreshes or retries the auth endpoints', () async {
    var refreshPathCount = 0;
    var logoutPathCount = 0;
    final server = await TestHttpServer.start((request, raw) async {
      if (request.path == '/api/v1/me') {
        await jsonResponse(raw, meBody());
        return;
      }
      if (request.path == '/api/v1/auth/refresh') {
        refreshPathCount++;
        await jsonResponse(raw, errorBody('TOKEN_EXPIRED'), status: 401);
        return;
      }
      if (request.path == '/api/v1/auth/logout') {
        logoutPathCount++;
        await jsonResponse(raw, errorBody('TOKEN_EXPIRED'), status: 401);
        return;
      }
      await jsonResponse(raw, errorBody('NOT_FOUND'), status: 404);
    });
    addTearDown(server.close);

    final store = MemoryRefreshTokenStore();
    final controller = await signIn(server, store);
    addTearDown(controller.dispose);
    final client = SessionHttpClient(
      baseUri: server.baseUri,
      session: controller,
    );
    addTearDown(client.close);

    final refreshResponse = await client.post(
      Uri.parse('${server.baseUri}/api/v1/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: '{"refresh_token":"refresh-a"}',
    );
    final logoutResponse = await client.post(
      Uri.parse('${server.baseUri}/api/v1/auth/logout'),
      headers: {'Content-Type': 'application/json'},
      body: '{"refresh_token":"refresh-a"}',
    );

    expect(refreshResponse.statusCode, 401);
    expect(logoutResponse.statusCode, 401);
    expect(refreshPathCount, 1);
    expect(logoutPathCount, 1);
    expect(controller.accessToken, 'access-a');
    expect(controller.phase, SessionPhase.authenticated);
  });

  test('signs out on invalid token codes', () async {
    var invalidCode = 'INVALID_TOKEN';
    var refreshCount = 0;
    final server = await TestHttpServer.start((request, raw) async {
      if (request.path == '/api/v1/me') {
        await jsonResponse(raw, meBody());
        return;
      }
      if (request.path == '/api/v1/auth/refresh') {
        refreshCount++;
        await jsonResponse(raw, tokenPairBody('access-b', 'refresh-b'));
        return;
      }
      await jsonResponse(raw, errorBody(invalidCode), status: 401);
    });
    addTearDown(server.close);

    for (final code in ['INVALID_TOKEN', 'SESSION_REVOKED', 'AUTH_REQUIRED']) {
      invalidCode = code;
      final store = MemoryRefreshTokenStore();
      final controller = await signIn(server, store);
      final client = SessionHttpClient(
        baseUri: server.baseUri,
        session: controller,
      );

      final response = await client.get(
        Uri.parse('${server.baseUri}/api/v1/todos'),
      );

      expect(response.statusCode, 401, reason: code);
      expect(controller.phase, SessionPhase.signedOut, reason: code);
      expect(controller.accessToken, isNull, reason: code);
      expect(store.token, isNull, reason: code);

      client.close();
      controller.dispose();
    }
    expect(refreshCount, 0);
  });

  test('keeps the session on source, server and timeout failures', () async {
    final server = await TestHttpServer.start((request, raw) async {
      if (request.path == '/api/v1/me') {
        await jsonResponse(raw, meBody());
        return;
      }
      if (request.path == '/api/v1/source') {
        await jsonResponse(raw, errorBody('SOURCE_AUTH_REQUIRED'), status: 409);
        return;
      }
      if (request.path == '/api/v1/server') {
        await jsonResponse(raw, errorBody('INTERNAL'), status: 500);
        return;
      }
      await jsonResponse(raw, <String, Object>{});
    });
    addTearDown(server.close);

    final store = MemoryRefreshTokenStore();
    final controller = await signIn(server, store);
    addTearDown(controller.dispose);
    final client = SessionHttpClient(
      baseUri: server.baseUri,
      session: controller,
    );
    addTearDown(client.close);

    final sourceResponse = await client.get(
      Uri.parse('${server.baseUri}/api/v1/source'),
    );
    final serverResponse = await client.get(
      Uri.parse('${server.baseUri}/api/v1/server'),
    );
    final timeoutClient = SessionHttpClient(
      baseUri: server.baseUri,
      session: controller,
      inner: _TimeoutClient(),
    );
    addTearDown(timeoutClient.close);

    await expectLater(
      timeoutClient.get(Uri.parse('${server.baseUri}/api/v1/todos')),
      throwsA(isA<TimeoutException>()),
    );

    expect(sourceResponse.statusCode, 409);
    expect(serverResponse.statusCode, 500);
    expect(controller.phase, SessionPhase.authenticated);
    expect(controller.accessToken, 'access-a');
    expect(store.token, 'refresh-a');
  });

  test(
    'raises a client exception when the refresh fails on the network',
    () async {
      final server = await TestHttpServer.start((request, raw) async {
        if (request.path == '/api/v1/me') {
          await jsonResponse(raw, meBody());
          return;
        }
        await jsonResponse(raw, errorBody('TOKEN_EXPIRED'), status: 401);
      });
      addTearDown(server.close);

      final store = MemoryRefreshTokenStore();
      final gateway = _OfflineRefreshGateway(
        HttpAuthGateway(baseUri: server.baseUri),
      );
      final controller = SessionController(
        gateway: gateway,
        refreshTokenStore: store,
      );
      addTearDown(controller.dispose);
      await controller.signIn(testCredentials());
      final client = SessionHttpClient(
        baseUri: server.baseUri,
        session: controller,
      );
      addTearDown(client.close);

      await expectLater(
        client.get(Uri.parse('${server.baseUri}/api/v1/todos')),
        throwsA(isA<http.ClientException>()),
      );

      expect(controller.phase, SessionPhase.unavailable);
      expect(controller.currentUser?.id, 'user-a');
      expect(store.token, 'refresh-a');
    },
  );

  test(
    'does not sign out when a rotated token fails during an in-flight refresh',
    () async {
      final refreshReceived = Completer<void>();
      final releaseRefresh = Completer<void>();
      final secondUnauthorized = Completer<void>();
      var refreshCount = 0;
      var oldRequestCount = 0;

      final server = await TestHttpServer.start((request, raw) async {
        if (request.path == '/api/v1/me') {
          await jsonResponse(raw, meBody());
          return;
        }
        if (request.path == '/api/v1/auth/refresh') {
          refreshCount++;
          refreshReceived.complete();
          await releaseRefresh.future;
          await jsonResponse(raw, tokenPairBody('access-b', 'refresh-b'));
          return;
        }
        if (request.path == '/api/v1/todos') {
          if (request.authorization == 'Bearer access-b') {
            await jsonResponse(raw, {'data': <Object>[]});
            return;
          }
          oldRequestCount++;
          if (oldRequestCount == 1) {
            await jsonResponse(raw, errorBody('TOKEN_EXPIRED'), status: 401);
          } else {
            await jsonResponse(raw, errorBody('INVALID_TOKEN'), status: 401);
            secondUnauthorized.complete();
          }
          return;
        }
        await jsonResponse(raw, errorBody('NOT_FOUND'), status: 404);
      });
      addTearDown(server.close);

      final store = MemoryRefreshTokenStore();
      final controller = await signIn(server, store);
      addTearDown(controller.dispose);
      final client = SessionHttpClient(
        baseUri: server.baseUri,
        session: controller,
      );
      addTearDown(client.close);
      final todosUri = Uri.parse('${server.baseUri}/api/v1/todos');

      final first = client.get(todosUri);
      await refreshReceived.future;
      final second = client.get(todosUri);
      await secondUnauthorized.future;
      releaseRefresh.complete();
      final responses = await Future.wait([first, second]);

      expect(responses.map((response) => response.statusCode), [200, 200]);
      expect(controller.phase, SessionPhase.authenticated);
      expect(controller.accessToken, 'access-b');
      expect(refreshCount, 1);
    },
  );

  test(
    'does not sign out when an old token reports 401 after a refresh',
    () async {
      for (final staleCode in ['TOKEN_EXPIRED', 'INVALID_TOKEN']) {
        final secondArrived = Completer<void>();
        final releaseStale = Completer<void>();
        var refreshCount = 0;
        var oldRequestCount = 0;

        final server = await TestHttpServer.start((request, raw) async {
          if (request.path == '/api/v1/me') {
            await jsonResponse(raw, meBody());
            return;
          }
          if (request.path == '/api/v1/auth/refresh') {
            refreshCount++;
            await secondArrived.future;
            await jsonResponse(raw, tokenPairBody('access-b', 'refresh-b'));
            return;
          }
          if (request.path == '/api/v1/todos') {
            if (request.authorization == 'Bearer access-b') {
              await jsonResponse(raw, {'data': <Object>[]});
              return;
            }
            oldRequestCount++;
            if (oldRequestCount == 1) {
              await jsonResponse(raw, errorBody('TOKEN_EXPIRED'), status: 401);
            } else {
              secondArrived.complete();
              await releaseStale.future;
              await jsonResponse(raw, errorBody(staleCode), status: 401);
            }
            return;
          }
          await jsonResponse(raw, errorBody('NOT_FOUND'), status: 404);
        });
        addTearDown(server.close);

        final store = MemoryRefreshTokenStore();
        final controller = await signIn(server, store);
        final client = SessionHttpClient(
          baseUri: server.baseUri,
          session: controller,
        );
        final todosUri = Uri.parse('${server.baseUri}/api/v1/todos');

        final first = client.get(todosUri);
        final second = client.get(todosUri);
        await _waitUntil(() => controller.accessToken == 'access-b');
        releaseStale.complete();
        final responses = await Future.wait([first, second]);

        expect(responses.map((response) => response.statusCode), [
          200,
          200,
        ], reason: staleCode);
        expect(controller.phase, SessionPhase.authenticated, reason: staleCode);
        expect(controller.accessToken, 'access-b', reason: staleCode);
        expect(refreshCount, 1, reason: staleCode);

        client.close();
        controller.dispose();
      }
    },
  );
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

class _TimeoutClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return Future<http.StreamedResponse>.error(TimeoutException('timeout'));
  }
}

class _OfflineRefreshGateway implements AuthGateway {
  _OfflineRefreshGateway(this._delegate);

  final AuthGateway _delegate;

  @override
  Future<TokenPair> refresh(String refreshToken) async {
    throw http.ClientException('network unavailable');
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
