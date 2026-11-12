import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/source/source.dart';
import 'package:jlu_dela/features/assignments/chaoxing_source.dart';

import 'support/chaoxing_test_support.dart';

void main() {
  const courseUrl =
      'https://mooc1.chaoxing.com/visit/stucoursemiddle'
      '?courseid=100&clazzid=200&enc=fixture';

  test(
    'fetchCourses resolves the entry frame and keeps source routes',
    () async {
      final http = FakeSourceHttpClient()
        ..on(baseUrl, entryPage())
        ..on(entryUrl, coursesPage());
      final source = ChaoxingSource(http);

      final courses = await source.fetchCourses();
      expect(courses, hasLength(1));
      expect(courses.single.id, '100:200');
      expect(courses.single.name, '示例课程甲');
      expect(courses.single.sourceUri?.path, '/visit/stucoursemiddle');
    },
  );

  test(
    'uses the redirected final URI to resolve a relative entry frame',
    () async {
      final finalUri = Uri.parse('https://i.chaoxing.com/home');
      final http = FakeSourceHttpClient()
        ..on(
          baseUrl,
          '<html><body><iframe id="frame_content" src="frame"></iframe></body></html>',
          finalUri: finalUri,
        )
        ..on('https://i.chaoxing.com/frame', coursesPage());
      final source = ChaoxingSource(http);

      final courses = await source.fetchCourses();
      expect(courses, hasLength(1));
      expect(
        http.requests,
        contains(Uri.parse('https://i.chaoxing.com/frame')),
      );
    },
  );

  test('fetchWorks merges detail deadlines and notes detail failures', () async {
    final http = FakeSourceHttpClient()
      ..on(baseUrl, entryPage())
      ..on(entryUrl, coursesPage())
      ..on(courseUrl, courseLandingPage())
      ..on(worksFrameUrl, worksPage())
      ..on(
        'https://mooc1.chaoxing.com/mooc2/work/task?workId=work-2&enc=fixture',
        detailPage('截止时间：2026-11-04 08:00'),
      );
    final source = ChaoxingSource(http);
    final course = (await source.fetchCourses()).single;

    final works = await source.fetchWorks(course);
    expect(works, hasLength(2));
    expect(works[0].detailTiming, '截止时间：2026-11-04 20:00');
    expect(works[1].detailTiming, '截止时间：2026-11-04 08:00');

    final failing = FakeSourceHttpClient()
      ..on(baseUrl, entryPage())
      ..on(entryUrl, coursesPage())
      ..on(courseUrl, courseLandingPage())
      ..on(worksFrameUrl, worksPage());
    final failingWorks = await ChaoxingSource(failing).fetchWorks(course);
    expect(failingWorks[1].detailTiming, isNull);
    expect(failingWorks[1].detailError, contains('详情'));
  });

  test('detail authentication failure stops the course refresh', () async {
    final http = FakeSourceHttpClient()
      ..on(baseUrl, entryPage())
      ..on(entryUrl, coursesPage())
      ..on(courseUrl, courseLandingPage())
      ..on(worksFrameUrl, worksPage())
      ..on(
        'https://mooc1.chaoxing.com/mooc2/work/task?workId=work-2&enc=fixture',
        loginPage(),
      );
    final source = ChaoxingSource(http);
    final course = (await source.fetchCourses()).single;

    await expectLater(
      source.fetchWorks(course),
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
    'falls back to pageHeader and accepts a directly served work list',
    () async {
      final http = FakeSourceHttpClient()
        ..on(baseUrl, entryPage())
        ..on(entryUrl, coursesPage())
        ..on(courseUrl, '<html><body>课程首页</body></html>')
        ..onWhere(
          (uri) =>
              uri.path.endsWith('/visit/stucoursemiddle') &&
              uri.queryParameters['pageHeader'] == '8',
          worksPage(),
        );
      final source = ChaoxingSource(http);
      final course = (await source.fetchCourses()).single;

      final items = await source.fetchWorkItems(course);
      expect(items.map((item) => item.work.id), ['work-1', 'work-2']);
      expect(
        http.requests.any((uri) => uri.queryParameters['pageHeader'] == '8'),
        isTrue,
      );
    },
  );

  test('login pages and forbidden responses map to auth required', () async {
    for (final http in [
      FakeSourceHttpClient()..on(baseUrl, loginPage()),
      FakeSourceHttpClient()..on(baseUrl, '', statusCode: 403),
    ]) {
      await expectLater(
        ChaoxingSource(http).fetchCourses(),
        throwsA(
          isA<SourceException>().having(
            (error) => error.failure.code,
            'code',
            SourceErrorCodes.sourceAuthRequired,
          ),
        ),
      );
    }
  });

  test('unknown structure and foreign hosts map to source protocol', () async {
    final broken = FakeSourceHttpClient()
      ..on(baseUrl, '<html><body>系统维护中</body></html>');
    await expectLater(
      ChaoxingSource(broken).fetchCourses(),
      throwsA(
        isA<SourceException>().having(
          (error) => error.failure.code,
          'code',
          SourceErrorCodes.sourceProtocol,
        ),
      ),
    );

    final foreign = FakeSourceHttpClient()
      ..on(
        baseUrl,
        '<html><body><iframe id="frame_content" src="https://example.com/x"></iframe></body></html>',
      );
    await expectLater(
      ChaoxingSource(foreign).fetchCourses(),
      throwsA(
        isA<SourceException>().having(
          (error) => error.failure.code,
          'code',
          SourceErrorCodes.sourceProtocol,
        ),
      ),
    );
    expect(foreign.requests.any((uri) => uri.host == 'example.com'), isFalse);
  });

  test('server errors are retryable and unexpected pages are not', () async {
    final serverError = FakeSourceHttpClient()
      ..on(baseUrl, '', statusCode: 503);
    await expectLater(
      ChaoxingSource(serverError).fetchCourses(),
      throwsA(
        isA<SourceException>().having(
          (error) => error.failure.retryable,
          'retryable',
          isTrue,
        ),
      ),
    );
    final notFound = FakeSourceHttpClient()..on(baseUrl, '', statusCode: 404);
    await expectLater(
      ChaoxingSource(notFound).fetchCourses(),
      throwsA(
        isA<SourceException>().having(
          (error) => error.failure.retryable,
          'retryable',
          isFalse,
        ),
      ),
    );
  });
}
