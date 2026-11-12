import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/source.dart';
import 'package:jlu_dela/core/source/source_page_opener_impl.dart';
import 'package:jlu_dela/core/source/source_session.dart';

import 'source_fakes.dart';

Future<BuildContext> _pumpHost(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (builderContext) {
          context = builderContext;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return context;
}

void main() {
  testWidgets('writes cookies before loading an allowlisted page', (
    tester,
  ) async {
    final sessions = SourceSessionRegistry()
      ..save(SourceAuthGroup.jluCampus, [
        const SourceCookie(
          name: 'CASTGC',
          value: 'test-ticket',
          domain: '.jlu.edu.cn',
          secure: true,
        ),
      ]);
    final webView = FakeSourceWebView();
    final opener = InAppWebViewSourcePageOpener(
      sessions: sessions,
      webView: webView,
    );
    final context = await _pumpHost(tester);
    final uri = Uri.parse('https://oa.jlu.edu.cn/defaultroot/portal/index.jsp');

    final future = opener.openPage(context, source: SourceKind.jluOa, uri: uri);
    await tester.pump();
    await tester.pump();

    expect(webView.controller.calls, ['setCookies', 'load']);
    expect(webView.controller.setCookieCalls.single.name, 'CASTGC');
    expect(webView.controller.loadedUri, uri);

    await tester.tap(find.byKey(const Key('source-page-close')));
    await tester.pumpAndSettle();
    await future;
  });

  testWidgets('loads the page when no source session exists', (tester) async {
    final webView = FakeSourceWebView();
    final opener = InAppWebViewSourcePageOpener(
      sessions: SourceSessionRegistry(),
      webView: webView,
    );
    final context = await _pumpHost(tester);
    final uri = Uri.parse('https://i.chaoxing.com/base');

    final future = opener.openPage(
      context,
      source: SourceKind.chaoxing,
      uri: uri,
    );
    await tester.pump();
    await tester.pump();

    expect(webView.controller.calls, ['load']);
    expect(webView.controller.setCookieCalls, isEmpty);

    await tester.tap(find.byKey(const Key('source-page-close')));
    await tester.pumpAndSettle();
    await future;
  });

  testWidgets('shows blocked navigation in the page dialog', (tester) async {
    final webView = FakeSourceWebView();
    final opener = InAppWebViewSourcePageOpener(
      sessions: SourceSessionRegistry(),
      webView: webView,
    );
    final context = await _pumpHost(tester);

    final future = opener.openPage(
      context,
      source: SourceKind.chaoxing,
      uri: Uri.parse('https://i.chaoxing.com/base'),
    );
    await tester.pump();
    await tester.pump();

    webView.emitBlocked('已拦截非学校来源的页面：evil.example');
    await tester.pump();
    expect(find.text('已拦截非学校来源的页面：evil.example'), findsOneWidget);

    await tester.tap(find.byKey(const Key('source-page-close')));
    await tester.pumpAndSettle();
    await future;
  });

  testWidgets('rejects pages outside the allowlist', (tester) async {
    final opener = InAppWebViewSourcePageOpener(
      sessions: SourceSessionRegistry(),
      webView: FakeSourceWebView(),
    );
    final context = await _pumpHost(tester);

    await expectLater(
      opener.openPage(
        context,
        source: SourceKind.jluOa,
        uri: Uri.parse('https://evil.example/'),
      ),
      throwsA(
        isA<SourceException>().having(
          (error) => error.failure.code,
          'code',
          SourceErrorCodes.sourceProtocol,
        ),
      ),
    );
    await expectLater(
      opener.openPage(
        context,
        source: SourceKind.jluIedu,
        uri: Uri.parse('http://iedu.jlu.edu.cn/'),
      ),
      throwsA(isA<SourceException>()),
    );
  });

  testWidgets('rejects pages that belong to another source group', (
    tester,
  ) async {
    final opener = InAppWebViewSourcePageOpener(
      sessions: SourceSessionRegistry(),
      webView: FakeSourceWebView(),
    );
    final context = await _pumpHost(tester);

    await expectLater(
      opener.openPage(
        context,
        source: SourceKind.jluIedu,
        uri: Uri.parse('https://i.chaoxing.com/base'),
      ),
      throwsA(
        isA<SourceException>().having(
          (error) => error.failure.code,
          'code',
          SourceErrorCodes.sourceProtocol,
        ),
      ),
    );
  });
}
