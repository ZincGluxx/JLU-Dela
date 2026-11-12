import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/in_app_web_view_source_web_view.dart';
import 'package:jlu_dela/core/source/source_session.dart';

void main() {
  test('keeps domain, path, flags and expiry from WebView2 cookies', () {
    final sourceCookie = sourceCookieFromWebViewCookie(
      Cookie(
        name: 'CASTGC',
        value: 'test-ticket',
        domain: '.jlu.edu.cn',
        path: '/tpass',
        isSecure: true,
        isHttpOnly: true,
        expiresDate: 1767225600,
      ),
      Uri.parse('https://cas.jlu.edu.cn/tpass/login'),
      isWindows: true,
    );

    expect(sourceCookie, isNotNull);
    expect(sourceCookie!.name, 'CASTGC');
    expect(sourceCookie.value, 'test-ticket');
    expect(sourceCookie.domain, '.jlu.edu.cn');
    expect(sourceCookie.path, '/tpass');
    expect(sourceCookie.secure, isTrue);
    expect(sourceCookie.httpOnly, isTrue);
    expect(sourceCookie.hostOnly, isFalse);
    expect(
      sourceCookie.expiresAtUtc,
      DateTime.fromMillisecondsSinceEpoch(1767225600000, isUtc: true),
    );
  });

  test('keeps non-Windows WebView expiry in milliseconds', () {
    final cookie = sourceCookieFromWebViewCookie(
      Cookie(name: 'UID', value: 'test-uid', expiresDate: 1798761600123),
      Uri.parse('https://i.chaoxing.com/base'),
      isWindows: false,
    );

    expect(cookie!.expiresAtUtc, DateTime.utc(2027, 1, 1, 0, 0, 0, 123));
  });

  test('defaults expiry conversion to the actual platform', () {
    final cookie = sourceCookieFromWebViewCookie(
      Cookie(
        name: 'UID',
        value: 'test-uid',
        expiresDate: Platform.isWindows ? 1798761600 : 1798761600000,
      ),
      Uri.parse('https://i.chaoxing.com/base'),
    );

    expect(cookie!.expiresAtUtc, DateTime.utc(2027));
  });

  test('Windows persistent cookies remain usable until their real expiry', () {
    final uri = Uri.parse('https://i.chaoxing.com/base');
    final sessions = SourceSessionRegistry(now: () => DateTime.utc(2026));
    sessions.save(SourceAuthGroup.chaoxing, [
      sourceCookieFromWebViewCookie(
        Cookie(
          name: 'UID',
          value: 'test-uid',
          domain: '.chaoxing.com',
          expiresDate: 1798761600,
          isSessionOnly: false,
        ),
        uri,
        isWindows: true,
      )!,
      sourceCookieFromWebViewCookie(
        Cookie(name: 'expired', value: 'old', expiresDate: 1735689600),
        uri,
        isWindows: true,
      )!,
    ]);

    expect(sessions.cookieHeaderFor(SourceKind.chaoxing, uri), {
      'UID': 'test-uid',
    });
  });

  test(
    'session and non-positive expiries stay session-only on both platforms',
    () {
      for (final isWindows in [true, false]) {
        for (final expiresDate in [null, -1, 0]) {
          final cookie = sourceCookieFromWebViewCookie(
            Cookie(name: 'session', value: 'test', expiresDate: expiresDate),
            Uri.parse('https://iedu.jlu.edu.cn/'),
            isWindows: isWindows,
          );
          expect(cookie!.expiresAtUtc, isNull);
        }
        final cookie = sourceCookieFromWebViewCookie(
          Cookie(
            name: 'session',
            value: 'test',
            expiresDate: 1798761600,
            isSessionOnly: true,
          ),
          Uri.parse('https://iedu.jlu.edu.cn/'),
          isWindows: isWindows,
        );
        expect(cookie!.expiresAtUtc, isNull);
      }
    },
  );

  test('treats a cookie without domain as host-only for the queried host', () {
    final sourceCookie = sourceCookieFromWebViewCookie(
      Cookie(name: 'JSESSIONID', value: 'session'),
      Uri.parse('https://iedu.jlu.edu.cn/'),
    );

    expect(sourceCookie, isNotNull);
    expect(sourceCookie!.domain, 'iedu.jlu.edu.cn');
    expect(sourceCookie.hostOnly, isTrue);
    expect(sourceCookie.secure, isTrue);
    expect(sourceCookie.path, '/');
    expect(sourceCookie.expiresAtUtc, isNull);
  });

  test('drops cookies without a name and keeps session cookies in memory', () {
    expect(
      sourceCookieFromWebViewCookie(
        Cookie(name: '', value: 'x'),
        Uri.parse('https://cas.jlu.edu.cn/'),
      ),
      isNull,
    );
    final sessionCookie = sourceCookieFromWebViewCookie(
      Cookie(
        name: 'ROUTE',
        value: 'node-1',
        domain: 'cas.jlu.edu.cn',
        path: '/',
        isSessionOnly: true,
      ),
      Uri.parse('https://cas.jlu.edu.cn/'),
    );
    expect(sessionCookie!.expiresAtUtc, isNull);
    expect(sessionCookie.hostOnly, isTrue);
  });
}
