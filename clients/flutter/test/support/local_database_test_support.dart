import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/local_migrations.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<LocalDatabase> openTestDatabase({
  List<LocalMigration> migrations = appLocalMigrations,
}) {
  return LocalDatabase.openInMemory(migrations: migrations);
}

Future<LocalDatabase> openTempFileDatabase(
  String path, {
  List<LocalMigration> migrations = appLocalMigrations,
}) {
  return LocalDatabase.open(
    migrations: migrations,
    path: path,
    databaseFactory: databaseFactoryFfiNoIsolate,
  );
}

Future<String> createTempDatabasePath() async {
  final directory = await Directory.systemTemp.createTemp('jlu_dela_test');
  addTearDown(() => directory.delete(recursive: true));
  return p.join(directory.path, 'dela.db');
}
