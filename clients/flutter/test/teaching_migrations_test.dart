import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/storage/core_migrations.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
import 'package:jlu_dela/features/teaching/teaching_migrations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/local_database_test_support.dart';

const List<LocalMigration> teachingTestMigrations = [
  ...coreMigrations,
  ...teachingMigrations,
];

void main() {
  test('an empty database creates the teaching schema at version 6', () async {
    final database = await openTestDatabase(migrations: teachingTestMigrations);
    addTearDown(database.close);

    expect(database.schemaVersion, 6);
    final version = await database.database.rawQuery('PRAGMA user_version');
    expect(version.single['user_version'], 6);

    final tables = await database.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
    );
    expect(
      tables.map((row) => row['name']),
      containsAll(<String>[
        'teaching_semesters',
        'teaching_lessons',
        'teaching_period_times',
        'teaching_calendars',
        'teaching_parse_issues',
      ]),
    );
    final indexes = await database.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    );
    expect(
      indexes.map((row) => row['name']),
      containsAll(<String>[
        'teaching_lessons_user_range',
        'teaching_lessons_semester_range',
      ]),
    );
  });

  test('upgrading a v1 database keeps rows and adds teaching tables', () async {
    final path = await createTempDatabasePath();
    final first = await openTempFileDatabase(path, migrations: coreMigrations);
    await first.database.insert('app_meta', <String, Object?>{
      'key': 'last_user_id',
      'value': 'user-a',
    });
    await first.database.insert('local_identity', <String, Object?>{
      'user_id': 'user-a',
      'display_name': '示例用户',
      'timezone': 'Asia/Shanghai',
      'verified_at_utc': 1,
      'last_used_at_utc': 1,
    });
    await first.close();

    final upgraded = await openTempFileDatabase(
      path,
      migrations: teachingTestMigrations,
    );
    addTearDown(upgraded.close);

    expect(upgraded.schemaVersion, 6);
    final meta = await upgraded.database.query('app_meta');
    expect(meta.single['value'], 'user-a');
    final identity = await upgraded.database.query('local_identity');
    expect(identity.single['display_name'], '示例用户');
    final semesters = await upgraded.database.query('teaching_semesters');
    expect(semesters, isEmpty);
  });

  test('teaching rows cascade with their semester and course', () async {
    final database = await openTestDatabase(migrations: teachingTestMigrations);
    addTearDown(database.close);
    final db = database.database;
    await db.insert('course_offerings', <String, Object?>{
      'id': 'offering-1',
      'user_id': 'user-a',
      'source': 'jlu_iedu',
      'source_scope': '2026-2027-1',
      'source_id': 'course-1',
      'semester_id': 'semester-1',
      'name': '示例课程',
      'teacher': '示例教师',
      'remark': null,
      'retained': 1,
      'created_at_utc': 1,
      'updated_at_utc': 1,
    });
    await db.insert('teaching_semesters', <String, Object?>{
      'id': 'semester-1',
      'user_id': 'user-a',
      'source': 'jlu_iedu',
      'source_scope': 'semester',
      'source_id': '2026-2027-1',
      'name': '2026-2027 秋季学期',
      'is_current': 1,
      'last_observed_at_utc': 1,
      'created_at_utc': 1,
      'updated_at_utc': 1,
    });
    await db.insert('teaching_lessons', <String, Object?>{
      'id': 'lesson-1',
      'user_id': 'user-a',
      'semester_id': 'semester-1',
      'course_offering_id': 'offering-1',
      'title': '示例课程',
      'starts_at_utc': 1,
      'ends_at_utc': 2,
      'location': '示例教室',
      'period_start': 1,
      'period_end': 2,
      'weekday': 1,
      'week_number': 1,
      'source_lesson_id': 'course-1:0',
      'note': null,
      'created_at_utc': 1,
      'updated_at_utc': 1,
    });
    await db.insert('teaching_calendars', <String, Object?>{
      'user_id': 'user-a',
      'semester_id': 'semester-1',
      'starts_on': '2026-09-14',
      'total_weeks': 20,
      'observed_at_utc': 1,
    });
    await db.insert('teaching_parse_issues', <String, Object?>{
      'user_id': 'user-a',
      'semester_id': 'semester-1',
      'message': '示例警告',
      'observed_at_utc': 1,
    });

    await db.delete(
      'course_offerings',
      where: 'id = ?',
      whereArgs: ['offering-1'],
    );
    expect(await db.query('teaching_lessons'), isEmpty);
    expect(await db.query('teaching_calendars'), hasLength(1));

    await db.delete(
      'teaching_semesters',
      where: 'id = ?',
      whereArgs: ['semester-1'],
    );
    expect(await db.query('teaching_calendars'), isEmpty);
    expect(await db.query('teaching_parse_issues'), isEmpty);
  });

  test('a failing later migration rolls back teaching tables', () async {
    final path = await createTempDatabasePath();
    const failing = LocalMigration(7, <String>[
      'CREATE TABLE teaching_failure(id TEXT PRIMARY KEY)',
      'CREATE TABLE teaching_failure(id TEXT PRIMARY KEY)',
    ]);

    await expectLater(
      openTempFileDatabase(
        path,
        migrations: const <LocalMigration>[...teachingTestMigrations, failing],
      ),
      throwsA(isA<DatabaseException>()),
    );

    final reopened = await openTempFileDatabase(
      path,
      migrations: teachingTestMigrations,
    );
    addTearDown(reopened.close);
    expect(reopened.schemaVersion, 6);
    final blocked = await reopened.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name = 'teaching_failure'",
    );
    expect(blocked, isEmpty);
  });
}
