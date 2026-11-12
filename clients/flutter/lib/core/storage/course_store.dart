import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../models/course.dart';
import '../models/source.dart';
import 'local_database.dart';

class SourceCourse {
  const SourceCourse({
    required this.source,
    required this.sourceScope,
    required this.sourceId,
    required this.name,
    this.teacher,
    this.semesterId,
  });

  final SourceKind source;
  final String sourceScope;
  final String sourceId;
  final String name;
  final String? teacher;
  final String? semesterId;
}

class CourseStore {
  CourseStore(LocalDatabase database, this.userId, {DateTime Function()? now})
    : _database = database.database,
      _now = now ?? DateTime.now;

  static const _uuid = Uuid();

  final Database _database;
  final String userId;
  final DateTime Function() _now;

  Future<CourseOffering> upsert(SourceCourse course) {
    return _upsert(_database, course);
  }

  Future<CourseOffering?> byId(String id) async {
    final rows = await _database.query(
      'course_offerings',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
      limit: 1,
    );
    return rows.isEmpty ? null : _courseFromRow(rows.first);
  }

  Future<List<CourseOffering>> list({
    SourceKind? source,
    bool? retained,
  }) async {
    final conditions = ['user_id = ?'];
    final arguments = <Object?>[userId];
    if (source != null) {
      conditions.add('source = ?');
      arguments.add(source.databaseValue);
    }
    if (retained != null) {
      conditions.add('retained = ?');
      arguments.add(retained ? 1 : 0);
    }
    final rows = await _database.query(
      'course_offerings',
      where: conditions.join(' AND '),
      whereArgs: arguments,
      orderBy: 'name',
    );
    return rows.map(_courseFromRow).toList();
  }

  Future<CourseOffering> updatePreferences(
    String id, {
    String? remark,
    bool clearRemark = false,
    bool? retained,
  }) async {
    final values = <String, Object?>{
      'updated_at_utc': _now().toUtc().millisecondsSinceEpoch,
    };
    if (clearRemark) {
      values['remark'] = null;
    } else if (remark != null) {
      final normalizedRemark = remark.trim();
      if (normalizedRemark.isEmpty || normalizedRemark.runes.length > 100) {
        throw ArgumentError.value(remark, 'remark', '课程备注需在 trim 后为 1–100 个字符');
      }
      values['remark'] = normalizedRemark;
    }
    if (retained != null) {
      values['retained'] = retained ? 1 : 0;
    }
    await _database.update(
      'course_offerings',
      values,
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
    final rows = await _database.query(
      'course_offerings',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Course offering not found: $id');
    }
    return _courseFromRow(rows.first);
  }

  Future<void> applySnapshot({
    required SourceKind source,
    required String scope,
    required List<SourceCourse> courses,
    required bool complete,
  }) async {
    await _database.transaction((transaction) async {
      for (final course in courses) {
        await _upsert(transaction, course);
      }
      if (!complete) {
        return;
      }
      final sourceIdArguments = [
        userId,
        source.databaseValue,
        scope,
        ...courses.map((course) => course.sourceId),
      ];
      final placeholders = List.filled(courses.length, '?').join(',');
      final unseen = courses.isEmpty
          ? ''
          : ' AND source_id NOT IN ($placeholders)';
      await transaction.delete(
        'course_offerings',
        where: 'user_id = ? AND source = ? AND source_scope = ?$unseen',
        whereArgs: sourceIdArguments,
      );
    });
  }

  Future<CourseOffering> _upsert(
    DatabaseExecutor executor,
    SourceCourse course,
  ) async {
    final rows = await executor.query(
      'course_offerings',
      where:
          'user_id = ? AND source = ? AND source_scope = ? AND source_id = ?',
      whereArgs: [
        userId,
        course.source.databaseValue,
        course.sourceScope,
        course.sourceId,
      ],
      limit: 1,
    );
    final timestamp = _now().toUtc().millisecondsSinceEpoch;

    if (rows.isEmpty) {
      final offering = CourseOffering(
        id: _uuid.v4(),
        userId: userId,
        sourceRef: SourceRef(
          source: course.source,
          sourceScope: course.sourceScope,
          sourceId: course.sourceId,
        ),
        semesterId: course.semesterId,
        name: course.name,
        teacher: course.teacher,
        remark: null,
        retained: true,
      );
      await executor.insert('course_offerings', {
        'id': offering.id,
        'user_id': userId,
        'source': course.source.databaseValue,
        'source_scope': course.sourceScope,
        'source_id': course.sourceId,
        'semester_id': course.semesterId,
        'name': course.name,
        'teacher': course.teacher,
        'remark': null,
        'retained': 1,
        'created_at_utc': timestamp,
        'updated_at_utc': timestamp,
      });
      return offering;
    }

    final existing = _courseFromRow(rows.first);
    await executor.update(
      'course_offerings',
      {
        'semester_id': course.semesterId,
        'name': course.name,
        'teacher': course.teacher,
        'updated_at_utc': timestamp,
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [existing.id, userId],
    );
    existing
      ..semesterId = course.semesterId
      ..name = course.name
      ..teacher = course.teacher;
    return existing;
  }

  CourseOffering _courseFromRow(Map<String, Object?> row) {
    return CourseOffering(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      sourceRef: SourceRef(
        source: SourceKind.fromDatabaseValue(row['source'] as String),
        sourceScope: row['source_scope'] as String,
        sourceId: row['source_id'] as String,
      ),
      semesterId: row['semester_id'] as String?,
      name: row['name'] as String,
      teacher: row['teacher'] as String?,
      remark: row['remark'] as String?,
      retained: (row['retained'] as int) == 1,
    );
  }
}
