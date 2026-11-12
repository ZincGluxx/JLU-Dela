import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/models/local_date.dart';
import 'package:jlu_dela/core/source/campus_login.dart';
import 'package:jlu_dela/core/source/source.dart';
import 'package:jlu_dela/core/source/source_context.dart';
import 'package:jlu_dela/core/source/source_portal.dart';
import 'package:jlu_dela/core/source/source_session.dart';
import 'package:jlu_dela/core/storage/course_store.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
import 'package:jlu_dela/core/storage/source_snapshot_store.dart';
import 'package:jlu_dela/features/teaching/teaching_store.dart';

import 'support/local_database_test_support.dart';
import 'teaching_test_support.dart';

final DateTime _now = DateTime.utc(2026, 9, 16, 12);
const String _semesterCode = '2026-2027-1';

T _value<T>(SourceResult<T> result) {
  return switch (result) {
    SourceSuccess<T>(:final value) => value,
    SourceFailed<T>(:final failure) => fail(
      'unexpected source failure: ${failure.code} ${failure.message}',
    ),
  };
}

void main() {
  late LocalDatabase database;
  late SourceSnapshotStore snapshots;
  late CourseStore courses;
  late TeachingStore store;

  setUp(() async {
    database = await openTestDatabase();
    snapshots = SourceSnapshotStore(database, 'user-a');
    courses = CourseStore(database, 'user-a', now: () => _now);
    store = TeachingStore(
      database,
      'user-a',
      snapshots,
      courses,
      now: () => _now,
    );
  });

  tearDown(() => database.close());

  Future<void> syncSemester(FakeSourceHttp http) async {
    _value(await store.syncCurrentSemester(http: http));
    _value(
      await store.refreshSemester(http: http, semesterCode: _semesterCode),
    );
  }

  test('persists semesters, period times, lessons and source status', () async {
    final http = teachingHttp();
    await syncSemester(http);

    final semesters = await store.listSemesters();
    expect(semesters, hasLength(1));
    final semester = semesters.single;
    expect(semester.code, _semesterCode);
    expect(semester.name, '2026-2027 秋季学期');
    expect(semester.startsOn, const LocalDate(2026, 9, 14));
    expect(semester.totalWeeks, 20);
    expect(semester.isCurrent, isTrue);

    final lessons = await store.lessonsBetween(
      const LocalDate(2026, 9, 14),
      const LocalDate(2026, 9, 21),
    );
    expect(lessons, hasLength(1));
    final lesson = lessons.single;
    expect(lesson.title, '示例课程');
    expect(lesson.startsAtUtc, DateTime.utc(2026, 9, 16, 1, 10));
    expect(lesson.endsAtUtc, DateTime.utc(2026, 9, 16, 2, 50));
    expect(lesson.location, '示例教室');
    expect(lesson.periodStart, 1);
    expect(lesson.periodEnd, 2);

    final details = await store.lessonDetailsBetween(
      semester.id,
      const LocalDate(2026, 9, 14),
      const LocalDate(2026, 9, 21),
    );
    expect(details.single.teacher, '示例教师');
    expect(details.single.weekNumber, 1);
    expect(details.single.weekday, 3);

    expect(await store.periodTimes(), hasLength(3));
    expect(await store.warningsForSemester(semester.id), isEmpty);

    final snapshot = await store.snapshotForSemester(_semesterCode);
    expect(snapshot.lastSuccessAtUtc, _now);
    expect(snapshot.lastErrorCode, isNull);
    expect((await store.semesterSnapshot()).lastSuccessAtUtc, _now);

    final offerings = await courses.list(source: teachingSource);
    expect(offerings, hasLength(1));
    expect(offerings.single.name, '示例课程');
    expect(offerings.single.teacher, '示例教师');
    expect(offerings.single.semesterId, semester.id);
  });

  test('a real database file keeps teaching data across reopen', () async {
    final path = await createTempDatabasePath();
    final first = await openTempFileDatabase(path);
    final firstStore = TeachingStore(
      first,
      'user-a',
      SourceSnapshotStore(first, 'user-a'),
      CourseStore(first, 'user-a', now: () => _now),
      now: () => _now,
    );
    final http = teachingHttp();
    _value(await firstStore.syncCurrentSemester(http: http));
    _value(
      await firstStore.refreshSemester(http: http, semesterCode: _semesterCode),
    );
    await first.close();

    final reopened = await openTempFileDatabase(path);
    addTearDown(reopened.close);
    final reopenedStore = TeachingStore(
      reopened,
      'user-a',
      SourceSnapshotStore(reopened, 'user-a'),
      CourseStore(reopened, 'user-a', now: () => _now),
      now: () => _now,
    );
    final semesters = await reopenedStore.listSemesters();
    expect(semesters.single.code, _semesterCode);
    final lessons = await reopenedStore.lessonsBetween(
      const LocalDate(2026, 9, 14),
      const LocalDate(2026, 9, 21),
    );
    expect(lessons.single.title, '示例课程');
    expect(
      (await reopenedStore.snapshotForSemester(_semesterCode)).lastSuccessAtUtc,
      _now,
    );
  });

  test('two users never see each other timetable', () async {
    final otherSnapshots = SourceSnapshotStore(database, 'user-b');
    final otherCourses = CourseStore(database, 'user-b', now: () => _now);
    final otherStore = TeachingStore(
      database,
      'user-b',
      otherSnapshots,
      otherCourses,
      now: () => _now,
    );

    await syncSemester(teachingHttp());

    expect(await otherStore.listSemesters(), isEmpty);
    expect(
      await otherStore.lessonsBetween(
        const LocalDate(2026, 9, 14),
        const LocalDate(2026, 9, 21),
      ),
      isEmpty,
    );
    expect(
      (await otherStore.snapshotForSemester(_semesterCode)).lastSuccessAtUtc,
      isNull,
    );
    expect(await otherCourses.list(source: teachingSource), isEmpty);
    _value(await otherStore.syncCurrentSemester(http: teachingHttp()));
    _value(
      await otherStore.refreshSemester(
        http: teachingHttp(),
        semesterCode: _semesterCode,
      ),
    );
    final firstLessons = await store.lessonsBetween(
      const LocalDate(2026, 9, 14),
      const LocalDate(2026, 9, 21),
    );
    final otherLessons = await otherStore.lessonsBetween(
      const LocalDate(2026, 9, 14),
      const LocalDate(2026, 9, 21),
    );
    expect(firstLessons, hasLength(1));
    expect(otherLessons, hasLength(1));
    expect(otherLessons.single.id, isNot(firstLessons.single.id));
    expect(
      otherLessons.single.courseOfferingId,
      isNot(firstLessons.single.courseOfferingId),
    );
    _value(
      await store.refreshSemester(
        http: teachingHttp(),
        semesterCode: _semesterCode,
      ),
    );
    expect(
      (await store.lessonsBetween(
        const LocalDate(2026, 9, 14),
        const LocalDate(2026, 9, 21),
      )).single.id,
      firstLessons.single.id,
    );
  });

  test('failure keeps the cached timetable and records the error', () async {
    final http = teachingHttp();
    await syncSemester(http);
    final before = await store.lessonsBetween(
      const LocalDate(2026, 9, 14),
      const LocalDate(2026, 9, 21),
    );

    final failed = await store.refreshSemester(
      http: teachingHttp(unauthorized: true),
      semesterCode: _semesterCode,
    );
    expect(failed, isA<SourceFailed<Object?>>());
    final failure = failed as SourceFailed<Object?>;
    expect(failure.failure.code, SourceErrorCodes.sourceAuthRequired);
    expect(failure.hasCachedData, isTrue);

    final after = await store.lessonsBetween(
      const LocalDate(2026, 9, 14),
      const LocalDate(2026, 9, 21),
    );
    expect(after.single.id, before.single.id);
    final snapshot = await store.snapshotForSemester(_semesterCode);
    expect(snapshot.lastSuccessAtUtc, _now);
    expect(snapshot.lastAttemptAtUtc, _now);
    expect(snapshot.lastErrorCode, SourceErrorCodes.sourceAuthRequired);
  });

  test('a required endpoint failure never replaces the snapshot', () async {
    await syncSemester(teachingHttp());
    final failed = await store.refreshSemester(
      http: teachingHttp(failCourses: true),
      semesterCode: _semesterCode,
    );
    expect(failed, isA<SourceFailed<Object?>>());
    expect(
      (failed as SourceFailed<Object?>).failure.code,
      SourceErrorCodes.sourceUnavailable,
    );
    expect(
      await store.lessonsBetween(
        const LocalDate(2026, 9, 14),
        const LocalDate(2026, 9, 21),
      ),
      hasLength(1),
    );
  });

  test(
    'a malformed payload is a protocol failure that keeps the cache',
    () async {
      await syncSemester(teachingHttp());
      final routes = Map<String, SourceResponse Function()>.of(
        Map<String, SourceResponse Function()>.from(teachingHttp().routes),
      );
      routes['cxxszhxqkb.do'] = () => const SourceResponse(
        statusCode: 200,
        body: '{"code":"0","datas":{"cxxszhxqkb":{"rows":[{"KCM":"缺少时间"}]}}}',
      );
      final failed = await store.refreshSemester(
        http: FakeSourceHttp(routes),
        semesterCode: _semesterCode,
      );
      expect(failed, isA<SourceFailed<Object?>>());
      final failure = failed as SourceFailed<Object?>;
      expect(failure.failure.code, SourceErrorCodes.sourceProtocol);
      expect(failure.failure.message, contains('字段'));
      expect(
        await store.lessonsBetween(
          const LocalDate(2026, 9, 14),
          const LocalDate(2026, 9, 21),
        ),
        hasLength(1),
      );
    },
  );

  test(
    'optional change failure still updates the timetable and warns',
    () async {
      await syncSemester(teachingHttp(failChanges: true));
      final semester = (await store.listSemesters()).single;
      expect(
        await store.warningsForSemester(semester.id),
        contains('调停课信息未获取，请对照教务原课表核查临时调整'),
      );
      expect(
        await store.lessonsBetween(
          const LocalDate(2026, 9, 14),
          const LocalDate(2026, 9, 21),
        ),
        hasLength(1),
      );
    },
  );

  test(
    'a complete refresh removes occurrences and courses that disappeared',
    () async {
      await syncSemester(
        teachingHttp(
          courses: <Map<String, Object?>>[
            teachingCourse(kbId: 'keep-course', courseCode: 'KEEP'),
            teachingCourse(
              kbId: 'drop-course',
              courseCode: 'DROP',
              weekday: '4',
            ),
          ],
        ),
      );
      expect(
        await store.lessonsBetween(
          const LocalDate(2026, 9, 14),
          const LocalDate(2026, 9, 21),
        ),
        hasLength(2),
      );

      _value(
        await store.refreshSemester(
          http: teachingHttp(
            courses: <Map<String, Object?>>[
              teachingCourse(kbId: 'keep-course', courseCode: 'KEEP'),
            ],
          ),
          semesterCode: _semesterCode,
        ),
      );
      final lessons = await store.lessonsBetween(
        const LocalDate(2026, 9, 14),
        const LocalDate(2026, 9, 21),
      );
      expect(lessons.single.title, '示例课程');
      expect(
        (await courses.list(
          source: teachingSource,
        )).map((offering) => offering.sourceRef.sourceId),
        <String>['keep-course'],
      );
    },
  );

  test('saves rescheduled occurrences with their adjustment note', () async {
    await syncSemester(
      teachingHttp(
        courses: <Map<String, Object?>>[
          teachingCourse(weekday: '1', weekMask: '11'),
        ],
        changes: <Map<String, Object?>>[
          <String, Object?>{
            'KBID': 'demo-course',
            'SKZC': '10',
            'XSKZC': '01',
            'XSKXQ': '5',
            'XKSJC': '3',
            'XJSJC': '3',
            'XJASMC': '新教室',
          },
        ],
      ),
    );
    final semester = (await store.listSemesters()).single;
    final secondWeek = await store.lessonDetailsBetween(
      semester.id,
      const LocalDate(2026, 9, 21),
      const LocalDate(2026, 9, 28),
    );
    expect(secondWeek, hasLength(2));
    final adjusted = secondWeek.singleWhere((detail) => detail.note == '教务调课');
    expect(adjusted.lesson.location, '新教室');
    expect(adjusted.weekday, 5);
    expect(adjusted.lesson.periodStart, 3);
  });

  test(
    'keeps equally named courses separate when their source ids differ',
    () async {
      await syncSemester(
        teachingHttp(
          courses: <Map<String, Object?>>[
            teachingCourse(kbId: 'course-a', courseCode: 'A'),
            teachingCourse(kbId: 'course-b', courseCode: 'B'),
          ],
        ),
      );
      final offerings = await courses.list(source: teachingSource);
      expect(offerings, hasLength(2));
      expect(
        offerings.map((offering) => offering.sourceRef.sourceId).toSet(),
        <String>{'course-a', 'course-b'},
      );
    },
  );

  test(
    'moves the current flag when the school current semester changes',
    () async {
      await syncSemester(teachingHttp());
      _value(
        await store.syncCurrentSemester(
          http: teachingHttp(semesterCode: '2026-2027-2'),
        ),
      );
      final semesters = await store.listSemesters();
      expect(semesters, hasLength(2));
      final current = semesters.where((semester) => semester.isCurrent);
      expect(current.single.code, '2026-2027-2');
      expect(
        semesters
            .firstWhere((semester) => semester.code == _semesterCode)
            .isCurrent,
        isFalse,
      );
    },
  );

  test('uses the injected source context when no client is passed', () async {
    final http = teachingHttp();
    final injected = TeachingStore(
      database,
      'user-a',
      snapshots,
      courses,
      source: SourceContext(
        sessions: SourceSessionRegistry(),
        http: http,
        campusLogin: FakeCampusLogin(),
        browser: const UnsupportedSourcePageOpener(),
      ),
      now: () => _now,
    );
    _value(await injected.syncCurrentSemester());
    _value(await injected.refreshSemester(semesterCode: _semesterCode));
    expect(await injected.listSemesters(), hasLength(1));
    expect(http.requests, isNotEmpty);
  });

  test('lessonsBetween only returns overlapping campus dates', () async {
    await syncSemester(teachingHttp());
    expect(
      await store.lessonsBetween(
        const LocalDate(2026, 9, 16),
        const LocalDate(2026, 9, 17),
      ),
      hasLength(1),
    );
    expect(
      await store.lessonsBetween(
        const LocalDate(2026, 9, 17),
        const LocalDate(2026, 9, 18),
      ),
      isEmpty,
    );
  });
}
