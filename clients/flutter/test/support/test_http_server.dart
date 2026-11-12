import 'dart:convert';
import 'dart:io';

class RecordedHttpRequest {
  RecordedHttpRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.headers,
    required this.body,
  });

  final String method;
  final String path;
  final String query;
  final Map<String, String> headers;
  final String body;

  String? get authorization => headers['authorization'];
}

typedef TestRequestHandler =
    Future<void> Function(RecordedHttpRequest request, HttpRequest raw);

class TestHttpServer {
  TestHttpServer._(this._server);

  final HttpServer _server;
  final List<RecordedHttpRequest> requests = [];

  static Future<TestHttpServer> start(TestRequestHandler handler) async {
    final server = TestHttpServer._(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    server._server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      final headers = <String, String>{};
      request.headers.forEach((name, values) {
        headers[name.toLowerCase()] = values.join(',');
      });
      final recorded = RecordedHttpRequest(
        method: request.method,
        path: request.uri.path,
        query: request.uri.query,
        headers: headers,
        body: body,
      );
      server.requests.add(recorded);
      await handler(recorded, request);
    });
    return server;
  }

  Uri get baseUri => Uri.parse('http://127.0.0.1:${_server.port}');

  Future<void> close() => _server.close(force: true);
}

Future<void> jsonResponse(
  HttpRequest request,
  Object body, {
  int status = 200,
}) async {
  request.response.statusCode = status;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
  await request.response.close();
}

Future<void> emptyResponse(HttpRequest request, {int status = 204}) async {
  request.response.statusCode = status;
  await request.response.close();
}

Map<String, dynamic> tokenPairBody(
  String accessToken,
  String refreshToken, {
  int expiresIn = 900,
}) {
  return {
    'data': {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': 'Bearer',
      'expires_in': expiresIn,
    },
    'meta': {'request_id': 'test'},
  };
}

Map<String, dynamic> meBody({
  String id = 'user-a',
  String displayName = '测试用户',
}) {
  return {
    'data': {
      'id': id,
      'display_name': displayName,
      'timezone': 'Asia/Shanghai',
    },
    'meta': {'request_id': 'test'},
  };
}

Map<String, dynamic> errorBody(String code, {String? message}) {
  return {
    'error': {
      'code': code,
      'message': message ?? code,
      'request_id': 'test',
      'retryable': false,
      'fields': <Object>[],
    },
  };
}
