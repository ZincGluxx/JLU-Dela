import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/models/assignment.dart';
import 'package:jlu_dela/core/models/course.dart';
import 'package:jlu_dela/core/models/local_date.dart';
import 'package:jlu_dela/core/models/material.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/source/chaoxing_access.dart';
import 'package:jlu_dela/core/source/source.dart';
import 'package:jlu_dela/core/storage/course_store.dart';
import 'package:jlu_dela/core/storage/source_snapshot_store.dart';
import 'package:jlu_dela/features/assignments/chaoxing_store.dart';

import 'support/chaoxing_test_support.dart';
import 'support/local_database_test_support.dart';

Future<CourseOffering> _offering(ChaoxingStore store, String sourceId) async {
  final offerings = await store.listCourses();
  return offerings.firstWhere((item) => item.sourceRef.sourceId == sourceId);
}

String _courseUrl(String courseId) {
  return 'https://mooc1.chaoxing.com/visit/stucoursemiddle'
      '?courseid=$courseId&clazzid=200&enc=fixture';
}

void main() {
  test(
    'refresh persists courses and works, keeps marks, and retains cache on failure',
    () async {
      final harness = await ChaoxingHarness.create(
        now: () => DateTime.utc(2026, 11, 3, 2),
      );
      configureSingleCourse(harness.http);

      final report = await harness.store.refreshAll(http: harness.http);
      expect(report.isSuccess, isTrue);
      final offerings = await harness.store.listCourses();
      expect(offerings, hasLength(1));
      expect(offerings.single.sourceRef.sourceId, '100:200');
      expect(offerings.single.retained, isTrue);

      var assignments = await harness.store.list();
      expect(assignments, hasLength(2));
      final workOne = assignments.firstWhere((item) => item.title == '示例作业一');
      expect(workOne.dueKind, AssignmentDueKind.exact);
      expect(
        workOne.dueAtUtc,
        DateTime.parse('2026-11-04T20:00:00+08:00').toUtc(),
      );
      final workTwo = assignments.firstWhere((item) => item.title == '示例作业二');
      expect(
        workTwo.dueAtUtc,
        DateTime.parse('2026-11-04T08:00:00+08:00').toUtc(),
      );
      expect(workTwo.sourceStatus, 'awaiting_review');

      final marked = await harness.store.setMarks(
        workOne.id,
        read: true,
        muted: true,
      );
      expect(marked.readAtUtc, isNotNull);
      expect(marked.mutedAtUtc, isNotNull);

      final http = FakeSourceHttpClient()
        ..on(baseUrl, entryPage())
        ..on(entryUrl, coursesPage())
        ..on(_courseUrl('100'), courseLandingPage())
        ..on(
          worksFrameUrl,
          worksPage(
            works: const [
              (
                id: 'work-1',
                title: '示例作业一',
                status: 'completed',
                timing: '剩余1天',
                fullDate: '2026-11-04 20:00',
              ),
              (
                id: 'work-2',
                title: '示例作业二',
                status: 'To be marked',
                timing: '剩余2小时0分钟',
                fullDate: null,
              ),
            ],
          ),
        );
      final second = await harness.store.refreshAll(http: http);
      expect(second.isSuccess, isTrue);

      assignments = await harness.store.list();
      final refreshedOne = assignments.firstWhere(
        (item) => item.title == '示例作业一',
      );
      expect(refreshedOne.sourceStatus, 'completed');
      expect(refreshedOne.readAtUtc, marked.readAtUtc);
      expect(refreshedOne.mutedAtUtc, marked.mutedAtUtc);
      final refreshedTwo = assignments.firstWhere(
        (item) => item.title == '示例作业二',
      );
      expect(
        refreshedTwo.dueAtUtc,
        DateTime.parse('2026-11-04T08:00:00+08:00').toUtc(),
      );

      final failing = FakeSourceHttpClient()..on(baseUrl, '', statusCode: 500);
      final failed = await harness.store.refreshAll(http: failing);
      expect(failed.coursesFailure?.code, SourceErrorCodes.sourceUnavailable);
      expect(failed.coursesFailure?.retryable, isTrue);
      expect(await harness.store.list(), hasLength(2));
      final snapshot = await harness.store.coursesSnapshot();
      expect(snapshot.lastSuccessAtUtc, isNotNull);
      expect(snapshot.lastErrorCode, SourceErrorCodes.sourceUnavailable);
    },
  );

  test('a failing course only affects its own status and cached work', () async {
    final harness = await ChaoxingHarness.create();
    final http = FakeSourceHttpClient()
      ..on(baseUrl, entryPage())
      ..on(
        entryUrl,
        coursesPage(
          courses: const [
            (id: '100', name: 'A课程', teacher: '教师甲'),
            (id: '101', name: 'B课程', teacher: '教师乙'),
          ],
        ),
      )
      ..on(_courseUrl('100'), courseLandingPage())
      ..on(_courseUrl('101'), '', statusCode: 502)
      ..on(worksFrameUrl, worksPage())
      ..on(
        'https://mooc1.chaoxing.com/mooc2/work/task?workId=work-2&enc=fixture',
        detailPage('截止时间：2026-11-04 08:00'),
      );
    await harness.store.refreshAll(http: http);
    final a = await _offering(harness.store, '100:200');
    final b = await _offering(harness.store, '101:200');
    final report = await harness.store.refreshAll(http: http);
    expect(report.courseFailures, hasLength(1));
    expect(report.courseFailures.single.courseName, 'B课程');
    expect(
      report.courseFailures.single.failure.code,
      SourceErrorCodes.sourceUnavailable,
    );
    expect(await harness.store.list(courseId: a.id), hasLength(2));
    expect(await harness.store.list(courseId: b.id), isEmpty);
    final snapshot = await harness.store.courseSnapshot(b.id);
    expect(snapshot.lastErrorCode, SourceErrorCodes.sourceUnavailable);

    final authHttp = FakeSourceHttpClient()
      ..on(baseUrl, entryPage())
      ..on(
        entryUrl,
        coursesPage(
          courses: const [
            (id: '100', name: 'A课程', teacher: '教师甲'),
            (id: '101', name: 'B课程', teacher: '教师乙'),
          ],
        ),
      )
      ..on(_courseUrl('100'), courseLandingPage())
      ..on(_courseUrl('101'), loginPage())
      ..on(worksFrameUrl, worksPage());
    final authReport = await harness.store.refreshAll(http: authHttp);
    expect(authReport.requiresLogin, isTrue);
    expect(authReport.courseFailures, hasLength(1));
    expect(
      authReport.courseFailures.single.failure.code,
      SourceErrorCodes.sourceAuthRequired,
    );
    expect(await harness.store.list(courseId: a.id), hasLength(2));
  });

  test(
    'same-name courses stay separate and a complete refresh removes missing ones',
    () async {
      final harness = await ChaoxingHarness.create();
      FakeSourceHttpClient twoCourses() {
        return FakeSourceHttpClient()
          ..on(baseUrl, entryPage())
          ..on(
            entryUrl,
            coursesPage(
              courses: const [
                (id: '100', name: '同名课程', teacher: '教师甲'),
                (id: '101', name: '同名课程', teacher: '教师乙'),
              ],
            ),
          )
          ..on(_courseUrl('100'), courseLandingPage())
          ..on(_courseUrl('101'), courseLandingPage())
          ..on(worksFrameUrl, worksPage())
          ..on(
            'https://mooc1.chaoxing.com/mooc2/work/task?workId=work-2&enc=fixture',
            detailPage('截止时间：2026-11-04 08:00'),
          );
      }

      await harness.store.refreshAll(http: twoCourses());
      var offerings = await harness.store.listCourses();
      expect(offerings, hasLength(2));
      expect(offerings.map((item) => item.sourceRef.sourceId).toSet(), {
        '100:200',
        '101:200',
      });
      expect(await harness.store.list(), hasLength(4));

      final onlyFirst = FakeSourceHttpClient()
        ..on(baseUrl, entryPage())
        ..on(entryUrl, coursesPage())
        ..on(_courseUrl('100'), courseLandingPage())
        ..on(worksFrameUrl, worksPage())
        ..on(
          'https://mooc1.chaoxing.com/mooc2/work/task?workId=work-2&enc=fixture',
          detailPage('截止时间：2026-11-04 08:00'),
        );
      await harness.store.refreshAll(http: onlyFirst);
      offerings = await harness.store.listCourses();
      expect(offerings, hasLength(1));
      expect(offerings.single.sourceRef.sourceId, '100:200');
      expect(await harness.store.list(), hasLength(2));
    },
  );

  test('two users never see or modify each other data', () async {
    final harness = await ChaoxingHarness.create();
    configureSingleCourse(harness.http);
    await harness.store.refreshAll(http: harness.http);
    final offering = await _offering(harness.store, '100:200');
    final assignment = (await harness.store.list()).first;
    final other = harness.storeFor('user-b');

    expect(await other.listCourses(), isEmpty);
    expect(await other.list(), isEmpty);
    await expectLater(
      other.setMarks(assignment.id, read: true),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      other.setCourseRemark(offering.id, '别人的课'),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      other.setCourseRetained(offering.id, false),
      throwsA(isA<StateError>()),
    );
    expect(await harness.store.list(), hasLength(2));
  });

  test(
    'course remark and retained preferences survive a source refresh',
    () async {
      final harness = await ChaoxingHarness.create();
      configureSingleCourse(harness.http);
      await harness.store.refreshAll(http: harness.http);
      final offering = await _offering(harness.store, '100:200');

      final renamed = await harness.store.setCourseRemark(
        offering.id,
        '  安卓课  ',
      );
      expect(renamed.remark, '安卓课');
      final unretained = await harness.store.setCourseRetained(
        offering.id,
        false,
      );
      expect(unretained.retained, isFalse);

      configureSingleCourse(harness.http);
      await harness.store.refreshAll(http: harness.http);
      final refreshed = await _offering(harness.store, '100:200');
      expect(refreshed.remark, '安卓课');
      expect(refreshed.retained, isFalse);

      final cleared = await harness.store.setCourseRemark(offering.id, '   ');
      expect(cleared.remark, isNull);
      await expectLater(
        harness.store.setCourseRemark(
          offering.id,
          List.filled(101, '课').join(),
        ),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        harness.store.setCourseRemark('missing', '备注'),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'list filters by course, due range and undated work, ordered by due',
    () async {
      final harness = await ChaoxingHarness.create();
      final http = FakeSourceHttpClient()
        ..on(baseUrl, entryPage())
        ..on(entryUrl, coursesPage())
        ..on(_courseUrl('100'), courseLandingPage())
        ..on(
          worksFrameUrl,
          worksPage(
            works: const [
              (
                id: 'work-exact',
                title: '明确时间',
                status: '未交',
                timing: '',
                fullDate: '2026-11-05 08:00',
              ),
              (
                id: 'work-date',
                title: '只有日期',
                status: '未交',
                timing: '截止日期：2026-11-06',
                fullDate: null,
              ),
              (
                id: 'work-relative',
                title: '相对时间',
                status: '未交',
                timing: '剩余2天',
                fullDate: null,
              ),
              (
                id: 'work-unknown',
                title: '未知时间',
                status: '未交',
                timing: '',
                fullDate: null,
              ),
            ],
          ),
        );
      await harness.store.refreshAll(http: http);
      final offering = await _offering(harness.store, '100:200');

      final all = await harness.store.list();
      expect(all, hasLength(4));
      expect(all.first.title, '明确时间');
      expect(
        all.map((item) => item.dueKind),
        contains(AssignmentDueKind.dateOnly),
      );

      final exactRange = await harness.store.list(
        includeUndated: false,
        from: const LocalDate(2026, 11, 5),
        to: const LocalDate(2026, 11, 6),
      );
      expect(exactRange.map((item) => item.title), ['明确时间']);
      final dateRange = await harness.store.list(
        includeUndated: false,
        from: const LocalDate(2026, 11, 6),
        to: const LocalDate(2026, 11, 7),
      );
      expect(dateRange.map((item) => item.title), ['只有日期']);
      final includingUndated = await harness.store.list(
        from: const LocalDate(2026, 11, 5),
        to: const LocalDate(2026, 11, 6),
        includeUndated: true,
      );
      expect(includingUndated.map((item) => item.title), [
        '明确时间',
        '未知时间',
        '相对时间',
      ]);
      expect(
        await harness.store.list(
          courseId: 'another-course',
          from: const LocalDate(2026, 11, 5),
          to: const LocalDate(2026, 11, 6),
        ),
        isEmpty,
      );
      final dated = await harness.store.list(includeUndated: false);
      expect(dated.map((item) => item.title), ['明确时间', '只有日期']);
      await expectLater(
        harness.store.list(from: const LocalDate(2026, 11, 5)),
        throwsA(isA<ArgumentError>()),
      );
      expect(await harness.store.list(courseId: offering.id), hasLength(4));
    },
  );

  test('real SQLite restart keeps assignments, marks and courses', () async {
    final path = await createTempDatabasePath();
    final firstDatabase = await openTempFileDatabase(path);
    final http = FakeSourceHttpClient();
    configureSingleCourse(http);
    final first = buildStore(
      database: firstDatabase,
      userId: 'user-a',
      source: makeSourceContext(http: http),
      now: () => DateTime.utc(2026, 11, 3, 2),
    );
    await first.refreshAll(http: http);
    final work = (await first.list()).first;
    await first.setMarks(work.id, read: true);
    await firstDatabase.close();

    final secondDatabase = await openTempFileDatabase(path);
    addTearDown(secondDatabase.close);
    final second = buildStore(
      database: secondDatabase,
      userId: 'user-a',
      source: makeSourceContext(http: FakeSourceHttpClient()),
    );
    final reopened = await second.list();
    expect(reopened, hasLength(2));
    expect((await second.listCourses()).single.sourceRef.sourceId, '100:200');
    expect(
      reopened.firstWhere((item) => item.id == work.id).readAtUtc,
      isNotNull,
    );
    final other = buildStore(
      database: secondDatabase,
      userId: 'user-b',
      source: makeSourceContext(http: FakeSourceHttpClient()),
    );
    expect(await other.list(), isEmpty);
  });

  test(
    'openAssignment only accepts mapped works and verified source pages',
    () async {
      final harness = await ChaoxingHarness.create();
      configureSingleCourse(harness.http);
      await harness.store.refreshAll(http: harness.http);
      final work = (await harness.store.list()).firstWhere(
        (item) => item.title == '示例作业一',
      );

      final access = await harness.store.openAssignment(assignmentId: work.id);
      expect(access.uri.host, 'mooc1.chaoxing.com');
      expect(access.uri.queryParameters['workId'], 'work-1');
      expect(access.mode, SourceAccessMode.sourcePage);
      expect(access.requiresSourceSession, isTrue);
      expect(access.expiresAtUtc, isNull);

      await expectLater(
        harness.store.openAssignment(assignmentId: 'not-mapped'),
        throwsA(
          isA<SourceException>().having(
            (error) => error.failure.code,
            'code',
            SourceErrorCodes.sourceProtocol,
          ),
        ),
      );
      await expectLater(
        harness.storeFor('user-b').openAssignment(assignmentId: work.id),
        throwsA(
          isA<SourceException>().having(
            (error) => error.failure.code,
            'code',
            SourceErrorCodes.sourceProtocol,
          ),
        ),
      );
    },
  );

  test('source access requires a session and a wired HTTP client', () async {
    final harness = await ChaoxingHarness.create(connected: false);
    configureSingleCourse(harness.http);
    await harness.store.refreshAll(http: harness.http);
    final work = (await harness.store.list()).first;
    await expectLater(
      harness.store.openAssignment(assignmentId: work.id),
      throwsA(
        isA<SourceException>().having(
          (error) => error.failure.code,
          'code',
          SourceErrorCodes.sourceAuthRequired,
        ),
      ),
    );

    final noClient = ChaoxingStore(
      harness.database,
      'user-a',
      SourceSnapshotStore(harness.database, 'user-a'),
      CourseStore(harness.database, 'user-a'),
    );
    await expectLater(
      noClient.openAssignment(assignmentId: work.id),
      throwsA(
        isA<SourceException>().having(
          (error) => error.failure.code,
          'code',
          SourceErrorCodes.sourceUnavailable,
        ),
      ),
    );
    final report = await noClient.refreshAll();
    expect(report.coursesFailure?.code, SourceErrorCodes.sourceUnavailable);
  });

  test(
    'material ids map to source children and verified download entries',
    () async {
      final harness = await ChaoxingHarness.create();
      final http = FakeSourceHttpClient()
        ..on(baseUrl, entryPage())
        ..on(entryUrl, coursesPage())
        ..on(_courseUrl('100'), courseLandingPage())
        ..on(materialsFrameUrl, materialListPage())
        ..onWhere(
          (uri) => uri.queryParameters['dataId'] == 'folder-1',
          materialFolderPage(),
        );
      final courseOffering = await CourseStore(harness.database, 'user-a')
          .upsert(
            const SourceCourse(
              source: SourceKind.chaoxing,
              sourceScope: 'default',
              sourceId: '100:200',
              name: '示例课程甲',
            ),
          );
      final store = buildStore(
        database: harness.database,
        userId: 'user-a',
        source: makeSourceContext(http: http, sessions: harness.sessions),
      );

      final children = await store.listMaterialChildren(
        courseOfferingId: courseOffering.id,
      );
      expect(children.page, 1);
      expect(children.totalPages, 1);
      expect(children.entries, hasLength(2));
      final folder = children.entries.firstWhere(
        (item) => item.kind == MaterialKind.folder,
      );
      final file = children.entries.firstWhere(
        (item) => item.kind == MaterialKind.file,
      );
      expect(folder.id, 'folder-1');
      expect(folder.parentId, isNull);
      expect(file.id, 'file-1');
      expect(file.downloadable, isTrue);
      expect(file.parentId, isNull);

      final nested = await store.listMaterialChildren(
        courseOfferingId: courseOffering.id,
        parentSourceId: folder.id,
      );
      expect(nested.entries.single.name, '目录内文件.pdf');
      expect(nested.entries.single.parentId, folder.id);

      final access = await store.accessMaterial(
        courseOfferingId: courseOffering.id,
        sourceId: 'file-1',
      );
      expect(access.uri.host, 'download.chaoxing.com');
      expect(access.uri.queryParameters['dataId'], 'file-1');
      expect(access.mode, SourceAccessMode.sourcePage);
      expect(access.filename, '讲义.pdf');
      expect(access.requiresSourceSession, isTrue);
      final nestedAccess = await store.accessMaterial(
        courseOfferingId: courseOffering.id,
        sourceId: 'file-2',
      );
      expect(nestedAccess.uri.queryParameters['dataId'], 'file-2');

      for (final invalid in ['missing', 'https://example.com/file']) {
        await expectLater(
          store.accessMaterial(
            courseOfferingId: courseOffering.id,
            sourceId: invalid,
          ),
          throwsA(
            isA<SourceException>().having(
              (error) => error.failure.code,
              'code',
              SourceErrorCodes.sourceProtocol,
            ),
          ),
          reason: invalid,
        );
      }
      await expectLater(
        store.accessMaterial(courseOfferingId: 'missing', sourceId: 'file-1'),
        throwsA(isA<SourceException>()),
      );
      await expectLater(
        store.listMaterialChildren(courseOfferingId: 'missing'),
        throwsA(isA<SourceException>()),
      );
      await expectLater(
        store.listMaterialChildren(
          courseOfferingId: courseOffering.id,
          parentSourceId: 'missing',
        ),
        throwsA(isA<SourceException>()),
      );
    },
  );
}
