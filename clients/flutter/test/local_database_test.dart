import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/local_migrations.dart';
import 'package:jlu_dela/core/storage/core_migrations.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/local_database_test_support.dart';

void main() {
  test(
    'an empty database is created at the aggregate schema version',
    () async {
      final database = await openTestDatabase();
      addTearDown(database.close);

      final expectedVersion = appLocalMigrations.last.version;
      expect(database.schemaVersion, expectedVersion);
      final version = await database.database.rawQuery('PRAGMA user_version');
      expect(version.single['user_version'], expectedVersion);
      final foreignKeys = await database.database.rawQuery(
        'PRAGMA foreign_keys',
      );
      expect(foreignKeys.single['foreign_keys'], 1);

      final tables = await database.database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
      );
      final names = tables.map((row) => row['name']).toSet();
      expect(
        names,
        containsAll([
          'app_meta',
          'local_identity',
          'todos',
          'course_offerings',
          'source_snapshots',
          'local_drafts',
        ]),
      );

      final indexes = await database.database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index'",
      );
      expect(indexes.map((row) => row['name']), contains('todos_user_due'));
    },
  );

  test('aggregate migrations are unique, increasing and include core v1', () {
    // 版本区间：1 CORE；2–9 教务；10–19 学习通；20–29 内容；30–39 预留。
    final versions = appLocalMigrations
        .map((migration) => migration.version)
        .toList();

    expect(versions, isNotEmpty);
    expect(versions.toSet(), hasLength(versions.length));
    expect(versions, containsAll(coreMigrations.map((m) => m.version)));
    for (var index = 1; index < versions.length; index++) {
      expect(versions[index], greaterThan(versions[index - 1]));
    }
  });

  test('upgrading keeps existing rows and adds new schema', () async {
    final path = await createTempDatabasePath();
    final first = await openTempFileDatabase(path, migrations: coreMigrations);
    await first.database.insert('app_meta', {
      'key': 'last_user_id',
      'value': 'user-a',
    });
    await first.close();

    final upgraded = await openTempFileDatabase(
      path,
      migrations: const [
        ...coreMigrations,
        LocalMigration(2, ['CREATE TABLE feature_v2(id TEXT PRIMARY KEY)']),
      ],
    );
    addTearDown(upgraded.close);

    expect(upgraded.schemaVersion, 2);
    final meta = await upgraded.database.query('app_meta');
    expect(meta.single['value'], 'user-a');
    final created = await upgraded.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'feature_v2'",
    );
    expect(created, hasLength(1));
  });

  test('a database newer than the application is refused', () async {
    final path = await createTempDatabasePath();
    final advanced = await openTempFileDatabase(
      path,
      migrations: const [
        ...coreMigrations,
        LocalMigration(2, ['CREATE TABLE feature_v2(id TEXT PRIMARY KEY)']),
      ],
    );
    await advanced.close();

    await expectLater(
      openTempFileDatabase(path, migrations: coreMigrations),
      throwsA(isA<LocalSchemaTooNewException>()),
    );
  });

  test('a later module can add migrations below the current version', () async {
    final path = await createTempDatabasePath();
    const content = LocalMigration(20, [
      'CREATE TABLE content_cache(id TEXT PRIMARY KEY)',
    ]);
    const teaching = LocalMigration(2, [
      'CREATE TABLE lesson_cache(id TEXT PRIMARY KEY)',
    ]);
    final first = await openTempFileDatabase(
      path,
      migrations: const [...coreMigrations, content],
    );
    await first.database.insert('content_cache', {'id': 'saved-notice'});
    await first.close();

    final upgraded = await openTempFileDatabase(
      path,
      migrations: const [...coreMigrations, teaching, content],
    );
    await upgraded.database.insert('lesson_cache', {'id': 'new-lesson'});
    expect(upgraded.schemaVersion, 20);
    expect(
      (await upgraded.database.query('content_cache')).single['id'],
      'saved-notice',
    );
    await upgraded.close();

    final reopened = await openTempFileDatabase(
      path,
      migrations: const [...coreMigrations, teaching, content],
    );
    addTearDown(reopened.close);
    expect(
      (await reopened.database.query('lesson_cache')).single['id'],
      'new-lesson',
    );
    expect(
      (await reopened.database.query(
        'local_migrations',
      )).map((row) => row['version']),
      unorderedEquals([1, 2, 20]),
    );
  });

  test(
    'legacy sparse databases retain rows and install missing modules',
    () async {
      final path = await createTempDatabasePath();
      final legacy = await databaseFactoryFfiNoIsolate.openDatabase(path);
      for (final statement in coreMigrations.single.statements) {
        await legacy.execute(statement);
      }
      await legacy.execute('CREATE TABLE content_cache(id TEXT PRIMARY KEY)');
      await legacy.insert('content_cache', {'id': 'saved-notice'});
      await legacy.insert('app_meta', {
        'key': 'last_user_id',
        'value': 'user-a',
      });
      await legacy.execute('PRAGMA user_version = 20');
      await legacy.close();

      final upgraded = await openTempFileDatabase(
        path,
        migrations: const [
          ...coreMigrations,
          LocalMigration(2, ['CREATE TABLE lesson_cache(id TEXT PRIMARY KEY)']),
          LocalMigration(10, [
            'CREATE TABLE assignment_cache(id TEXT PRIMARY KEY)',
          ]),
          LocalMigration(20, [
            'CREATE TABLE content_cache(id TEXT PRIMARY KEY)',
          ]),
        ],
      );
      addTearDown(upgraded.close);
      await upgraded.database.insert('lesson_cache', {'id': 'new-lesson'});
      await upgraded.database.insert('assignment_cache', {
        'id': 'new-assignment',
      });
      expect(upgraded.schemaVersion, 20);
      expect(
        (await upgraded.database.query('content_cache')).single['id'],
        'saved-notice',
      );
      expect(
        (await upgraded.database.query('app_meta')).single['value'],
        'user-a',
      );
    },
  );

  test('failed lower migrations are rolled back and can be retried', () async {
    final path = await createTempDatabasePath();
    const content = LocalMigration(20, [
      'CREATE TABLE content_cache(id TEXT PRIMARY KEY)',
    ]);
    final first = await openTempFileDatabase(
      path,
      migrations: const [...coreMigrations, content],
    );
    await first.close();

    await expectLater(
      openTempFileDatabase(
        path,
        migrations: const [
          ...coreMigrations,
          LocalMigration(2, [
            'CREATE TABLE lesson_cache(id TEXT PRIMARY KEY)',
            'CREATE TABLE lesson_cache(id TEXT PRIMARY KEY)',
          ]),
          content,
        ],
      ),
      throwsA(isA<DatabaseException>()),
    );
    final retried = await openTempFileDatabase(
      path,
      migrations: const [
        ...coreMigrations,
        LocalMigration(2, ['CREATE TABLE lesson_cache(id TEXT PRIMARY KEY)']),
        content,
      ],
    );
    addTearDown(retried.close);
    expect(retried.schemaVersion, 20);
    await retried.database.insert('lesson_cache', {'id': 'new-lesson'});
  });

  test('a failed migration rolls back and keeps the previous version', () async {
    final path = await createTempDatabasePath();
    const failing = LocalMigration(2, [
      'CREATE TABLE blocked(id TEXT PRIMARY KEY)',
      'CREATE TABLE blocked(id TEXT PRIMARY KEY)',
    ]);

    await expectLater(
      openTempFileDatabase(
        path,
        migrations: const [...coreMigrations, failing],
      ),
      throwsA(isA<DatabaseException>()),
    );

    final reopened = await openTempFileDatabase(
      path,
      migrations: coreMigrations,
    );
    addTearDown(reopened.close);
    expect(reopened.schemaVersion, 1);
    final blocked = await reopened.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'blocked'",
    );
    expect(blocked, isEmpty);
  });
}
