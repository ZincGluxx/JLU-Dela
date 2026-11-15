import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/local_migrations.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/storage/course_store.dart';
import 'package:jlu_dela/core/storage/source_snapshot_store.dart';
import 'package:jlu_dela/core/source/source.dart';
import 'package:jlu_dela/features/teaching/teaching_store.dart';
import 'package:jlu_dela/features/assignments/course_binding_store.dart';

import 'support/local_database_test_support.dart';
import 'teaching_test_support.dart';

void main() {
  test(
    'binds the course reference produced by the existing teaching pipeline',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final courses = CourseStore(database, 'user-a');
      final teaching = TeachingStore(
        database,
        'user-a',
        SourceSnapshotStore(database, 'user-a'),
        courses,
      );
      final result = await teaching.refreshSemester(
        http: teachingHttp(),
        semesterCode: '2026-2027-1',
      );
      expect(result, isA<SourceSuccess>());
      final target = (await courses.list(source: SourceKind.jluIedu)).single;
      final semester = (await teaching.listSemesters()).single;
      final platform = await courses.upsert(
        const SourceCourse(
          source: SourceKind.chaoxing,
          sourceScope: 'default',
          sourceId: '100:200',
          name: '来源不同名',
        ),
      );
      final bindings = CourseBindingStore(database, 'user-a', courses);
      await bindings.bind(
        platformCourseId: platform.id,
        teachingCourseId: target.id,
      );
      final saved = (await bindings.list()).single;
      expect(saved.semesterId, semester.id);
      expect(saved.teachingCourse.sourceScope, semester.code);
      expect(saved.teachingCourse.sourceId, target.sourceRef.sourceId);
      expect(saved.matchesTeaching(target), isTrue);
    },
  );
  test(
    'v32 upgrade preserves personal rows and bindings survive disk reopen',
    () async {
      final path = await createTempDatabasePath();
      final old = await openTempFileDatabase(
        path,
        migrations: appLocalMigrations
            .where((item) => item.version <= 32)
            .toList(),
      );
      expect(old.schemaVersion, 32);
      final courses = CourseStore(old, 'user-a');
      final platform = await courses.upsert(
        const SourceCourse(
          source: SourceKind.chaoxing,
          sourceScope: 'default',
          sourceId: '100:200',
          name: '同名课程',
        ),
      );
      final teaching = await courses.upsert(
        const SourceCourse(
          source: SourceKind.jluIedu,
          sourceScope: '2026-2027-1',
          sourceId: 'kb-1',
          semesterId: 'teaching:user-a:2026-2027-1',
          name: '同名课程',
        ),
      );
      await old.database.insert('app_meta', {
        'key': 'sentinel',
        'value': 'preserved',
      });
      await old.close();

      final upgraded = await openTempFileDatabase(path);
      expect(upgraded.schemaVersion, 33);
      expect(
        (await upgraded.database.query('app_meta')).single['value'],
        'preserved',
      );
      final bindings = CourseBindingStore(
        upgraded,
        'user-a',
        CourseStore(upgraded, 'user-a'),
      );
      await bindings.bind(
        platformCourseId: platform.id,
        teachingCourseId: teaching.id,
      );
      await upgraded.close();

      final reopened = await openTempFileDatabase(path);
      addTearDown(reopened.close);
      final saved = (await CourseBindingStore(
        reopened,
        'user-a',
        CourseStore(reopened, 'user-a'),
      ).list()).single;
      expect(saved.teachingCourseOfferingId, teaching.id);
      expect(saved.teachingCourse.sourceId, 'kb-1');
      expect(saved.semesterId, 'teaching:user-a:2026-2027-1');
      expect(saved.matchesPlatform(platform), isTrue);
      expect(saved.matchesTeaching(teaching), isTrue);
      final columns = await reopened.database.rawQuery(
        'PRAGMA table_info(platform_course_bindings)',
      );
      expect(columns.map((row) => row['name']), isNot(contains('cookie')));
      expect(
        await reopened.database.rawQuery('PRAGMA foreign_key_check'),
        isEmpty,
      );
    },
  );

  test(
    'explicit IDs separate same names, semesters and accounts; rebind and unbind are local',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final courses = CourseStore(database, 'user-a');
      final bindings = CourseBindingStore(database, 'user-a', courses);
      final platform = await courses.upsert(
        const SourceCourse(
          source: SourceKind.chaoxing,
          sourceScope: 'default',
          sourceId: '100:200',
          name: '同名课程',
        ),
      );
      final platformTwo = await courses.upsert(
        const SourceCourse(
          source: SourceKind.chaoxing,
          sourceScope: 'default',
          sourceId: '101:200',
          name: '同名课程',
        ),
      );
      final teaching = await courses.upsert(
        const SourceCourse(
          source: SourceKind.jluIedu,
          sourceScope: '2026-2027-1',
          sourceId: 'kb-1',
          semesterId: 'term-1',
          name: '同名课程',
        ),
      );
      final later = await courses.upsert(
        const SourceCourse(
          source: SourceKind.jluIedu,
          sourceScope: '2026-2027-2',
          sourceId: 'kb-1',
          semesterId: 'term-2',
          name: '同名课程',
        ),
      );
      expect(await bindings.list(), isEmpty);
      await bindings.bind(
        platformCourseId: platform.id,
        teachingCourseId: teaching.id,
      );
      var saved = (await bindings.list()).single;
      expect(saved.matchesPlatform(platformTwo), isFalse);
      expect(saved.matchesTeaching(later), isFalse);
      await bindings.bind(
        platformCourseId: platform.id,
        teachingCourseId: later.id,
      );
      saved = (await bindings.list()).single;
      expect(saved.matchesTeaching(later), isTrue);
      expect(saved.matchesTeaching(teaching), isFalse);

      final otherCourses = CourseStore(database, 'user-b');
      final other = CourseBindingStore(database, 'user-b', otherCourses);
      final otherTeaching = await otherCourses.upsert(
        const SourceCourse(
          source: SourceKind.jluIedu,
          sourceScope: '2026-2027-1',
          sourceId: 'kb-1',
          semesterId: 'other-term',
          name: '同名课程',
        ),
      );
      expect(await other.list(), isEmpty);
      await expectLater(
        other.bind(
          platformCourseId: platform.id,
          teachingCourseId: otherTeaching.id,
        ),
        throwsStateError,
      );
      await expectLater(
        bindings.bind(
          platformCourseId: platform.id,
          teachingCourseId: otherTeaching.id,
        ),
        throwsStateError,
      );
      await other.unbind(platform.sourceRef);
      expect(await bindings.list(), hasLength(1));
      expect((await courses.byId(platform.id))!.semesterId, isNull);
      await bindings.unbind(platform.sourceRef);
      expect(await bindings.list(), isEmpty);
      expect(await courses.list(), hasLength(4));
    },
  );

  test(
    'missing snapshots preserve personal mapping and resolve only the original identity',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final courses = CourseStore(database, 'user-a');
      final bindings = CourseBindingStore(database, 'user-a', courses);
      const platformSource = SourceCourse(
        source: SourceKind.chaoxing,
        sourceScope: 'default',
        sourceId: '100:200',
        name: '课程',
      );
      const teachingSource = SourceCourse(
        source: SourceKind.jluIedu,
        sourceScope: '2026-2027-1',
        sourceId: 'kb-1',
        semesterId: 'term-1',
        name: '课程',
      );
      final platform = await courses.upsert(platformSource);
      final teaching = await courses.upsert(teachingSource);
      await bindings.bind(
        platformCourseId: platform.id,
        teachingCourseId: teaching.id,
      );
      await courses.applySnapshot(
        source: SourceKind.jluIedu,
        scope: '2026-2027-1',
        courses: const [],
        complete: true,
      );
      await courses.applySnapshot(
        source: SourceKind.chaoxing,
        scope: 'default',
        courses: const [],
        complete: true,
      );
      final saved = (await bindings.list()).single;
      final newPlatform = await courses.upsert(platformSource);
      final newTeaching = await courses.upsert(teachingSource);
      expect(newPlatform.id, isNot(platform.id));
      expect(newTeaching.id, isNot(teaching.id));
      expect(saved.matchesPlatform(newPlatform), isTrue);
      expect(saved.matchesTeaching(newTeaching), isTrue);
      newTeaching.semesterId = 'term-changed';
      expect(saved.matchesTeaching(newTeaching), isFalse);
    },
  );

  test(
    'rejects missing semesters and non-teaching targets without creating mappings',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);
      final courses = CourseStore(database, 'user-a');
      final bindings = CourseBindingStore(database, 'user-a', courses);
      final platform = await courses.upsert(
        const SourceCourse(
          source: SourceKind.chaoxing,
          sourceScope: 'default',
          sourceId: '100:200',
          name: '课程',
        ),
      );
      final incomplete = await courses.upsert(
        const SourceCourse(
          source: SourceKind.jluIedu,
          sourceScope: 'term',
          sourceId: 'kb-1',
          name: '课程',
        ),
      );
      await expectLater(
        bindings.bind(
          platformCourseId: platform.id,
          teachingCourseId: incomplete.id,
        ),
        throwsStateError,
      );
      await expectLater(
        bindings.bind(
          platformCourseId: platform.id,
          teachingCourseId: platform.id,
        ),
        throwsStateError,
      );
      await expectLater(
        bindings.bind(
          platformCourseId: incomplete.id,
          teachingCourseId: incomplete.id,
        ),
        throwsStateError,
      );
      expect(await bindings.list(), isEmpty);
    },
  );
}
