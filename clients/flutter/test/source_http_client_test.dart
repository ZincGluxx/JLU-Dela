import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlu_dela/core/source/cookie_source_http_client.dart';
import 'package:jlu_dela/core/source/source.dart';
import 'package:jlu_dela/core/source/source_session.dart';

Matcher sourceFailure(String code) {
  return throwsA(
    isA<SourceException>().having((error) => error.failure.code, 'code', code),
  );
}

SourceCookie jluCookie({
  String name = 'CASTGC',
  String value = 'test-ticket',
  String domain = '.jlu.edu.cn',
  String path = '/',
  bool hostOnly = false,
}) {
  return SourceCookie(
    name: name,
    value: value,
    domain: domain,
    path: path,
    secure: true,
    httpOnly: true,
    hostOnly: hostOnly,
  );
}

void main() {
  test('attaches registry cookies only to matching allowlist hosts', () async {
    final sessions = SourceSessionRegistry();
    sessions.save(SourceAuthGroup.jluCampus, [
      jluCookie(domain: 'iedu.jlu.edu.cn', hostOnly: true),
    ]);
    final headers = <String, Map<String, String>>{};
    final client = CookieSourceHttpClient(
      sessions: sessions,
      client: MockClient((request) async {
        headers[request.url.host] = request.headers;
        return http.Response('<html>ok</html>', 200);
      }),
    );

    final response = await client.send(
      SourceRequest(
        uri: Uri.parse(
          'https://iedu.jlu.edu.cn/jwapp/sys/emaphome/portal/index.do',
        ),
      ),
    );

    expect(response.statusCode, 200);
    expect(
      response.finalUri,
      Uri.parse('https://iedu.jlu.edu.cn/jwapp/sys/emaphome/portal/index.do'),
    );
    expect(headers['iedu.jlu.edu.cn']!['cookie'], 'CASTGC=test-ticket');

    await client.send(SourceRequest(uri: Uri.parse('https://oa.jlu.edu.cn/')));
    expect(headers['oa.jlu.edu.cn']!.containsKey('cookie'), isFalse);
  });

  test('rejects requests outside the allowlist before sending', () async {
    var requests = 0;
    final client = CookieSourceHttpClient(
      sessions: SourceSessionRegistry(),
      client: MockClient((request) async {
        requests++;
        return http.Response('', 200);
      }),
    );

    await expectLater(
      client.send(SourceRequest(uri: Uri.parse('https://evil.example/'))),
      sourceFailure(SourceErrorCodes.sourceProtocol),
    );
    await expectLater(
      client.send(SourceRequest(uri: Uri.parse('http://iedu.jlu.edu.cn/'))),
      sourceFailure(SourceErrorCodes.sourceProtocol),
    );
    expect(requests, 0);
  });

  test(
    'follows redirects inside the source and reports the final uri',
    () async {
      final seen = <Uri>[];
      final client = CookieSourceHttpClient(
        sessions: SourceSessionRegistry(),
        client: MockClient((request) async {
          seen.add(request.url);
          if (request.url.path == '/jwapp/sys/emaphome/portal/index.do') {
            return http.Response(
              '',
              302,
              headers: {'location': '/jwapp/sys/emaphome/home.do'},
            );
          }
          return http.Response('<html>ok</html>', 200);
        }),
      );

      final response = await client.send(
        SourceRequest(
          uri: Uri.parse(
            'https://iedu.jlu.edu.cn/jwapp/sys/emaphome/portal/index.do',
          ),
        ),
      );

      expect(seen.length, 2);
      expect(
        response.finalUri,
        Uri.parse('https://iedu.jlu.edu.cn/jwapp/sys/emaphome/home.do'),
      );
    },
  );

  test(
    'stops at redirects outside the allowlist without leaking cookies',
    () async {
      var requests = 0;
      final sessions = SourceSessionRegistry();
      sessions.save(SourceAuthGroup.jluCampus, [jluCookie()]);
      final client = CookieSourceHttpClient(
        sessions: sessions,
        client: MockClient((request) async {
          requests++;
          return http.Response(
            '',
            302,
            headers: {'location': 'https://evil.example/steal'},
          );
        }),
      );

      await expectLater(
        client.send(
          SourceRequest(
            uri: Uri.parse('https://iedu.jlu.edu.cn/?ticket=SECRET'),
          ),
        ),
        throwsA(
          isA<SourceException>()
              .having(
                (error) => error.failure.code,
                'code',
                SourceErrorCodes.sourceProtocol,
              )
              .having(
                (error) => error.failure.message,
                'message',
                isNot(contains('SECRET')),
              ),
        ),
      );
      expect(requests, 1);
    },
  );

  test('reports authentication required for school login redirects', () async {
    final client = CookieSourceHttpClient(
      sessions: SourceSessionRegistry(),
      client: MockClient(
        (request) async => http.Response(
          '',
          302,
          headers: {
            'location': 'https://cas.jlu.edu.cn/tpass/login?service=iedu',
          },
        ),
      ),
    );

    await expectLater(
      client.send(
        SourceRequest(
          uri: Uri.parse(
            'https://iedu.jlu.edu.cn/jwapp/sys/emaphome/portal/index.do',
          ),
        ),
      ),
      sourceFailure(SourceErrorCodes.sourceAuthRequired),
    );
  });

  test('stops redirects that cross source groups', () async {
    final client = CookieSourceHttpClient(
      sessions: SourceSessionRegistry(),
      client: MockClient(
        (request) async => http.Response(
          '',
          302,
          headers: {'location': 'https://i.chaoxing.com/base'},
        ),
      ),
    );

    await expectLater(
      client.send(SourceRequest(uri: Uri.parse('https://iedu.jlu.edu.cn/'))),
      sourceFailure(SourceErrorCodes.sourceProtocol),
    );
  });

  test(
    'reports authentication required on 401 and login form responses',
    () async {
      final unauthorized = CookieSourceHttpClient(
        sessions: SourceSessionRegistry(),
        client: MockClient((request) async => http.Response('', 401)),
      );
      await expectLater(
        unauthorized.send(
          SourceRequest(uri: Uri.parse('https://iedu.jlu.edu.cn/')),
        ),
        sourceFailure(SourceErrorCodes.sourceAuthRequired),
      );

      final loginForm = CookieSourceHttpClient(
        sessions: SourceSessionRegistry(),
        client: MockClient(
          (request) async => http.Response('<form id="loginForm"></form>', 200),
        ),
      );
      await expectLater(
        loginForm.send(
          SourceRequest(uri: Uri.parse('https://iedu.jlu.edu.cn/')),
        ),
        sourceFailure(SourceErrorCodes.sourceAuthRequired),
      );
    },
  );

  test('classifies timeouts, server errors and network failures', () async {
    final serverError = CookieSourceHttpClient(
      sessions: SourceSessionRegistry(),
      client: MockClient((request) async => http.Response('', 502)),
    );
    await expectLater(
      serverError.send(
        SourceRequest(uri: Uri.parse('https://iedu.jlu.edu.cn/')),
      ),
      sourceFailure(SourceErrorCodes.sourceUnavailable),
    );

    final serverTimeout = CookieSourceHttpClient(
      sessions: SourceSessionRegistry(),
      client: MockClient((request) async => http.Response('', 408)),
    );
    await expectLater(
      serverTimeout.send(
        SourceRequest(uri: Uri.parse('https://iedu.jlu.edu.cn/')),
      ),
      sourceFailure(SourceErrorCodes.sourceTimeout),
    );

    final network = CookieSourceHttpClient(
      sessions: SourceSessionRegistry(),
      client: MockClient(
        (request) async => throw http.ClientException('offline'),
      ),
    );
    await expectLater(
      network.send(SourceRequest(uri: Uri.parse('https://iedu.jlu.edu.cn/'))),
      sourceFailure(SourceErrorCodes.sourceNetwork),
    );

    final slow = CookieSourceHttpClient(
      sessions: SourceSessionRegistry(),
      client: MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response('', 200);
      }),
    );
    await expectLater(
      slow.send(
        SourceRequest(
          uri: Uri.parse('https://iedu.jlu.edu.cn/'),
          timeout: const Duration(milliseconds: 20),
        ),
      ),
      sourceFailure(SourceErrorCodes.sourceTimeout),
    );
  });

  test('ignores caller supplied Cookie headers', () async {
    final sessions = SourceSessionRegistry();
    sessions.save(SourceAuthGroup.jluCampus, [jluCookie()]);
    Map<String, String>? seen;
    final client = CookieSourceHttpClient(
      sessions: sessions,
      client: MockClient((request) async {
        seen = request.headers;
        return http.Response('<html>ok</html>', 200);
      }),
    );

    await client.send(
      SourceRequest(
        uri: Uri.parse('https://iedu.jlu.edu.cn/'),
        headers: {'Cookie': 'injected=1'},
      ),
    );

    expect(seen!['cookie'], 'CASTGC=test-ticket');
    expect(seen!.keys.where((key) => key.toLowerCase() == 'cookie').length, 1);
  });

  test('stops after the configured redirect limit', () async {
    var requests = 0;
    final client = CookieSourceHttpClient(
      sessions: SourceSessionRegistry(),
      client: MockClient((request) async {
        requests++;
        return http.Response(
          '',
          302,
          headers: {'location': 'https://iedu.jlu.edu.cn/next'},
        );
      }),
    );

    await expectLater(
      client.send(SourceRequest(uri: Uri.parse('https://iedu.jlu.edu.cn/'))),
      sourceFailure(SourceErrorCodes.sourceProtocol),
    );
    expect(requests, 6);
  });
}
