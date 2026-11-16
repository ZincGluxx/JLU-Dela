import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/device_campus_login.dart';
import 'package:jlu_dela/core/auth/session_controller.dart';
import 'package:jlu_dela/core/auth/session_scope.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/campus_login.dart';
import 'package:jlu_dela/core/source/source.dart';
import 'package:jlu_dela/core/source/source_page_opener_impl.dart';
import 'package:jlu_dela/core/source/source_session.dart';

import 'source_fakes.dart';
import 'support/session_test_support.dart';

const _cookieA = SourceCookie(
  name: 'UID',
  value: 'source-user-a',
  domain: '.chaoxing.com',
  secure: true,
);
const _cookieB = SourceCookie(
  name: 'UID',
  value: 'source-user-b',
  domain: '.chaoxing.com',
  secure: true,
);
final _sourceUri = Uri.parse('https://i.chaoxing.com/base');

class _DelayedCookieRead extends FakeSourceWebViewController {
  final result = Completer<List<SourceCookie>>();
  final started = Completer<void>();

  @override
  Future<List<SourceCookie>> readCookies(Iterable<Uri> uris) async {
    await super.readCookies(uris);
    started.complete();
    return result.future;
  }
}

class _DelayedCookieWrite extends FakeSourceWebViewController {
  final release = Completer<void>();
  final started = Completer<void>();

  @override
  Future<void> setCookies(Iterable<SourceCookie> cookies) async {
    await super.setCookies(cookies);
    started.complete();
    await release.future;
  }
}

Future<SessionController> _session(SourceSessionRegistry sources) async {
  final session = SessionController(
    gateway: FakeAuthGateway(
      onFetchMe: (token) async =>
          testUser(id: token == 'access-b' ? 'user-b' : 'user-a'),
      onRevoke: (_, _) async {},
    ),
    refreshTokenStore: MemoryRefreshTokenStore(),
  );
  addTearDown(session.dispose);
  session.registerPrivateCache(sources.clearAll);
  await session.signIn(testCredentials());
  return session;
}

Future<void> _changeAccount(
  SessionController session,
  SourceSessionRegistry sources,
  String change,
) async {
  if (change == 'signout') {
    await session.signOut();
  } else {
    await session.signIn(
      testCredentials(accessToken: 'access-b', refreshToken: 'refresh-b'),
    );
    sources.save(SourceAuthGroup.chaoxing, [_cookieB]);
  }
}

void _expectCurrentCookies(SourceSessionRegistry sources, String change) {
  expect(
    sources.cookieHeaderFor(SourceKind.chaoxing, _sourceUri),
    change == 'signout' ? <String, String>{} : {'UID': _cookieB.value},
  );
}

