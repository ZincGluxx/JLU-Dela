import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/device_campus_login.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/campus_login.dart';
import 'package:jlu_dela/core/source/campus_source_policy.dart';
import 'package:jlu_dela/core/source/source.dart';
import 'package:jlu_dela/core/source/source_session.dart';

import 'source_fakes.dart';

SourceCookie _jluCookie() {
  return const SourceCookie(
    name: 'CASTGC',
    value: 'test-ticket',
    domain: '.jlu.edu.cn',
    secure: true,
    httpOnly: true,
  );
}

SourceCookie _chaoxingCookie() {
  return const SourceCookie(
    name: 'UID',
    value: 'test-uid',
    domain: '.chaoxing.com',
    secure: true,
  );
}

Future<Future<CampusLoginResult>> _openConnect(
  WidgetTester tester,
  DeviceCampusLogin login,
  SourceKind source,
) async {
  late Future<CampusLoginResult> future;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            future = login.connect(context, source);
          },
          child: const Text('connect'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('connect'));
  await tester.pump();
  await tester.pump();
  return future;
}

void main() {
  testWidgets('connects after the probe confirms the session', (tester) async {
    final sessions = SourceSessionRegistry();
    final webView = FakeSourceWebView(
      controller: FakeSourceWebViewController(cookies: [_jluCookie()]),
    );
    final http = StubSourceHttpClient();
    final login = DeviceCampusLogin(
      sessions: sessions,
      http: http,
      webView: webView,
    );

    final future = await _openConnect(tester, login, SourceKind.jluIedu);
    await tester.tap(find.byKey(const Key('source-login-confirm')));
    await tester.pumpAndSettle();
    final result = await future;

    expect(result.connected, isTrue);
    expect(
      sessions.stateFor(SourceKind.jluIedu),
      SourceConnectionState.connected,
    );
    expect(
      sessions.stateFor(SourceKind.jluOa),
      SourceConnectionState.connected,
    );
    expect(
      http.requests.single.uri,
      CampusSourceEndpoints.forSource(SourceKind.jluIedu).probeUri,
    );
    expect(http.requests.single.timeout, const Duration(seconds: 30));
  });

  for (final source in SourceKind.values) {
    testWidgets('opens and probes the selected ${source.name} source', (
      tester,
    ) async {
      final endpoints = CampusSourceEndpoints.forSource(source);
      final webView = FakeSourceWebView(
        controller: FakeSourceWebViewController(
          cookies: [
            source == SourceKind.chaoxing ? _chaoxingCookie() : _jluCookie(),
          ],
        ),
      );
      final http = StubSourceHttpClient();
      final login = DeviceCampusLogin(
        sessions: SourceSessionRegistry(),
        http: http,
        webView: webView,
      );

      final future = await _openConnect(tester, login, source);
      expect(webView.initialUri, endpoints.loginEntryUri);
      await tester.tap(find.byKey(const Key('source-login-confirm')));
      await tester.pumpAndSettle();

      expect((await future).connected, isTrue);
      expect(http.requests.single.uri, endpoints.probeUri);
    });
  }

  testWidgets('saves Chaoxing cookies in their own group', (tester) async {
    final sessions = SourceSessionRegistry();
    final login = DeviceCampusLogin(
      sessions: sessions,
      http: StubSourceHttpClient(),
      webView: FakeSourceWebView(
        controller: FakeSourceWebViewController(cookies: [_chaoxingCookie()]),
      ),
    );

    final future = await _openConnect(tester, login, SourceKind.chaoxing);
    await tester.tap(find.byKey(const Key('source-login-confirm')));
    await tester.pumpAndSettle();
    final result = await future;

    expect(result.connected, isTrue);
    expect(
      sessions
          .cookiesForUri(
            SourceKind.chaoxing,
            Uri.parse('https://i.chaoxing.com/base'),
          )
          .single
          .name,
      'UID',
    );
    expect(sessions.hasSession(SourceKind.jluIedu), isFalse);
  });

  testWidgets('clears the group when the probe requires authentication', (
    tester,
  ) async {
    final sessions = SourceSessionRegistry()
      ..save(SourceAuthGroup.jluCampus, [_jluCookie()]);
    final http = StubSourceHttpClient(
      onSend: (request) async {
        throw const SourceException(
          SourceFailure(
            code: SourceErrorCodes.sourceAuthRequired,
            message: '教务系统登录已失效，请重新登录来源',
          ),
        );
      },
    );
    final login = DeviceCampusLogin(
      sessions: sessions,
      http: http,
      webView: FakeSourceWebView(
        controller: FakeSourceWebViewController(cookies: [_jluCookie()]),
      ),
    );

    final future = await _openConnect(tester, login, SourceKind.jluIedu);
    await tester.tap(find.byKey(const Key('source-login-confirm')));
    await tester.pumpAndSettle();
    final result = await future;

    expect(result.connected, isFalse);
    expect(result.message, '未能确认教务系统登录状态，请完成学校登录后重试');
    expect(sessions.hasSession(SourceKind.jluIedu), isFalse);
  });

  testWidgets('clears the group when the probe responds with a login page', (
    tester,
  ) async {
    final sessions = SourceSessionRegistry();
    final endpoints = CampusSourceEndpoints.forSource(SourceKind.jluIedu);
    final http = StubSourceHttpClient(
      onSend: (request) async => SourceResponse(
        statusCode: 200,
        body: '<form id="loginForm"></form>',
        finalUri: endpoints.probeUri,
      ),
    );
    final login = DeviceCampusLogin(
      sessions: sessions,
      http: http,
      webView: FakeSourceWebView(
        controller: FakeSourceWebViewController(cookies: [_jluCookie()]),
      ),
    );

    final future = await _openConnect(tester, login, SourceKind.jluIedu);
    await tester.tap(find.byKey(const Key('source-login-confirm')));
    await tester.pumpAndSettle();
    final result = await future;

    expect(result.connected, isFalse);
    expect(result.message, '未能确认教务系统登录状态，请完成学校登录后重试');
    expect(sessions.hasSession(SourceKind.jluIedu), isFalse);
  });

  testWidgets('surfaces network probe failures without caching a session', (
    tester,
  ) async {
    final sessions = SourceSessionRegistry();
    final http = StubSourceHttpClient(
      onSend: (request) async {
        throw const SourceException(
          SourceFailure(
            code: SourceErrorCodes.sourceNetwork,
            message: '无法连接来源服务，请检查网络或校园网/VPN',
            retryable: true,
          ),
        );
      },
    );
    final login = DeviceCampusLogin(
      sessions: sessions,
      http: http,
      webView: FakeSourceWebView(
        controller: FakeSourceWebViewController(cookies: [_jluCookie()]),
      ),
    );

    final future = await _openConnect(tester, login, SourceKind.jluIedu);
    await tester.tap(find.byKey(const Key('source-login-confirm')));
    await tester.pumpAndSettle();
    final result = await future;

    expect(result.connected, isFalse);
    expect(result.message, '无法连接来源服务，请检查网络或校园网/VPN');
    expect(sessions.hasSession(SourceKind.jluIedu), isFalse);
  });

  testWidgets('cancelling the dialog leaves the session untouched', (
    tester,
  ) async {
    final sessions = SourceSessionRegistry();
    final http = StubSourceHttpClient();
    final login = DeviceCampusLogin(
      sessions: sessions,
      http: http,
      webView: FakeSourceWebView(),
    );

    final future = await _openConnect(tester, login, SourceKind.jluIedu);
    await tester.tap(find.byKey(const Key('source-login-cancel')));
    await tester.pumpAndSettle();
    final result = await future;

    expect(result.connected, isFalse);
    expect(result.message, '已取消来源登录');
    expect(http.requests, isEmpty);
    expect(sessions.hasSession(SourceKind.jluIedu), isFalse);
  });
}
