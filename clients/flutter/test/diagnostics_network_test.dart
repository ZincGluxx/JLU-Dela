import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jlu_dela/core/api/api_failure.dart';
import 'package:jlu_dela/core/api/diagnostics_service.dart';

void main() {
  late HttpServer server;

  DiagnosticsService serviceFor(Uri baseUri) {
    return DiagnosticsService(
      apiBaseUri: baseUri,
      httpClient: http.Client(),
      clientVersionLoader: () async => '0.1.0+test',
      timeout: const Duration(seconds: 2),
    );
  }

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final response = request.response;
      response.headers.contentType = ContentType.json;
      response.write(switch (request.uri.path) {
        '/health/live' => _fixture('health_live.success.json'),
        '/health/ready' => _fixture('health_ready.success.json'),
        '/api/v1/meta' => _fixture('meta.success.json'),
        _ =>
          '{"error":{"code":"NOT_FOUND","message":"not found",'
              '"request_id":"test","retryable":false,"fields":[]}}',
      });
      if (!const {
        '/health/live',
        '/health/ready',
        '/api/v1/meta',
      }.contains(request.uri.path)) {
        response.statusCode = 404;
      }
      await response.close();
    });
  });

  tearDown(() => server.close(force: true));

  test(
    'checks the real loopback endpoints through the generated client',
    () async {
      final report = await serviceFor(
        Uri.parse('http://127.0.0.1:${server.port}'),
      ).check();

      expect(report.clientVersion, '0.1.0+test');
      expect(report.meta.data.buildId, 'fixture-build');
      expect(report.database.ready, isTrue);
      expect(report.database.schemaVersion, '1');
    },
  );

  test('reports a network failure when the connection is dropped', () async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    socket.listen((client) => client.destroy());

    await expectLater(
      serviceFor(Uri.parse('http://127.0.0.1:${socket.port}')).check(),
      throwsA(
        isA<ApiFailure>().having(
          (failure) => failure.kind,
          'kind',
          ApiFailureKind.network,
        ),
      ),
    );
    await socket.close();
  });
}

String _fixture(String name) {
  return File('../../contracts/fixtures/$name').readAsStringSync();
}
