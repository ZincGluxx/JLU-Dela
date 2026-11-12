import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/local_migrations.dart';
import 'package:jlu_dela/core/storage/local_database.dart';

void main() {
  test('内容迁移创建通知与资料表，schema 版本包含 v20-23', () async {
    final database = await LocalDatabase.openInMemory(
      migrations: appLocalMigrations,
    );
    addTearDown(database.close);

    expect(database.schemaVersion, 23);
    final tables = (await database.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    )).map((row) => row['name'] as String).toSet();
    expect(
      tables,
      containsAll(<String>[
        'notices',
        'notice_attachments',
        'notice_scopes',
        'materials',
        'material_scopes',
      ]),
    );
    final version = await database.database.rawQuery('PRAGMA user_version');
    expect(version.first['user_version'], 23);
  });

  test('重启后通知与资料缓存仍属于原用户', () async {
    final directory = await Directory.systemTemp.createTemp('dela-content-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}dela.db';
    final timestamp = DateTime.utc(2026, 11, 8).millisecondsSinceEpoch;

    final first = await LocalDatabase.open(
      path: path,
      migrations: appLocalMigrations,
    );
    await first.database.insert('notices', <String, Object?>{
      'id': 'notice-row-1',
      'user_id': 'user-a',
      'source_scope': '179577',
      'source_id': '1001',
      'title': '示例通知',
      'pinned': 0,
      'observed_at_utc': timestamp,
    });
    await first.database.insert('course_offerings', <String, Object?>{
      'id': 'course-row-1',
      'user_id': 'user-a',
      'source': 'chaoxing',
      'source_scope': 'sample-account',
      'source_id': 'course-1',
      'name': '示例课程',
      'retained': 1,
      'created_at_utc': timestamp,
      'updated_at_utc': timestamp,
    });
    await first.database.insert('materials', <String, Object?>{
      'id': 'material-row-1',
      'user_id': 'user-a',
      'course_offering_id': 'course-row-1',
      'parent_key': '',
      'source_scope': 'sample-account',
      'source_id': 'file-1',
      'name': '示例资料.pdf',
      'kind': 'file',
      'bytes': 1024,
      'downloadable': 1,
      'position': 0,
      'observed_at_utc': timestamp,
    });
    await first.close();

    final reopened = await LocalDatabase.open(
      path: path,
      migrations: appLocalMigrations,
    );
    addTearDown(reopened.close);
    expect(reopened.schemaVersion, 23);
    final notices = await reopened.database.query('notices');
    expect(notices, hasLength(1));
    expect(notices.single['user_id'], 'user-a');
    expect(notices.single['title'], '示例通知');
    final materials = await reopened.database.query('materials');
    expect(materials, hasLength(1));
    expect(materials.single['name'], '示例资料.pdf');
  });

  test('数据库版本高于代码支持版本时拒绝打开', () async {
    final directory = await Directory.systemTemp.createTemp('dela-content-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}dela.db';
    final database = await LocalDatabase.open(
      path: path,
      migrations: appLocalMigrations,
    );
    await database.database.execute('PRAGMA user_version = 99');
    await database.close();

    await expectLater(
      LocalDatabase.open(path: path, migrations: appLocalMigrations),
      throwsA(isA<LocalSchemaTooNewException>()),
    );
  });

  test('迁移中途失败回滚，不留下半套内容 schema', () async {
    final directory = await Directory.systemTemp.createTemp('dela-content-');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}dela.db';
    final broken = <LocalMigration>[
      ...appLocalMigrations,
      const LocalMigration(24, <String>[
        'CREATE TABLE broken_table(',
        'CREATE TABLE should_not_exist(id TEXT)',
      ]),
    ];
    await expectLater(
      LocalDatabase.open(path: path, migrations: broken),
      throwsA(anything),
    );

    final recovered = await LocalDatabase.open(
      path: path,
      migrations: appLocalMigrations,
    );
    addTearDown(recovered.close);
    expect(recovered.schemaVersion, 23);
    final tables = (await recovered.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    )).map((row) => row['name'] as String).toSet();
    expect(tables, isNot(contains('should_not_exist')));
  });
}
