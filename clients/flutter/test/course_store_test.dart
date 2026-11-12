import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/storage/course_store.dart';
import 'package:jlu_dela/core/storage/local_database.dart';

import 'support/local_database_test_support.dart';

void main() {
  late LocalDatabase database;
  late CourseStore store;

  setUp(() async {
    database = await openTestDatabase();
    store = CourseStore(database, 'user-a');
  });

  tearDown(() => database.close());

  SourceCourse course({
    SourceKind source = SourceKind.jluIedu,
    String scope = '2026-fall',
    String sourceId = 'course-1',
    String name = '高等数学',
    String? teacher = '张老师',
    String? semesterId = 'semester-1',
  }) {
    return SourceCourse(
      source: source,
      sourceScope: scope,
      sourceId: sourceId,
      name: name,
      teacher: teacher,
      semesterId: semesterId,
    );
  }

  test('upsert is keyed by source identity, never by name', () async {
    final first = await store.upsert(course());
    final sameKey = await store.upsert(course(name: '高等数学 A'));
    final otherSource = await store.upsert(
      course(source: SourceKind.chaoxing, sourceId: 'chaoxing-1'),
    );
    final otherScope = await store.upsert(
      course(source: SourceKind.chaoxing, sourceId: 'chaoxing-2'),
    );

    expect(sameKey.id, first.id);
    expect(sameKey.name, '高等数学 A');
    expect(otherSource.id, isNot(first.id));
    expect(otherScope.id, isNot(first.id));
    expect(otherScope.id, isNot(otherSource.id));
    expect(await store.list(), hasLength(3));
  });

  test('upsert preserves user preferences', () async {
    final created = await store.upsert(course());
    await store.updatePreferences(created.id, remark: '我的备注', retained: false);

    final updated = await store.upsert(course(name: '高数（新）'));

    expect(updated.id, created.id);
    expect(updated.name, '高数（新）');
    expect(updated.remark, '我的备注');
    expect(updated.retained, isFalse);

    final cleared = await store.updatePreferences(
      created.id,
      clearRemark: true,
    );
    expect(cleared.remark, isNull);
    expect(cleared.retained, isFalse);
  });

  test(
    'a complete snapshot removes unseen courses only in its scope',
    () async {
      await store.upsert(course(sourceId: 'keep', name: '保留'));
      await store.upsert(course(sourceId: 'drop', name: '删除'));
      await store.upsert(course(scope: '2026-spring', sourceId: 'keep'));
      await store.upsert(
        course(source: SourceKind.chaoxing, sourceId: 'chaoxing-keep'),
      );

      await store.applySnapshot(
        source: SourceKind.jluIedu,
        scope: '2026-fall',
        complete: true,
        courses: [course(sourceId: 'keep', name: '保留')],
      );

      final teachingCourses = await store.list(source: SourceKind.jluIedu);
      expect(teachingCourses, hasLength(2));
      expect(
        teachingCourses
            .where((offering) => offering.sourceRef.sourceScope == '2026-fall')
            .map((offering) => offering.sourceRef.sourceId),
        ['keep'],
      );
      expect(
        teachingCourses.where(
          (offering) => offering.sourceRef.sourceScope == '2026-spring',
        ),
        hasLength(1),
      );
      expect(await store.list(source: SourceKind.chaoxing), hasLength(1));
    },
  );

  test('a complete empty snapshot clears its scope', () async {
    await store.upsert(course(sourceId: 'a'));
    await store.upsert(course(scope: '2026-spring', sourceId: 'b'));

    await store.applySnapshot(
      source: SourceKind.jluIedu,
      scope: '2026-fall',
      complete: true,
      courses: const [],
    );

    expect(
      (await store.list(
        source: SourceKind.jluIedu,
      )).map((offering) => offering.sourceRef.sourceScope),
      ['2026-spring'],
    );
  });

  test('a partial snapshot only upserts', () async {
    await store.upsert(course(sourceId: 'existing', name: '旧课程'));

    await store.applySnapshot(
      source: SourceKind.jluIedu,
      scope: '2026-fall',
      complete: false,
      courses: [
        course(sourceId: 'existing', name: '旧课程'),
        course(sourceId: 'new', name: '新课程'),
      ],
    );

    expect(await store.list(), hasLength(2));
  });

  test('lists by source and retention', () async {
    final retained = await store.upsert(course(sourceId: 'a', name: 'A'));
    final hidden = await store.upsert(course(sourceId: 'b', name: 'B'));
    await store.updatePreferences(hidden.id, retained: false);

    expect((await store.list(retained: true)).map((offering) => offering.id), [
      retained.id,
    ]);
    expect((await store.list(retained: false)).map((offering) => offering.id), [
      hidden.id,
    ]);
    expect(await store.list(source: SourceKind.chaoxing), isEmpty);
  });

  test('two users never see each other courses', () async {
    final other = CourseStore(database, 'user-b');
    final mine = await store.upsert(course());
    await other.upsert(course(sourceId: 'other-course', name: '别人的课'));

    expect((await store.list()).map((offering) => offering.id), [mine.id]);
    expect((await other.list()).single.sourceRef.sourceId, 'other-course');
  });
}
