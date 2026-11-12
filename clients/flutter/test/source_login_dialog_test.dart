import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/campus_source_policy.dart';
import 'package:jlu_dela/core/source/source_login_dialog.dart';
import 'package:jlu_dela/core/source/source_session.dart';

import 'source_fakes.dart';

SourceCookie _cookie({String name = 'CASTGC', String value = 'test-ticket'}) {
  return SourceCookie(
    name: name,
    value: value,
    domain: '.jlu.edu.cn',
    secure: true,
    httpOnly: true,
  );
}

Future<Future<SourceLoginCapture?>> _openDialog(
  WidgetTester tester, {
  required FakeSourceWebView webView,
  SourceKind source = SourceKind.jluIedu,
}) async {
  late Future<SourceLoginCapture?> future;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            future = showSourceLoginDialog(
              context,
              source: source,
              webView: webView,
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump();
  return future;
}

void main() {
  testWidgets('captures cookies after the user confirms the login', (
    tester,
  ) async {
    final webView = FakeSourceWebView(
      controller: FakeSourceWebViewController(cookies: [_cookie()]),
    );
    final future = await _openDialog(tester, webView: webView);

    expect(
      webView.initialUri,
      CampusSourceEndpoints.forSource(SourceKind.jluIedu).loginEntryUri,
    );
    await tester.tap(find.byKey(const Key('source-login-confirm')));
    await tester.pumpAndSettle();

    final capture = await future;
    expect(capture, isNotNull);
    expect(capture!.cookies.single.name, 'CASTGC');
    expect(webView.controller.calls, contains('readCookies'));
  });

  testWidgets('cancel closes the dialog and clears page cookies', (
    tester,
  ) async {
    final webView = FakeSourceWebView();
    final future = await _openDialog(tester, webView: webView);

    await tester.tap(find.byKey(const Key('source-login-cancel')));
    await tester.pumpAndSettle();

    expect(await future, isNull);
    expect(webView.controller.clearCalls, 1);
  });

  testWidgets('keeps the dialog open when no cookie can be read', (
    tester,
  ) async {
    final webView = FakeSourceWebView();
    final future = await _openDialog(tester, webView: webView);

    await tester.tap(find.byKey(const Key('source-login-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('未读取到学校 Cookie，请确认已完成登录后重试'), findsOneWidget);
    expect(find.byKey(const Key('source-login-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('source-login-cancel')));
    await tester.pumpAndSettle();
    expect(await future, isNull);
  });

  testWidgets('reports cookie extraction failures', (tester) async {
    final webView = FakeSourceWebView(
      controller: FakeSourceWebViewController()..failRead = true,
    );
    final future = await _openDialog(tester, webView: webView);

    await tester.tap(find.byKey(const Key('source-login-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('读取来源 Cookie 失败，请重试'), findsOneWidget);

    await tester.tap(find.byKey(const Key('source-login-cancel')));
    await tester.pumpAndSettle();
    await future;
  });

  testWidgets('shows blocked navigation and load errors in the dialog', (
    tester,
  ) async {
    final webView = FakeSourceWebView();
    await _openDialog(tester, webView: webView);

    webView.emitBlocked('已拦截非学校来源的页面：evil.example');
    await tester.pump();
    expect(find.text('已拦截非学校来源的页面：evil.example'), findsOneWidget);

    webView.emitLoadError('来源网页加载失败，请检查网络或校园网/VPN 后重试');
    await tester.pump();
    expect(find.text('来源网页加载失败，请检查网络或校园网/VPN 后重试'), findsOneWidget);
  });

  testWidgets('uses the Chaoxing login entry', (tester) async {
    final webView = FakeSourceWebView(
      controller: FakeSourceWebViewController(
        cookies: [
          SourceCookie(
            name: 'UID',
            value: 'test-uid',
            domain: '.chaoxing.com',
            secure: true,
          ),
        ],
      ),
    );
    final future = await _openDialog(
      tester,
      webView: webView,
      source: SourceKind.chaoxing,
    );

    expect(
      webView.initialUri,
      CampusSourceEndpoints.forSource(SourceKind.chaoxing).loginEntryUri,
    );
    await tester.tap(find.byKey(const Key('source-login-confirm')));
    await tester.pumpAndSettle();

    final capture = await future;
    expect(capture!.cookies.single.name, 'UID');
  });
}
