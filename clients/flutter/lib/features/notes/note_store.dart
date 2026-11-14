import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../core/storage/local_database.dart';
import 'note_models.dart';

/// 笔记的本地读写。
///
/// 所有查询都带 `user_id`：切号后不会读到上一账号的笔记。
/// 课程/回放只作为筛选条件与展示提示，不作为外键约束——
/// 来源失效不得删除用户的私人笔记。
class NoteStore extends ChangeNotifier {
  NoteStore(LocalDatabase database, this.userId, {DateTime Function()? now})
    : _database = database.database,
      _now = now ?? DateTime.now;

  static const _uuid = Uuid();

  final Database _database;
  final String userId;
  final DateTime Function() _now;

  /// 列出笔记，按更新时间倒序。
  ///
  /// [courseOfferingId]、[lessonId]、[replayId] 都是可选筛选：
  /// 传了就只返回挂在该目标下的笔记。
  Future<List<Note>> list({
    String? courseOfferingId,
    String? lessonId,
    String? replaySource,
    String? replayId,
    int limit = 100,
    int offset = 0,
  }) async {
    final where = <String>['user_id = ?'];
    final args = <Object?>[userId];
    if (courseOfferingId != null) {
      where.add('course_offering_id = ?');
      args.add(courseOfferingId);
    }
    if (lessonId != null) {
      where.add('lesson_id = ?');
      args.add(lessonId);
    }
    if (replayId != null) {
      where.add('replay_id = ?');
      args.add(replayId);
      if (replaySource != null) {
        where.add('replay_source = ?');
        args.add(replaySource);
      }
    }
    final rows = await _database.query(
      'notes',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'updated_at_utc DESC, id ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(_noteFromRow).toList();
  }

  Future<Note?> get(String id) async {
    final rows = await _database.query(
      'notes',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
      limit: 1,
    );
    return rows.isEmpty ? null : _noteFromRow(rows.first);
  }

  Future<int> count() async {
    final rows = await _database.rawQuery(
      'SELECT COUNT(*) AS total FROM notes WHERE user_id = ?',
      [userId],
    );
    return (rows.first['total'] as int?) ?? 0;
  }

  Future<Note> create({
    required String title,
    String body = '',
    NoteTarget target = const NoteTarget(),
    int? positionMs,
  }) async {
    final normalizedTitle = _validatedTitle(title);
    _validateBody(body);
    _validateTarget(target);
    _validatePosition(target, positionMs);
    final timestamp = _now().toUtc();
    final note = Note(
      id: _uuid.v4(),
      userId: userId,
      title: normalizedTitle,
      body: body,
      courseOfferingId: target.courseOfferingId,
      lessonId: target.lessonId,
      replaySource: target.replaySource,
      replayId: target.replayId,
      replayTitle: target.replayTitle,
      positionMs: positionMs,
      revision: 1,
      createdAtUtc: timestamp,
      updatedAtUtc: timestamp,
    );
    await _database.insert('notes', _rowOf(note));
    notifyListeners();
    return note;
  }

  /// 更新笔记内容与归属。
  ///
  /// 用 `revision` 做乐观并发：版本不匹配时抛 [NoteRevisionConflict] 并带回
  /// 库内当前版本，调用方据此保留用户草稿而不是静默覆盖。
  Future<Note> update(Note note) async {
    if (note.userId != userId) {
      throw const NoteValidationException('不能更新其他用户的笔记');
    }
    final normalizedTitle = _validatedTitle(note.title);
    _validateBody(note.body);
    _validateTarget(note.target);
    _validatePosition(note.target, note.positionMs);
    final timestamp = _now().toUtc();
    final updated = Note(
      id: note.id,
      userId: userId,
      title: normalizedTitle,
      body: note.body,
      courseOfferingId: note.courseOfferingId,
      lessonId: note.lessonId,
      replaySource: note.replaySource,
      replayId: note.replayId,
      replayTitle: note.replayTitle,
      positionMs: note.positionMs,
      revision: note.revision + 1,
      createdAtUtc: note.createdAtUtc,
      updatedAtUtc: timestamp,
    );
    final changed = await _database.update(
      'notes',
      _rowOf(updated),
      where: 'id = ? AND user_id = ? AND revision = ?',
      whereArgs: [note.id, userId, note.revision],
    );
    if (changed == 0) {
      throw NoteRevisionConflict(await _currentOrThrow(note.id));
    }
    notifyListeners();
    return updated;
  }

  /// 只更新回放时间位置（边看边记时的常用操作）。
  ///
  /// 与 [update] 一样走版本校验：用户在另一个窗口改了正文时不会把改动盖掉。
  Future<Note> updatePosition(
    String id, {
    required int revision,
    required int positionMs,
  }) async {
    if (positionMs < 0) {
      throw const NoteValidationException('时间位置不能为负数');
    }
    final current = await get(id);
    if (current == null) {
      throw NoteNotFoundException(id);
    }
    // 位置只有在挂了完整回放标识时才有意义。独立笔记若被写进 position_ms，
    // 之后正常编辑会被 _validatePosition 拒绝，等于把这条笔记做成了改不动的状态。
    if (!current.target.hasReplay) {
      throw const NoteValidationException('没有回放的笔记不能记录时间位置');
    }
    final timestamp = _now().toUtc();
    final changed = await _database.update(
      'notes',
      {
        'position_ms': positionMs,
        'revision': revision + 1,
        'updated_at_utc': _millisecondsOf(timestamp),
      },
      where: 'id = ? AND user_id = ? AND revision = ?',
      whereArgs: [id, userId, revision],
    );
    if (changed == 0) {
      throw NoteRevisionConflict(await _currentOrThrow(id));
    }
    notifyListeners();
    return (await get(id))!;
  }

  Future<void> delete(String id, {required int revision}) async {
    final changed = await _database.delete(
      'notes',
      where: 'id = ? AND user_id = ? AND revision = ?',
      whereArgs: [id, userId, revision],
    );
    if (changed == 0) {
      throw NoteRevisionConflict(await _currentOrThrow(id));
    }
    notifyListeners();
  }

  /// 回放改名时同步显示名。只更新 [replayTitle]，不碰正文与版本号——
  /// 这是来源侧的事实更新，不是用户编辑，不该制造版本冲突。
  Future<void> renameReplay({
    required String replaySource,
    required String replayId,
    required String replayTitle,
  }) async {
    await _database.update(
      'notes',
      {'replay_title': replayTitle},
      where: 'user_id = ? AND replay_source = ? AND replay_id = ?',
      whereArgs: [userId, replaySource, replayId],
    );
    notifyListeners();
  }

  String _validatedTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.runes.length > NoteLimits.maxTitleLength) {
      throw const NoteValidationException('标题不能超过 200 个字符');
    }
    return trimmed;
  }

  void _validateBody(String body) {
    if (body.runes.length > NoteLimits.maxBodyLength) {
      throw const NoteValidationException('正文不能超过 20000 个字符');
    }
  }

  /// 回放身份必须成对出现。
  ///
  /// 只给 id 不给来源时，界面知道「这条笔记挂了某个回放」，却不知道该去哪个来源
  /// 跳转；只给来源不给 id 更没法定位。两者缺一都不许落库。
  void _validateTarget(NoteTarget target) {
    if (target.hasPartialReplay) {
      throw const NoteValidationException('回放来源与回放标识必须成对提供');
    }
  }

  /// 时间位置只在挂了回放时有意义。
  ///
  /// 没有回放却带位置，说明调用方搞错了归属；与其静默丢弃，
  /// 不如在边界就拒绝，免得「保存成功但跳不回去」。
  void _validatePosition(NoteTarget target, int? positionMs) {
    if (positionMs == null) {
      return;
    }
    if (!target.hasReplay) {
      throw const NoteValidationException('没有回放的笔记不能记录时间位置');
    }
    if (positionMs < 0) {
      throw const NoteValidationException('时间位置不能为负数');
    }
  }

  Future<Note> _currentOrThrow(String id) async {
    final current = await get(id);
    if (current == null) {
      throw NoteNotFoundException(id);
    }
    return current;
  }

  Map<String, Object?> _rowOf(Note note) {
    return {
      'id': note.id,
      'user_id': note.userId,
      'title': note.title,
      'body': note.body,
      'course_offering_id': note.courseOfferingId,
      'lesson_id': note.lessonId,
      'replay_source': note.replaySource,
      'replay_id': note.replayId,
      'replay_title': note.replayTitle,
      'position_ms': note.positionMs,
      'revision': note.revision,
      'created_at_utc': _millisecondsOf(note.createdAtUtc),
      'updated_at_utc': _millisecondsOf(note.updatedAtUtc),
    };
  }

  Note _noteFromRow(Map<String, Object?> row) {
    return Note(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      title: row['title'] as String,
      body: row['body'] as String,
      courseOfferingId: row['course_offering_id'] as String?,
      lessonId: row['lesson_id'] as String?,
      replaySource: row['replay_source'] as String?,
      replayId: row['replay_id'] as String?,
      replayTitle: row['replay_title'] as String?,
      positionMs: row['position_ms'] as int?,
      revision: row['revision'] as int,
      createdAtUtc: _utcFromMilliseconds(row['created_at_utc'] as int),
      updatedAtUtc: _utcFromMilliseconds(row['updated_at_utc'] as int),
    );
  }

  DateTime _utcFromMilliseconds(int value) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }

  int _millisecondsOf(DateTime value) {
    return value.toUtc().millisecondsSinceEpoch;
  }
}
