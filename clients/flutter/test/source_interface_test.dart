import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/campus_login.dart';
import 'package:jlu_dela/core/source/chaoxing_access.dart';
import 'package:jlu_dela/core/source/source.dart';
import 'package:jlu_dela/core/source/source_context.dart';
import 'package:jlu_dela/core/source/source_portal.dart';
import 'package:jlu_dela/core/source/source_session.dart';

void main() {
  test('source requests default to a bounded timeout', () {
    final request = SourceRequest(uri: Uri.parse('https://iedu.jlu.edu.cn/'));

    expect(request.timeout, const Duration(seconds: 30));

    final response = SourceResponse(
      statusCode: 200,
      body: '',
      finalUri: Uri.parse('https://cas.jlu.edu.cn/tpass/login'),
    );
    expect(response.finalUri, Uri.parse('https://cas.jlu.edu.cn/tpass/login'));
  });

  test('unavailable chaoxing access reports a source failure', () async {
    const access = UnavailableChaoxingAccess();

    await expectLater(
      access.listMaterialChildren(
        courseOfferingId: 'course-1',
        parentSourceId: 'folder-1',
        page: 2,
      ),
      throwsA(
        isA<SourceException>().having(
          (error) => error.failure.code,
          'code',
          SourceErrorCodes.sourceUnavailable,
        ),
      ),
    );
    await expectLater(
      access.accessMaterial(courseOfferingId: 'course-1', sourceId: 'file-1'),
      throwsA(isA<SourceException>()),
    );
    await expectLater(
      access.openAssignment(assignmentId: 'assignment-1'),
      throwsA(isA<SourceException>()),
    );
  });

  testWidgets('unsupported page opening reports a source failure', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (builderContext) {
          context = builderContext;
          return const SizedBox.shrink();
        },
      ),
    );

    await expectLater(
      const UnsupportedSourcePageOpener().openPage(
        context,
        source: SourceKind.jluOa,
        uri: Uri.parse('https://oa.jlu.edu.cn/'),
      ),
      throwsA(
        isA<SourceException>().having(
          (error) => error.failure.code,
          'code',
          SourceErrorCodes.sourceUnavailable,
        ),
      ),
    );
  });

  testWidgets('fake campus login receives the widget context', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (builderContext) {
          context = builderContext;
          return const SizedBox.shrink();
        },
      ),
    );
    final login = FakeCampusLogin();

    final result = await login.connect(context, SourceKind.chaoxing);

    expect(result.connected, isTrue);
    expect(login.attempted, [SourceKind.chaoxing]);
  });

  test('source context carries the shared source dependencies', () {
    final sessions = SourceSessionRegistry();
    final http = UnavailableSourceHttpClient(sessions: sessions);
    const campusLogin = UnsupportedCampusLogin();
    const browser = UnsupportedSourcePageOpener();
    final context = SourceContext(
      sessions: sessions,
      http: http,
      campusLogin: campusLogin,
      browser: browser,
    );

    expect(context.sessions, same(sessions));
    expect(context.http, same(http));
    expect(context.campusLogin, same(campusLogin));
    expect(context.browser, same(browser));
  });
}
