import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/local_migrations.dart';
import 'package:jlu_dela/core/models/source.dart';
import 'package:jlu_dela/core/storage/core_migrations.dart';
import 'package:jlu_dela/core/storage/course_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/local_database_test_support.dart';

void main() {
  test('v10 creates the assignments table, indexes and cascade', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);

    expect(database.schemaVersion, appLocalMigrations.last.version);
    final tables = await database.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    expect(tables.map((row) => row['name']), contains('assignments'));
    final indexes = await database.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    );
    expect(
      indexes.map((row) => row['name']),
      containsAll(['assignments_user_due', 'assignments_user_course']),
    );
    final foreignKeys = await database.database.rawQuery(
      'PRAGMA foreign_key_list(assignments)',
    );
    expect(foreignKeys.single['table'], 'course_offerings');
    expect(foreignKeys.single['on_delete'], 'CASCADE');
  });

  test('source identity is unique and due semantics are constrained', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    final courses = CourseStore(database, 'user-a');
    final offering = await courses.upsert(
      const SourceCourse(
        source: SourceKind.chaoxing,
        sourceScope: 'default',
        sourceId: '100:200',
        name: '示例课程',
      ),
    );

    Future<void> insert({
      String workId = 'work-1',
      String dueKind = 'exact',
      int? dueAt = 1000,
      String? dueDate,
    }) {
      return database.database.insert('assignments', {
        'id': 'assignment-$workId-$dueKind',
        'user_id': 'user-a',
        'course_offering_id': offering.id,
        'source_scope': 'default',
        'source_course_id': '100:200',
        'source_work_id': workId,
        'title': '示例作业',
        'source_status': 'not_submitted',
        'due_kind': dueKind,
        'due_date': dueDate,
        'due_at_utc': dueAt,
        'observed_at_utc': 1000,
        'created_at_utc': 1000,
        'updated_at_utc': 1000,
      });
    }

    await insert();
    expect(() => insert(), throwsA(isA<DatabaseException>()));
    expect(
      () => insert(workId: 'work-2', dueAt: null),
      throwsA(isA<DatabaseException>()),
    );
    expect(
      () => insert(
        workId: 'work-3',
        dueKind: 'date_only',
        dueAt: 1000,
        dueDate: '2026-11-05',
      ),
      throwsA(isA<DatabaseException>()),
    );
    await insert(
      workId: 'work-4',
      dueKind: 'date_only',
      dueAt: null,
      dueDate: '2026-11-05',
    );
    await insert(workId: 'work-5', dueKind: 'relative', dueAt: null);

    await database.database.delete(
      'course_offerings',
      where: 'id = ?',
      whereArgs: [offering.id],
    );
    expect(await database.database.query('assignments'), isEmpty);
  });

  test(
    'upgrading from the core schema keeps rows and adds assignments',
    () async {
      final path = await createTempDatabasePath();
      final first = await openTempFileDatabase(
        path,
        migrations: coreMigrations,
      );
      await first.database.insert('app_meta', {
        'key': 'last_user_id',
        'value': 'user-a',
      });
      final offering = await CourseStore(first, 'user-a').upsert(
        const SourceCourse(
          source: SourceKind.chaoxing,
          sourceScope: 'default',
          sourceId: '100:200',
          name: '示例课程',
        ),
      );
      await first.close();

      final upgraded = await openTempFileDatabase(path);
      addTearDown(upgraded.close);
      expect(upgraded.schemaVersion, appLocalMigrations.last.version);
      final meta = await upgraded.database.query('app_meta');
      expect(meta.single['value'], 'user-a');
      final courses = await upgraded.database.query('course_offerings');
      expect(courses.single['id'], offering.id);
      final tables = await upgraded.database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      expect(tables.map((row) => row['name']), contains('assignments'));
    },
  );
}
