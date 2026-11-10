import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlu_dela/app/app.dart';
import 'package:jlu_dela/core/api/diagnostics_service.dart';

void main() {
  late List<http.Request> requests;

  setUp(() {
    requests = [];
  });

  DiagnosticsService serviceFor(MockClient client) {
    return DiagnosticsService(
      apiBaseUri: Uri.parse('http://127.0.0.1:8080'),
      httpClient: client,
      clientVersionLoader: () async => '0.1.0+1',
      timeout: const Duration(seconds: 2),
    );
  }

  MockClient successClient({bool databaseReady = true}) {
    return MockClient((request) async {
      requests.add(request);
      return switch (request.url.path) {
        '/health/live' => _jsonResponse('health_live.success.json'),
        '/health/ready' =>
          databaseReady
              ? _jsonResponse('health_ready.success.json')
              : _jsonResponse('health_ready.unavailable.json', statusCode: 503),
        '/api/v1/meta' => _jsonResponse('meta.success.json'),
        _ => http.Response('unexpected path', 404),
      };
    });
  }

  testWidgets('shows loading, then real server and database status', (
    tester,
  ) async {
    final client = MockClient((request) async {
      requests.add(request);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return switch (request.url.path) {
        '/health/live' => _jsonResponse('health_live.success.json'),
        '/health/ready' => _jsonResponse('health_ready.success.json'),
        '/api/v1/meta' => _jsonResponse('meta.success.json'),
        _ => http.Response('unexpected path', 404),
      };
    });

    await tester.pumpWidget(JluDelaApp(diagnosticsService: serviceFor(client)));

    expect(find.byKey(const Key('diagnostics-loading')), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('diagnostics-report')), findsOneWidget);
    expect(find.textContaining('服务与数据库均正常'), findsOneWidget);
    expect(find.text('0.1.0+1'), findsOneWidget);
    expect(find.textContaining('build fixture-build'), findsOneWidget);
    expect(requests.map((request) => request.url.path), [
      '/health/live',
      '/api/v1/meta',
      '/health/ready',
    ]);
  });

  testWidgets('keeps the service connected when the database is not ready', (
    tester,
  ) async {
    await tester.pumpWidget(
      JluDelaApp(
        diagnosticsService: serviceFor(successClient(databaseReady: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('diagnostics-report')), findsOneWidget);
    expect(find.textContaining('服务在线，数据库未就绪'), findsOneWidget);
    expect(find.textContaining('数据库暂不可用'), findsWidgets);
  });

  testWidgets('shows a failure and retries the real requests', (tester) async {
    var failLive = true;
    final client = MockClient((request) async {
      requests.add(request);
      if (failLive && request.url.path == '/health/live') {
        throw const SocketException('connection refused');
      }
      return switch (request.url.path) {
        '/health/live' => _jsonResponse('health_live.success.json'),
        '/health/ready' => _jsonResponse('health_ready.success.json'),
        '/api/v1/meta' => _jsonResponse('meta.success.json'),
        _ => http.Response('unexpected path', 404),
      };
    });

    await tester.pumpWidget(JluDelaApp(diagnosticsService: serviceFor(client)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('diagnostics-error')), findsOneWidget);
    expect(find.textContaining('无法连接服务'), findsOneWidget);

    failLive = false;
    await tester.tap(find.byKey(const Key('diagnostics-retry')));
    await tester.pump();
    expect(find.byKey(const Key('diagnostics-loading')), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('diagnostics-report')), findsOneWidget);
    expect(requests.length, greaterThanOrEqualTo(4));
  });

  testWidgets('uses the compact layout on narrow screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(640, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      JluDelaApp(diagnosticsService: serviceFor(successClient())),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('工程底座诊断'), findsOneWidget);
    expect(find.textContaining('真实服务连接与环境验收'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the desktop layout on wide screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      JluDelaApp(diagnosticsService: serviceFor(successClient())),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('真实服务连接与环境验收'), findsOneWidget);
    expect(find.textContaining('工程底座诊断'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

http.Response _jsonResponse(String fixture, {int statusCode = 200}) {
  return http.Response(
    File('../../contracts/fixtures/$fixture').readAsStringSync(),
    statusCode,
    headers: const {'content-type': 'application/json'},
  );
}
