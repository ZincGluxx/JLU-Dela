import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'local_database.dart';

class LocalDraftStore {
  LocalDraftStore(LocalDatabase database, this.userId)
    : _database = database.database;

  final Database _database;
  final String userId;

  Future<Map<String, dynamic>?> read(String scope, String key) async {
    final rows = await _database.query(
      'local_drafts',
      where: 'user_id = ? AND scope = ? AND key = ?',
      whereArgs: [userId, scope, key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(rows.first['payload'] as String) as Map;
    return decoded.cast<String, dynamic>();
  }

  Future<void> write(
    String scope,
    String key,
    Map<String, dynamic> payload,
  ) async {
    await _database.insert('local_drafts', {
      'user_id': userId,
      'scope': scope,
      'key': key,
      'payload': jsonEncode(payload),
      'updated_at_utc': DateTime.now().toUtc().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clear(String scope, String key) async {
    await _database.delete(
      'local_drafts',
      where: 'user_id = ? AND scope = ? AND key = ?',
      whereArgs: [userId, scope, key],
    );
  }
}
