import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class LocalMigration {
  const LocalMigration(this.version, this.statements);

  final int version;
  final List<String> statements;
}

class LocalSchemaTooNewException implements Exception {
  const LocalSchemaTooNewException({
    required this.databaseVersion,
    required this.supportedVersion,
  });

  final int databaseVersion;
  final int supportedVersion;

  @override
  String toString() {
    return 'LocalSchemaTooNewException(databaseVersion: $databaseVersion, '
        'supportedVersion: $supportedVersion)';
  }
}

class LocalDatabase {
  LocalDatabase._(this._database, this.schemaVersion);

  final Database _database;
  final int schemaVersion;

  Database get database => _database;

  static Future<LocalDatabase> open({
    required List<LocalMigration> migrations,
    String? path,
    DatabaseFactory? databaseFactory,
  }) async {
    sqfliteFfiInit();
    final factory = databaseFactory ?? databaseFactoryFfi;
    final resolvedPath = path ?? await _applicationDatabasePath();
    final database = await factory.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    try {
      final version = await _migrate(database, migrations);
      return LocalDatabase._(database, version);
    } on Object {
      await database.close();
      rethrow;
    }
  }

  static Future<LocalDatabase> openInMemory({
    required List<LocalMigration> migrations,
    DatabaseFactory? databaseFactory,
  }) {
    return open(
      migrations: migrations,
      path: inMemoryDatabasePath,
      databaseFactory: databaseFactory ?? databaseFactoryFfiNoIsolate,
    );
  }

  Future<void> close() => _database.close();

  static Future<String> _applicationDatabasePath() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'jlu_dela'));
    await directory.create(recursive: true);
    return p.join(directory.path, 'dela.db');
  }

  static Future<int> _migrate(
    Database database,
    List<LocalMigration> migrations,
  ) async {
    final ordered = [...migrations]
      ..sort((left, right) => left.version.compareTo(right.version));
    final supportedVersion = ordered.isEmpty ? 0 : ordered.last.version;
    final currentVersion = await _readUserVersion(database);
    if (currentVersion > supportedVersion) {
      throw LocalSchemaTooNewException(
        databaseVersion: currentVersion,
        supportedVersion: supportedVersion,
      );
    }

    var version = currentVersion;
    for (final migration in ordered) {
      if (migration.version <= version) {
        continue;
      }
      await database.transaction((transaction) async {
        for (final statement in migration.statements) {
          await transaction.execute(statement);
        }
        await transaction.execute('PRAGMA user_version = ${migration.version}');
      });
      version = migration.version;
    }
    return version;
  }

  static Future<int> _readUserVersion(Database database) async {
    final rows = await database.rawQuery('PRAGMA user_version');
    return rows.first['user_version'] as int;
  }
}
