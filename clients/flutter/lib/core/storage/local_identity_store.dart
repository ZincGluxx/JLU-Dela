import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'local_database.dart';

class CachedIdentity {
  const CachedIdentity({
    required this.userId,
    required this.displayName,
    required this.timezone,
    required this.verifiedAtUtc,
    required this.lastUsedAtUtc,
  });

  final String userId;
  final String displayName;
  final String timezone;

  /// Last server confirmation of the application account, not student identity.
  final DateTime verifiedAtUtc;
  final DateTime lastUsedAtUtc;
}

class LocalIdentityStore {
  LocalIdentityStore(LocalDatabase database) : _database = database.database;

  static const _lastUserIdKey = 'last_user_id';

  final Database _database;

  Future<CachedIdentity?> lastUsed() async {
    final meta = await _database.query(
      'app_meta',
      where: 'key = ?',
      whereArgs: [_lastUserIdKey],
      limit: 1,
    );
    if (meta.isEmpty) {
      return null;
    }
    final userId = meta.first['value'] as String;
    final rows = await _database.query(
      'local_identity',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isEmpty ? null : _identityFromRow(rows.first);
  }

  /// Caches an application account confirmed by /me; grants no access rights.
  Future<void> recordVerified({
    required String userId,
    required String displayName,
    required String timezone,
    required DateTime verifiedAt,
  }) async {
    final verifiedAtUtc = verifiedAt.toUtc().millisecondsSinceEpoch;
    final lastUsedAtUtc = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _database.transaction((transaction) async {
      await transaction.insert('local_identity', {
        'user_id': userId,
        'display_name': displayName,
        'timezone': timezone,
        'verified_at_utc': verifiedAtUtc,
        'last_used_at_utc': lastUsedAtUtc,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await transaction.insert('app_meta', {
        'key': _lastUserIdKey,
        'value': userId,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  CachedIdentity _identityFromRow(Map<String, Object?> row) {
    return CachedIdentity(
      userId: row['user_id'] as String,
      displayName: row['display_name'] as String,
      timezone: row['timezone'] as String,
      verifiedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        row['verified_at_utc'] as int,
        isUtc: true,
      ),
      lastUsedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        row['last_used_at_utc'] as int,
        isUtc: true,
      ),
    );
  }
}
