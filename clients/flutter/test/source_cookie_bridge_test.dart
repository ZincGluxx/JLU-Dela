import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/source/in_app_web_view_source_web_view.dart';

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
        expiresDate: 1767225600000,
      ),
      Uri.parse('https://cas.jlu.edu.cn/tpass/login'),
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
