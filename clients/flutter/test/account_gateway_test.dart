import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/api/api_failure.dart';
import 'package:jlu_dela/core/auth/account_gateway.dart';
import 'package:jlu_dela/core/auth/session_models.dart';

import 'support/test_http_server.dart';

void main() {
  test('activate posts the invitation and maps the token pair', () async {
    final server = await TestHttpServer.start((request, raw) async {
      await jsonResponse(
        raw,
        tokenPairBody('access-activate', 'refresh-activate', expiresIn: 600),
      );
    });
    addTearDown(server.close);
    final gateway = HttpAccountGateway(baseUri: server.baseUri);

    final credentials = await gateway.activate(
      inviteToken: 'inv-flow-token',
      password: 'E2e-Flow-Password-2026',
    );

    expect(credentials.accessToken, 'access-activate');
    expect(credentials.refreshToken, 'refresh-activate');
    expect(credentials.expiresIn, 600);
    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/api/v1/auth/activate');
    expect(request.headers['content-type'], contains('application/json'));
    expect(jsonDecode(request.body), {
      'invite_token': 'inv-flow-token',
      'password': 'E2e-Flow-Password-2026',
    });
  });

  test('login posts the credentials and maps the token pair', () async {
    final server = await TestHttpServer.start((request, raw) async {
      await jsonResponse(raw, tokenPairBody('access-login', 'refresh-login'));
    });
    addTearDown(server.close);
    final gateway = HttpAccountGateway(baseUri: server.baseUri);

    final credentials = await gateway.login(
      login: 'e2e.user',
      password: 'E2e-Flow-Password-2026',
    );

    expect(credentials.accessToken, 'access-login');
    expect(credentials.refreshToken, 'refresh-login');
    final request = server.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/api/v1/auth/login');
    expect(jsonDecode(request.body), {
      'login': 'e2e.user',
      'password': 'E2e-Flow-Password-2026',
    });
  });

  test('maps a rejected credential to INVALID_CREDENTIALS', () async {
    final server = await TestHttpServer.start((request, raw) async {
      await jsonResponse(raw, errorBody('INVALID_CREDENTIALS'), status: 401);
    });
    addTearDown(server.close);
    final gateway = HttpAccountGateway(baseUri: server.baseUri);

    await expectLater(
      gateway.login(login: 'e2e.user', password: 'wrong-password-2026'),
      throwsA(
        isA<ApiFailure>()
            .having((failure) => failure.code, 'code', 'INVALID_CREDENTIALS')
            .having((failure) => failure.statusCode, 'status', 401)
            .having((failure) => failure.kind, 'kind', ApiFailureKind.server),
      ),
    );
  });

  test('maps a rejected invitation to INVALID_INVITE', () async {
    final server = await TestHttpServer.start((request, raw) async {
      await jsonResponse(raw, errorBody('INVALID_INVITE'), status: 401);
    });
    addTearDown(server.close);
    final gateway = HttpAccountGateway(baseUri: server.baseUri);

    await expectLater(
      gateway.activate(
        inviteToken: 'inv-expired',
        password: 'E2e-Flow-Password-2026',
      ),
      throwsA(
        isA<ApiFailure>()
            .having((failure) => failure.code, 'code', 'INVALID_INVITE')
            .having((failure) => failure.statusCode, 'status', 401),
      ),
    );
  });

  test('reads Retry-After seconds from a RATE_LIMITED response', () async {
    final server = await TestHttpServer.start((request, raw) async {
      raw.response.headers.set('Retry-After', '37');
      await jsonResponse(raw, errorBody('RATE_LIMITED'), status: 429);
    });
    addTearDown(server.close);
    final gateway = HttpAccountGateway(baseUri: server.baseUri);

    await expectLater(
      gateway.login(login: 'e2e.user', password: 'wrong-password-2026'),
      throwsA(
        isA<ApiFailure>()
            .having((failure) => failure.code, 'code', 'RATE_LIMITED')
            .having((failure) => failure.statusCode, 'status', 429)
            .having(
              (failure) => failure.retryAfter,
              'retryAfter',
              const Duration(seconds: 37),
            ),
      ),
    );
  });

  test('maps a refused connection to a network failure', () async {
    final server = await TestHttpServer.start((request, raw) async {
      await jsonResponse(raw, tokenPairBody('access', 'refresh'));
    });
    final baseUri = server.baseUri;
    await server.close();
    final gateway = HttpAccountGateway(baseUri: baseUri);

    await expectLater(
      gateway.login(login: 'e2e.user', password: 'E2e-Flow-Password-2026'),
      throwsA(
        isA<ApiFailure>().having(
          (failure) => failure.kind,
          'kind',
          ApiFailureKind.network,
        ),
      ),
    );
  });

  test('session credentials and failures redact submitted secrets', () async {
    const credentials = SessionCredentials(
      accessToken: 'access-secret-value',
      refreshToken: 'refresh-secret-value',
      expiresIn: 600,
    );
    expect(credentials.toString(), isNot(contains('access-secret-value')));
    expect(credentials.toString(), isNot(contains('refresh-secret-value')));

    const password = 'E2e-Flow-Password-2026';
    final server = await TestHttpServer.start((request, raw) async {
      await jsonResponse(raw, errorBody('INVALID_CREDENTIALS'), status: 401);
    });
    addTearDown(server.close);
    final gateway = HttpAccountGateway(baseUri: server.baseUri);

    try {
      await gateway.login(login: 'e2e.user', password: password);
      fail('The login request should be rejected.');
    } on ApiFailure catch (failure) {
      expect(failure.toString(), isNot(contains(password)));
      expect(failure.technicalMessage, isNot(contains(password)));
    }
    expect(gateway.toString(), isNot(contains(password)));
  });
}
