import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/source.dart';
import 'local_database.dart';

class SourceSnapshotStore {
  SourceSnapshotStore(LocalDatabase database, this.userId)
    : _database = database.database;

  final Database _database;
  final String userId;

  Future<SourceSnapshot> read(
    SourceKind source,
    String resource, {
    String scopeKey = '',
  }) async {
    final rows = await _database.query(
      'source_snapshots',
      where: 'user_id = ? AND source = ? AND resource = ? AND scope_key = ?',
      whereArgs: [userId, source.databaseValue, resource, scopeKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      return SourceSnapshot(
        source: source,
        resource: resource,
        scopeKey: scopeKey,
      );
    }
    return _snapshotFromRow(rows.first);
  }

  Future<List<SourceSnapshot>> list() async {
    final rows = await _database.query(
      'source_snapshots',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'source, resource, scope_key',
    );
    return rows.map(_snapshotFromRow).toList();
  }

  Future<void> recordSuccess(
    SourceKind source,
    String resource, {
    String scopeKey = '',
    required DateTime observedAt,
  }) async {
    final timestamp = observedAt.toUtc().millisecondsSinceEpoch;
    await _database.rawInsert(
      '''
INSERT INTO source_snapshots(
  user_id, source, resource, scope_key,
  last_success_at_utc, last_attempt_at_utc, last_error_code, last_error_message
) VALUES (?, ?, ?, ?, ?, ?, NULL, NULL)
ON CONFLICT(user_id, source, resource, scope_key) DO UPDATE SET
  last_success_at_utc = excluded.last_success_at_utc,
  last_attempt_at_utc = excluded.last_attempt_at_utc,
  last_error_code = NULL,
  last_error_message = NULL
''',
      [userId, source.databaseValue, resource, scopeKey, timestamp, timestamp],
    );
  }

  Future<void> recordFailure(
    SourceKind source,
    String resource, {
    String scopeKey = '',
    required DateTime attemptedAt,
    required String code,
    String? message,
  }) async {
    await _database.rawInsert(
      '''
INSERT INTO source_snapshots(
  user_id, source, resource, scope_key,
  last_success_at_utc, last_attempt_at_utc, last_error_code, last_error_message
) VALUES (?, ?, ?, ?, NULL, ?, ?, ?)
ON CONFLICT(user_id, source, resource, scope_key) DO UPDATE SET
  last_attempt_at_utc = excluded.last_attempt_at_utc,
  last_error_code = excluded.last_error_code,
  last_error_message = excluded.last_error_message
''',
      [
        userId,
        source.databaseValue,
        resource,
        scopeKey,
        attemptedAt.toUtc().millisecondsSinceEpoch,
        code,
        message,
      ],
    );
  }

  SourceSnapshot _snapshotFromRow(Map<String, Object?> row) {
    final lastSuccessAtUtc = row['last_success_at_utc'] as int?;
    final lastAttemptAtUtc = row['last_attempt_at_utc'] as int?;
    return SourceSnapshot(
      source: SourceKind.fromDatabaseValue(row['source'] as String),
      resource: row['resource'] as String,
      scopeKey: row['scope_key'] as String,
      lastSuccessAtUtc: lastSuccessAtUtc == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastSuccessAtUtc, isUtc: true),
      lastAttemptAtUtc: lastAttemptAtUtc == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastAttemptAtUtc, isUtc: true),
      lastErrorCode: row['last_error_code'] as String?,
      lastErrorMessage: row['last_error_message'] as String?,
    );
  }
}
