import 'dart:convert';

import 'package:jlu_dela_api/api.dart' show BackupNote;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../core/storage/local_database.dart';
import 'note_models.dart';

class NoteBackupAdapter {
  NoteBackupAdapter(LocalDatabase database, this.userId)
    : _database = database.database;

  static const _uuid = Uuid();
  static const _copyNamespace = 'bcf4d342-3937-5cca-9ae9-2c4ff99b5d73';
  static const _maxNotes = 100;
  static const _maxJsonBytes = 512 * 1024;
  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final Database _database;
  final String userId;

  Future<List<BackupNote>> exportSelected(Set<String> ids) async {
    if (ids.length > _maxNotes) {
      throw const NoteValidationException('一次最多备份 100 条笔记');
    }
    if (ids.isEmpty) {
      return [];
    }
    final rows = await _database.query(
      'notes',
      where:
          'user_id = ? AND id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: [userId, ...ids],
      orderBy: 'updated_at_utc DESC, id ASC',
    );
    if (rows.length != ids.length) {
      throw const NoteValidationException('选中的笔记不存在或不属于当前用户');
    }
    return _validated(rows.map(_fromRow).toList());
  }

  Future<List<BackupNote>> listAll() async {
    final rows = await _database.query(
      'notes',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'updated_at_utc DESC, id ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<String>> restore(
    List<BackupNote> notes, {
    required bool Function() isCurrent,
  }) async {
    final validated = _validated(notes);
    return _database.transaction((transaction) async {
      _checkCurrent(isCurrent);
      final restored = <String>[];
      for (final note in validated) {
        final values = _valuesOf(note);
        var id = note.id;
        var rows = await transaction.query(
          'notes',
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        _checkCurrent(isCurrent);
        var copyIndex = 0;
        while (rows.isNotEmpty && !_canReuse(rows.single, values)) {
          id = _uuid.v5(
            _copyNamespace,
            jsonEncode({
              'user_id': userId,
              'note': _canonicalJson(note),
              if (copyIndex > 0) 'copy_index': copyIndex,
            }),
          );
          copyIndex++;
          rows = await transaction.query(
            'notes',
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          );
          _checkCurrent(isCurrent);
        }
        if (rows.isEmpty) {
          await transaction.insert('notes', {
            'id': id,
            'user_id': userId,
            ...values,
            'revision': 1,
          });
          _checkCurrent(isCurrent);
        }
        restored.add(id);
      }
      return restored;
    });
  }

  List<BackupNote> _validated(List<BackupNote> notes) {
    if (notes.length > _maxNotes) {
      throw const NoteValidationException('一次最多备份或恢复 100 条笔记');
    }
    final validated = <BackupNote>[];
    for (final note in notes) {
      if (!_uuidPattern.hasMatch(note.id)) {
        throw const NoteValidationException('笔记 ID 必须是 UUID');
      }
      final title = note.title.trim();
      if (title.runes.length > NoteLimits.maxTitleLength) {
        throw const NoteValidationException('标题不能超过 200 个字符');
      }
      if (note.body.runes.length > NoteLimits.maxBodyLength) {
        throw const NoteValidationException('正文不能超过 20000 个字符');
      }
      final target = NoteTarget(
        replaySource: note.replaySource,
        replayId: note.replayId,
      );
      if (target.hasPartialReplay) {
        throw const NoteValidationException('回放来源与回放标识必须成对提供');
      }
      if (note.positionMs != null) {
        if (!target.hasReplay) {
          throw const NoteValidationException('没有回放的笔记不能记录时间位置');
        }
        if (note.positionMs! < 0) {
          throw const NoteValidationException('时间位置不能为负数');
        }
      }
      final createdAt = _utcMillis(note.createdAt.millisecondsSinceEpoch);
      final updatedAt = _utcMillis(note.updatedAt.millisecondsSinceEpoch);
      if (createdAt.isAfter(updatedAt)) {
        throw const NoteValidationException('笔记创建时间不能晚于更新时间');
      }
      validated.add(
        BackupNote(
          id: note.id,
          title: title,
          body: note.body,
          courseOfferingId: note.courseOfferingId,
          lessonId: note.lessonId,
          replaySource: note.replaySource,
          replayId: note.replayId,
          replayTitle: note.replayTitle,
          positionMs: note.positionMs,
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      );
    }
    if (utf8.encode(jsonEncode(validated)).length > _maxJsonBytes) {
      throw const NoteValidationException('笔记备份不能超过 512 KiB');
    }
    return validated;
  }

  bool _canReuse(Map<String, Object?> row, Map<String, Object?> values) =>
      row['user_id'] == userId &&
      values.entries.every((entry) => row[entry.key] == entry.value);

  void _checkCurrent(bool Function() isCurrent) {
    if (!isCurrent()) {
      throw StateError('笔记恢复所属的账号会话已失效');
    }
  }

  Map<String, Object?> _valuesOf(BackupNote note) => {
    'title': note.title,
    'body': note.body,
    'course_offering_id': note.courseOfferingId,
    'lesson_id': note.lessonId,
    'replay_source': note.replaySource,
    'replay_id': note.replayId,
    'replay_title': note.replayTitle,
    'position_ms': note.positionMs,
    'created_at_utc': note.createdAt.millisecondsSinceEpoch,
    'updated_at_utc': note.updatedAt.millisecondsSinceEpoch,
  };

  Map<String, Object?> _canonicalJson(BackupNote note) => {
    'body': note.body,
    'course_offering_id': note.courseOfferingId,
    'created_at': note.createdAt.toIso8601String(),
    'id': note.id,
    'lesson_id': note.lessonId,
    'position_ms': note.positionMs,
    'replay_id': note.replayId,
    'replay_source': note.replaySource,
    'replay_title': note.replayTitle,
    'title': note.title,
    'updated_at': note.updatedAt.toIso8601String(),
  };

  BackupNote _fromRow(Map<String, Object?> row) => BackupNote(
    id: row['id'] as String,
    title: row['title'] as String,
    body: row['body'] as String,
    courseOfferingId: row['course_offering_id'] as String?,
    lessonId: row['lesson_id'] as String?,
    replaySource: row['replay_source'] as String?,
    replayId: row['replay_id'] as String?,
    replayTitle: row['replay_title'] as String?,
    positionMs: row['position_ms'] as int?,
    createdAt: _utcMillis(row['created_at_utc'] as int),
    updatedAt: _utcMillis(row['updated_at_utc'] as int),
  );

  DateTime _utcMillis(int milliseconds) =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
}