Future<void> _pumpHost(
  WidgetTester tester,
  SessionController session,
  void Function(BuildContext context) onOpen,
) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) =>
          SessionScope(session: session, child: child!),
      home: ListenableBuilder(
        listenable: session,
        builder: (context, _) => Navigator(
          key: ValueKey(
            '${session.currentUser?.id}:${session.sessionRevision}',
          ),
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const Key('open-source'),
                onPressed: () => onOpen(context),
                child: const Text('打开来源'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open-source')));
  await tester.pumpAndSettle();
}

void main() {
  for (final change in ['signout', 'switch-account']) {
    for (final afterFrame in [false, true]) {
      testWidgets(
        '$change during cookie capture cannot save the old source session, disposed: $afterFrame',
        (tester) async {
          final sources = SourceSessionRegistry();
          final session = await _session(sources);
          final controller = _DelayedCookieRead();
          final http = StubSourceHttpClient();
          final login = DeviceCampusLogin(
            sessions: sources,
            http: http,
            webView: FakeSourceWebView(controller: controller),
          );
          late BuildContext openingContext;
          await _pumpHost(tester, session, (context) {
            openingContext = context;
            unawaited(login.connect(context, SourceKind.chaoxing));
          });
          await tester.tap(find.byKey(const Key('source-login-confirm')));
          await tester.pumpAndSettle();
          expect(controller.started.isCompleted, isTrue);

          await _changeAccount(session, sources, change);
          if (afterFrame) await tester.pumpAndSettle();
          expect(openingContext.mounted, !afterFrame);
          controller.result.complete([_cookieA]);
          await tester.pumpAndSettle();

          _expectCurrentCookies(sources, change);
          expect(http.requests, isEmpty);
          expect(
            find.byKey(const Key('source-login-dialog'), skipOffstage: false),
            findsNothing,
          );
          expect(
            find.byKey(const Key('fake-source-webview'), skipOffstage: false),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final outcome in ['success', 'auth-failure', 'exception']) {
      testWidgets('$change discards an old login probe $outcome', (
        tester,
      ) async {
        final sources = SourceSessionRegistry();
        final session = await _session(sources);
        final probe = Completer<SourceResponse>();
        final http = StubSourceHttpClient(onSend: (_) => probe.future);
        final login = DeviceCampusLogin(
          sessions: sources,
          http: http,
          webView: FakeSourceWebView(
            controller: FakeSourceWebViewController(cookies: [_cookieA]),
          ),
        );
        late BuildContext openingContext;
        late Future<CampusLoginResult> pending;
        await _pumpHost(tester, session, (context) {
          openingContext = context;
          pending = login.connect(context, SourceKind.chaoxing);
        });
        await tester.tap(find.byKey(const Key('source-login-confirm')));
        await tester.pumpAndSettle();
        expect(http.requests, hasLength(1));
        expect(sources.cookieHeaderFor(SourceKind.chaoxing, _sourceUri), {
          'UID': _cookieA.value,
        });

        await _changeAccount(session, sources, change);
        expect(openingContext.mounted, isTrue);
        if (outcome == 'success') {
          probe.complete(
            SourceResponse(statusCode: 200, body: 'ok', finalUri: _sourceUri),
          );
        } else if (outcome == 'auth-failure') {
          probe.completeError(
            const SourceException(
              SourceFailure(
                code: SourceErrorCodes.sourceAuthRequired,
                message: 'old probe needs login',
                source: SourceKind.chaoxing,
              ),
            ),
          );
        } else {
          probe.completeError(Exception('old probe failed'));
        }
        final result = await pending;
        expect(result.connected, isFalse);
        _expectCurrentCookies(sources, change);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    for (final afterFrame in [false, true]) {
      testWidgets(
        '$change during cookie injection cannot load the old page, disposed: $afterFrame',
        (tester) async {
          final sources = SourceSessionRegistry();
          final session = await _session(sources);
          sources.save(SourceAuthGroup.chaoxing, [_cookieA]);
          final controller = _DelayedCookieWrite();
          final opener = InAppWebViewSourcePageOpener(
            sessions: sources,
            webView: FakeSourceWebView(controller: controller),
          );
          late BuildContext openingContext;
          await _pumpHost(tester, session, (context) {
            openingContext = context;
            unawaited(
              opener.openPage(
                context,
                source: SourceKind.chaoxing,
                uri: _sourceUri,
              ),
            );
          });
          expect(controller.started.isCompleted, isTrue);
          expect(controller.setCookieCalls.single.value, _cookieA.value);
          expect(controller.loadedUri, isNull);

          await _changeAccount(session, sources, change);
          if (afterFrame) await tester.pumpAndSettle();
          expect(openingContext.mounted, !afterFrame);
          controller.release.complete();
          await tester.pumpAndSettle();

          expect(controller.calls, ['setCookies']);
          expect(controller.loadedUri, isNull);
          _expectCurrentCookies(sources, change);
          expect(
            find.byKey(const Key('source-page-dialog'), skipOffstage: false),
            findsNothing,
          );
          expect(
            find.byKey(const Key('fake-source-webview'), skipOffstage: false),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
