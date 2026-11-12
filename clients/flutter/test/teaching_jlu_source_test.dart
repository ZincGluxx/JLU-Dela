import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/source/source.dart';
import 'package:jlu_dela/core/source/source_session.dart';
import 'package:jlu_dela/features/teaching/jlu_timetable_source.dart';

import 'teaching_test_support.dart';

void main() {
  group('JluTimetableSource', () {
    test(
      'resolves the current semester and posts EMAP form requests',
      () async {
        final http = teachingHttp();
        final source = JluTimetableSource(http: http);

        expect(await source.currentSemester(), '2026-2027-1');
        final fetch = await source.fetch();

        expect(fetch.semesterCode, '2026-2027-1');
        expect(fetch.timetable.semesterStart, '2026-09-14');
        expect(fetch.timetable.totalWeeks, 20);
        expect(fetch.timetable.lessons, hasLength(1));
        expect(fetch.timetable.periodTimes, hasLength(3));
        expect(fetch.warnings, isEmpty);

        expect(http.requests, hasLength(7));
        for (final request in http.requests) {
          expect(request.method, 'POST');
          expect(request.uri.host, 'iedu.jlu.edu.cn');
          expect(request.headers['Origin'], 'https://iedu.jlu.edu.cn');
          expect(request.headers['X-Requested-With'], 'XMLHttpRequest');
          expect(request.body, isNot(contains('XH=')));
          expect(request.body, isNot(contains('password')));
        }
        final courses = http.requests.firstWhere(
          (request) => request.uri.path.endsWith('cxxszhxqkb.do'),
        );
        expect(Uri.splitQueryString(courses.body!)['XNXQDM'], '2026-2027-1');
        final calendar = http.requests.firstWhere(
          (request) => request.uri.path.endsWith('cxxljc.do'),
        );
        final calendarQuery = Uri.splitQueryString(calendar.body!);
        expect(calendarQuery['XN'], '2026-2027');
        expect(calendarQuery['XQ'], '1');
        final changes = http.requests.firstWhere(
          (request) => request.uri.path.endsWith('xsdkkc.do'),
        );
        expect(Uri.splitQueryString(changes.body!)['*order'], '-SQSJ');
      },
    );

    test('raises a source auth failure for the CAS login page', () async {
      final source = JluTimetableSource(http: teachingHttp(loginPage: true));
      await expectLater(
        source.currentSemester(),
        throwsA(
          isA<SourceException>().having(
            (error) => error.failure.code,
            'code',
            SourceErrorCodes.sourceAuthRequired,
          ),
        ),
      );
    });

    test('raises a source auth failure for HTTP 401', () async {
      final http = FakeSourceHttp(<String, SourceResponse Function()>{
        'dqxnxq.do': () => const SourceResponse(statusCode: 401, body: ''),
      });
      await expectLater(
        JluTimetableSource(http: http).currentSemester(),
        throwsA(
          isA<SourceException>().having(
            (error) => error.failure.code,
            'code',
            SourceErrorCodes.sourceAuthRequired,
          ),
        ),
      );
    });

    test(
      'classifies non-JSON and error envelopes as protocol failures',
      () async {
        final nonJson = FakeSourceHttp(<String, SourceResponse Function()>{
          'dqxnxq.do': () =>
              const SourceResponse(statusCode: 200, body: '<html>维护中</html>'),
        });
        await expectLater(
          JluTimetableSource(http: nonJson).currentSemester(),
          throwsA(
            isA<SourceException>().having(
              (error) => error.failure.code,
              'code',
              SourceErrorCodes.sourceProtocol,
            ),
          ),
        );

        final errorEnvelope =
            FakeSourceHttp(<String, SourceResponse Function()>{
              'dqxnxq.do': () => const SourceResponse(
                statusCode: 200,
                body: '{"code":"500","datas":{}}',
              ),
            });
        await expectLater(
          JluTimetableSource(http: errorEnvelope).currentSemester(),
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
                  contains('响应结构'),
                ),
          ),
        );
      },
    );

    test('malformed lesson rows are rejected instead of fabricated', () async {
      final source = JluTimetableSource(
        http: teachingHttp(
          courses: <Map<String, Object?>>[
            <String, Object?>{'KCM': '缺少时间'},
          ],
        ),
      );
      await expectLater(
        source.fetch(semesterCode: '2026-2027-1'),
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
                contains('字段'),
              ),
        ),
      );
    });

    test('keeps a warning when optional change data is unavailable', () async {
      final source = JluTimetableSource(http: teachingHttp(failChanges: true));
      final fetch = await source.fetch(semesterCode: '2026-2027-1');
      expect(fetch.timetable.lessons, hasLength(1));
      expect(fetch.warnings, contains('调停课信息未获取，请对照教务原课表核查临时调整'));
      expect(fetch.warnings, isNot(contains('未排定时间的课程信息未获取')));
    });

    test(
      'still fails the refresh when an expired session hits an optional endpoint',
      () async {
        final http = teachingHttp();
        final routes = Map<String, SourceResponse Function()>.of(
          Map<String, SourceResponse Function()>.from(http.routes),
        );
        routes['xsdkkc.do'] = () =>
            throw sourceFailure('SOURCE_AUTH_REQUIRED', '教务登录已失效');
        await expectLater(
          JluTimetableSource(
            http: FakeSourceHttp(routes),
          ).fetch(semesterCode: '2026-2027-1'),
          throwsA(
            isA<SourceException>().having(
              (error) => error.failure.code,
              'code',
              SourceErrorCodes.sourceAuthRequired,
            ),
          ),
        );
      },
    );
  });
}
