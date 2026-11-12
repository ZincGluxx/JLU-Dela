import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/campus_source_policy.dart';
import 'package:jlu_dela/core/source/source_session.dart';

void main() {
  group('source allowlist', () {
    test('accepts only allowlisted https hosts on the default port', () {
      for (final host in sourceAllowedHosts) {
        expect(
          isAllowedSourceUri(Uri.parse('https://$host/')),
          isTrue,
          reason: host,
        );
      }
      expect(isAllowedSourceUri(Uri.parse('http://iedu.jlu.edu.cn/')), isFalse);
      expect(
        isAllowedSourceUri(Uri.parse('https://iedu.jlu.edu.cn:8443/')),
        isFalse,
      );
      expect(
        isAllowedSourceUri(Uri.parse('https://iedu.jlu.edu.cn@evil.example/')),
        isFalse,
      );
      expect(isAllowedSourceUri(Uri.parse('https://evil.example/')), isFalse);
      expect(
        isAllowedSourceUri(Uri.parse('https://sub.iedu.jlu.edu.cn/')),
        isFalse,
      );
    });

    test('maps allowlisted hosts to source kinds and auth groups', () {
      expect(
        sourceForAllowedUri(Uri.parse('https://iedu.jlu.edu.cn/')),
        SourceKind.jluIedu,
      );
      expect(
        sourceForAllowedUri(Uri.parse('https://cas.jlu.edu.cn/')),
        SourceKind.jluIedu,
      );
      expect(
        sourceForAllowedUri(Uri.parse('https://oa.jlu.edu.cn/')),
        SourceKind.jluOa,
      );
      for (final host in const [
        'i.chaoxing.com',
        'passport2.chaoxing.com',
        'mooc1.chaoxing.com',
        'mooc1-1.chaoxing.com',
        'mooc2-ans.chaoxing.com',
      ]) {
        expect(
          sourceForAllowedUri(Uri.parse('https://$host/')),
          SourceKind.chaoxing,
          reason: host,
        );
      }
      expect(sourceForAllowedUri(Uri.parse('https://evil.example/')), isNull);
      expect(sourceAuthGroup(SourceKind.jluIedu), SourceAuthGroup.jluCampus);
      expect(sourceAuthGroup(SourceKind.jluOa), SourceAuthGroup.jluCampus);
      expect(sourceAuthGroup(SourceKind.chaoxing), SourceAuthGroup.chaoxing);
    });

    test('recognizes only school login pages', () {
      expect(
        isSourceLoginUri(
          Uri.parse('https://cas.jlu.edu.cn/tpass/login?service=iedu'),
        ),
        isTrue,
      );
      expect(
        isSourceLoginUri(
          Uri.parse('https://cas.jlu.edu.cn/tpass/login;jsessionid=abc'),
        ),
        isTrue,
      );
      expect(
        isSourceLoginUri(Uri.parse('https://cas.jlu.edu.cn/tpass/logout')),
        isFalse,
      );
      expect(
        isSourceLoginUri(
          Uri.parse('https://passport2.chaoxing.com/login?fid=12'),
        ),
        isTrue,
      );
      expect(
        isSourceLoginUri(Uri.parse('https://passport2.chaoxing.com/mlogin')),
        isTrue,
      );
      expect(
        isSourceLoginUri(Uri.parse('https://i.chaoxing.com/base')),
        isFalse,
      );
      expect(
        isSourceLoginUri(
          Uri.parse('https://cas.jlu.edu.cn.evil.example/tpass/login'),
        ),
        isFalse,
      );
      expect(
        isSourceLoginUri(Uri.parse('http://cas.jlu.edu.cn/tpass/login')),
        isFalse,
      );
    });
  });

  group('source endpoints', () {
    test('keep every entry, probe and cookie URL inside the same group', () {
      for (final kind in SourceKind.values) {
        final endpoints = CampusSourceEndpoints.forSource(kind);
        expect(isAllowedSourceUri(endpoints.loginEntryUri), isTrue);
        expect(isAllowedSourceUri(endpoints.probeUri), isTrue);
        expect(endpoints.cookieUris, isNotEmpty);
        expect(
          sourceAuthGroup(sourceForAllowedUri(endpoints.loginEntryUri)!),
          sourceAuthGroup(kind),
        );
        expect(
          sourceAuthGroup(sourceForAllowedUri(endpoints.probeUri)!),
          sourceAuthGroup(kind),
        );
        for (final uri in endpoints.cookieUris) {
          expect(isAllowedSourceUri(uri), isTrue);
          expect(
            sourceAuthGroup(sourceForAllowedUri(uri)!),
            sourceAuthGroup(kind),
          );
        }
      }
    });

    test('detects the JLU CAS login form', () {
      final endpoints = CampusSourceEndpoints.forSource(SourceKind.jluIedu);
      final loginBodies = [
        '<html><form id="loginForm" action="/tpass/login"></form></html>',
        '<html><input name="WxCode" /></html>',
        '<html><input type="password" name="password" /></html>',
      ];
      for (final body in loginBodies) {
        expect(
          endpoints.looksLikeLoginPage(
            SourceResponse(statusCode: 200, body: body),
          ),
          isTrue,
          reason: body,
        );
      }
      expect(
        endpoints.looksLikeLoginPage(
          SourceResponse(
            statusCode: 200,
            body: '<html><body>吉林大学教务系统</body></html>',
          ),
        ),
        isFalse,
      );
      expect(
        endpoints.looksLikeLoginPage(
          SourceResponse(
            statusCode: 200,
            body: '<html><body>吉林大学教务系统</body></html>',
            finalUri: Uri.parse('https://cas.jlu.edu.cn/tpass/login'),
          ),
        ),
        isTrue,
      );
    });

    test('decides whether a probe response proves the session is active', () {
      final iedu = CampusSourceEndpoints.forSource(SourceKind.jluIedu);
      final probe = iedu.probeUri;
      expect(
        iedu.indicatesAuthenticated(
          SourceResponse(
            statusCode: 200,
            body: '<html><body>教务首页</body></html>',
            finalUri: probe,
          ),
        ),
        isTrue,
      );
      expect(
        iedu.indicatesAuthenticated(
          SourceResponse(
            statusCode: 200,
            body: '<html><body>教务首页</body></html>',
            finalUri: Uri.parse('https://cas.jlu.edu.cn/tpass/login'),
          ),
        ),
        isFalse,
      );
      expect(
        iedu.indicatesAuthenticated(
          SourceResponse(
            statusCode: 200,
            body: '<form id="loginForm"></form>',
            finalUri: probe,
          ),
        ),
        isFalse,
      );
      expect(
        iedu.indicatesAuthenticated(
          SourceResponse(statusCode: 500, body: '', finalUri: probe),
        ),
        isFalse,
      );

      final oa = CampusSourceEndpoints.forSource(SourceKind.jluOa);
      expect(
        oa.indicatesAuthenticated(
          SourceResponse(
            statusCode: 200,
            body: '<html><body>电子校务通知列表</body></html>',
            finalUri: oa.probeUri,
          ),
        ),
        isTrue,
      );
    });

    test('detects the Chaoxing login form', () {
      final endpoints = CampusSourceEndpoints.forSource(SourceKind.chaoxing);
      for (final body in [
        '<html><form id="fanyalogin"></form></html>',
        '<html><input id="phone" /></html>',
        '<html><input id="pwd" type="password" /></html>',
      ]) {
        expect(
          endpoints.looksLikeLoginPage(
            SourceResponse(statusCode: 200, body: body),
          ),
          isTrue,
          reason: body,
        );
      }
      expect(
        endpoints.looksLikeLoginPage(
          SourceResponse(
            statusCode: 200,
            body: '<html><body>学习通首页</body></html>',
            finalUri: Uri.parse('https://i.chaoxing.com/base'),
          ),
        ),
        isFalse,
      );
      expect(
        endpoints.looksLikeLoginPage(
          SourceResponse(
            statusCode: 200,
            body: '<html><body>学习通首页</body></html>',
            finalUri: Uri.parse('https://passport2.chaoxing.com/login?fid=12'),
          ),
        ),
        isTrue,
      );
    });
  });
}
