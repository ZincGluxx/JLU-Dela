/// 学习通作业、课程偏好与受权访问的本地实现。
///
/// 来源刷新走 `SourceHttpClient` + `SourceExecutor`：失败只记录来源状态，保留旧
/// 快照；个人已读/忽略标记与来源字段分列保存，刷新不会覆盖。数据按 `user_id`
/// 隔离，课程通过 CORE `CourseStore` upsert，唯一键为来源身份，不按课程名合并。
library;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/assignment.dart';
import '../../core/models/course.dart';
import '../../core/models/material.dart';
import '../../core/models/local_date.dart';
import '../../core/models/source.dart';
import '../../core/source/chaoxing_access.dart';
import '../../core/source/source.dart';
import '../../core/source/source_context.dart';
import '../../core/source/source_executor.dart';
import '../../core/source/source_session.dart';
import '../../core/storage/course_store.dart';
import '../../core/storage/local_database.dart';
import '../../core/storage/queries.dart';
import '../../core/storage/source_snapshot_store.dart';
import 'assignment_deadline.dart';
import 'assignment_grouping.dart';
import 'assignment_status.dart';
import 'chaoxing_materials.dart';
import 'chaoxing_models.dart';
import 'chaoxing_parse.dart';
import 'chaoxing_source.dart';

class ChaoxingStore implements AssignmentQuery, ChaoxingAccess {
  ChaoxingStore(
    this.database,
    this.userId,
    this.snapshots,
    this.courses, {
    this.source,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const String sourceScope = 'default';
  static const String coursesResource = 'courses';
  static const String assignmentsResource = 'assignments';
  static const int maxRemarkLength = 100;
  static const Uuid _uuid = Uuid();

  final LocalDatabase database;
  final String userId;
  final SourceSnapshotStore snapshots;
  final CourseStore courses;
  final SourceContext? source;
  final DateTime Function() _now;

  Database get _database => database.database;

  bool get hasSourceSession =>
      source?.sessions.hasSession(SourceKind.chaoxing) ?? false;

  Future<SourceSnapshot> coursesSnapshot() =>
      snapshots.read(SourceKind.chaoxing, coursesResource);

  Future<SourceSnapshot> courseSnapshot(String courseOfferingId) =>
      snapshots.read(
        SourceKind.chaoxing,
        assignmentsResource,
        scopeKey: courseOfferingId,
      );

  // ---------------------------------------------------------------- courses

  Future<List<CourseOffering>> listCourses({bool? retained}) {
    return courses.list(source: SourceKind.chaoxing, retained: retained);
  }

  Future<CourseOffering> setCourseRetained(
    String courseOfferingId,
    bool retained,
  ) async {
    final offering = await _requireCourse(courseOfferingId);
    return courses.updatePreferences(offering.id, retained: retained);
  }

  /// 备注名 trim 后 1–100 字符；空字符串表示清除，恢复来源课程名。
  Future<CourseOffering> setCourseRemark(
    String courseOfferingId,
    String remark,
  ) async {
    final offering = await _requireCourse(courseOfferingId);
    final value = remark.trim();
    if (value.length > maxRemarkLength) {
      throw ArgumentError('备注名不能超过 $maxRemarkLength 个字符');
    }
    return courses.updatePreferences(
      offering.id,
      remark: value.isEmpty ? null : value,
      clearRemark: value.isEmpty,
    );
  }

  Future<CourseOffering> _requireCourse(String courseOfferingId) async {
    final offering = await courses.byId(courseOfferingId);
    if (offering == null || offering.sourceRef.source != SourceKind.chaoxing) {
      throw StateError('课程不存在或不属于当前学习通来源');
    }
    return offering;
  }

  Future<CourseOffering> _requireCourseForAccess(
    String courseOfferingId,
  ) async {
    final offering = await courses.byId(courseOfferingId);
    if (offering == null || offering.sourceRef.source != SourceKind.chaoxing) {
      throw protocolException('只能访问已映射到当前学习通的课程');
    }
    return offering;
  }

  // ------------------------------------------------------------ assignments

  @override
  Future<List<Assignment>> list({
    String? courseId,
    bool includeUndated = true,
    LocalDate? from,
    LocalDate? to,
  }) async {
    final conditions = <String>['user_id = ?'];
    final arguments = <Object?>[userId];
    if (courseId != null) {
      conditions.add('course_offering_id = ?');
      arguments.add(courseId);
    }
    if (from != null || to != null) {
      if (from == null || to == null) {
        throw ArgumentError('from 与 to 需要同时提供');
      }
      conditions.add('''
(
  (due_kind = 'date_only' AND due_date >= ? AND due_date < ?)
  OR (due_kind = 'exact' AND due_at_utc >= ? AND due_at_utc < ?)
  ${includeUndated ? "OR due_kind IN ('relative','unknown')" : ''}
)''');
      arguments.addAll([
        from.toIso8601String(),
        to.toIso8601String(),
        _shanghaiMidnightMillis(from),
        _shanghaiMidnightMillis(to),
      ]);
    } else if (!includeUndated) {
      conditions.add("due_kind IN ('exact','date_only')");
    }
    final rows = await _database.query(
      'assignments',
      where: conditions.join(' AND '),
      whereArgs: arguments,
    );
    final items = rows.map(_assignmentFromRow).toList();
    items.sort(compareAssignmentDue);
    return items;
  }

  Future<Assignment?> byId(String assignmentId) async {
    final rows = await _database.query(
      'assignments',
      where: 'id = ? AND user_id = ?',
      whereArgs: [assignmentId, userId],
      limit: 1,
    );
    return rows.isEmpty ? null : _assignmentFromRow(rows.first);
  }

  /// 个人标记：`read=true` 记录当前时间，`false` 清除；忽略同上。来源状态不变。
  Future<Assignment> setMarks(
    String assignmentId, {
    bool? read,
    bool? muted,
  }) async {
    if (read == null && muted == null) {
      throw ArgumentError('至少需要一个标记');
    }
    final rows = await _database.query(
      'assignments',
      where: 'id = ? AND user_id = ?',
      whereArgs: [assignmentId, userId],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('作业不存在或不属于当前用户');
    final timestamp = _now().toUtc().millisecondsSinceEpoch;
    final values = <String, Object?>{'updated_at_utc': timestamp};
    if (read != null) values['read_at_utc'] = read ? timestamp : null;
    if (muted != null) values['muted_at_utc'] = muted ? timestamp : null;
    await _database.update(
      'assignments',
      values,
      where: 'id = ? AND user_id = ?',
      whereArgs: [assignmentId, userId],
    );
    final updated = await _database.query(
      'assignments',
      where: 'id = ? AND user_id = ?',
      whereArgs: [assignmentId, userId],
      limit: 1,
    );
    return _assignmentFromRow(updated.single);
  }

  // ---------------------------------------------------------------- refresh

  /// 刷新课程列表并逐门刷新已保留课程的作业；单门课程失败只影响该课程。
  Future<ChaoxingRefreshReport> refreshAll({SourceHttpClient? http}) async {
    final client = http ?? source?.http;
    if (client == null) {
      return ChaoxingRefreshReport(coursesFailure: unavailableFailure());
    }
    final clientSource = ChaoxingSource(client);
    final executor = SourceExecutor(snapshots: snapshots, now: _now);
    final coursesResult = await executor.run<List<ChaoxingCourse>>(
      source: SourceKind.chaoxing,
      resource: coursesResource,
      fetch: clientSource.fetchCourses,
      persist: (courses, _) => _persistCourses(courses),
    );
    if (coursesResult is SourceFailed<List<ChaoxingCourse>>) {
      return ChaoxingRefreshReport(coursesFailure: coursesResult.failure);
    }
    final success = coursesResult as SourceSuccess<List<ChaoxingCourse>>;
    final pages = success.value;
    final offerings = await listCourses(retained: true);
    final bySourceId = {for (final page in pages) page.id: page};
    final failures = <ChaoxingCourseFailure>[];
    for (final offering in offerings) {
      final page = bySourceId[offering.sourceRef.sourceId];
      if (page == null) continue;
      final result = await _refreshCourseWorks(clientSource, offering, page);
      if (result is SourceFailed<List<ChaoxingWork>>) {
        failures.add(
          ChaoxingCourseFailure(
            courseOfferingId: offering.id,
            courseName: offering.name,
            failure: result.failure,
          ),
        );
        if (result.failure.code == SourceErrorCodes.sourceAuthRequired) break;
      }
    }
    return ChaoxingRefreshReport(
      courseFailures: failures,
      observedAt: success.observedAt,
    );
  }

  /// 单独重试一门课程；课程入口取自来源课程列表，不修改课程缓存。
  Future<SourceResult<List<ChaoxingWork>>> refreshCourse(
    String courseOfferingId, {
    SourceHttpClient? http,
  }) async {
    final client = http ?? source?.http;
    if (client == null) {
      return SourceFailed<List<ChaoxingWork>>(
        failure: unavailableFailure(),
        snapshot: await courseSnapshot(courseOfferingId),
      );
    }
    final offering = await courses.byId(courseOfferingId);
    if (offering == null || offering.sourceRef.source != SourceKind.chaoxing) {
      return SourceFailed<List<ChaoxingWork>>(
        failure: protocolFailure('只能重试已保存的学习通课程'),
        snapshot: await courseSnapshot(courseOfferingId),
      );
    }
    final clientSource = ChaoxingSource(client);
    final ChaoxingCourse page;
    try {
      final pages = await clientSource.fetchCourses();
      final matched = findCourse(pages, offering.sourceRef.sourceId);
      if (matched == null) {
        return SourceFailed<List<ChaoxingWork>>(
          failure: protocolFailure('学习通课程列表中找不到该课程'),
          snapshot: await courseSnapshot(courseOfferingId),
        );
      }
      page = matched;
    } on Object catch (error) {
      final failure = sourceFailureOf(error, source: SourceKind.chaoxing);
      await _recordFailure(offering.id, failure);
      return SourceFailed<List<ChaoxingWork>>(
        failure: failure,
        snapshot: await courseSnapshot(courseOfferingId),
      );
    }
    return _refreshCourseWorks(clientSource, offering, page);
  }

  Future<SourceResult<List<ChaoxingWork>>> _refreshCourseWorks(
    ChaoxingSource source,
    CourseOffering offering,
    ChaoxingCourse course,
  ) {
    return SourceExecutor(
      snapshots: snapshots,
      now: _now,
    ).run<List<ChaoxingWork>>(
      source: SourceKind.chaoxing,
      resource: assignmentsResource,
      scopeKey: offering.id,
      fetch: () => source.fetchWorks(course),
      persist: (works, observedAt) =>
          _persistWorks(offering, works, observedAt),
    );
  }

  Future<void> _persistCourses(List<ChaoxingCourse> courses) {
    return this.courses.applySnapshot(
      source: SourceKind.chaoxing,
      scope: sourceScope,
      courses: [
        for (final course in courses)
          SourceCourse(
            source: SourceKind.chaoxing,
            sourceScope: sourceScope,
            sourceId: course.id,
            name: course.name,
            teacher: course.teacher.isEmpty ? null : course.teacher,
          ),
      ],
      complete: true,
    );
  }

  Future<void> _persistWorks(
    CourseOffering offering,
    List<ChaoxingWork> works,
    DateTime observedAt,
  ) async {
    final previous = await _storedWorks(offering.id);
    final merged = mergeWorkSnapshot(
      previous: previous,
      incoming: works,
      observedAt: observedAt,
    );
    final updatedAt = _now().toUtc().millisecondsSinceEpoch;
    await _database.transaction((transaction) async {
      for (final work in merged) {
        await transaction.rawInsert(
          _upsertAssignmentSql,
          _assignmentValues(offering, work, updatedAt),
        );
      }
      final ids = merged.map((work) => work.id).toList(growable: false);
      final placeholders = List.filled(ids.length, '?').join(',');
      final unseen = ids.isEmpty
          ? ''
          : ' AND source_work_id NOT IN ($placeholders)';
      await transaction.delete(
        'assignments',
        where:
            'user_id = ? AND source_scope = ? AND source_course_id = ?$unseen',
        whereArgs: [
          userId,
          offering.sourceRef.sourceScope,
          offering.sourceRef.sourceId,
          ...ids,
        ],
      );
    });
  }

  List<Object?> _assignmentValues(
    CourseOffering offering,
    ChaoxingWork work,
    int updatedAt,
  ) {
    final deadline = workDeadline(work);
    final dueAt = deadline == null
        ? null
        : dueInstantOf(deadline)?.millisecondsSinceEpoch;
    final kind =
        dueAt == null && assignmentDueKind(work) == AssignmentDueKind.exact
        ? AssignmentDueKind.unknown
        : assignmentDueKind(work);
    final dueDate = kind == AssignmentDueKind.dateOnly ? deadline?.date : null;
    final timingText = (work.detailTiming ?? work.timing).trim();
    return [
      _assignmentId(offering, work),
      userId,
      offering.id,
      offering.sourceRef.sourceScope,
      offering.sourceRef.sourceId,
      work.id,
      work.title,
      parseSourceStatus(work.status).code,
      sourceStatusText(work.status),
      _dueKindValue(kind),
      dueDate,
      dueAt,
      timingText.isEmpty ? null : timingText,
      work.observedAt?.toUtc().millisecondsSinceEpoch ?? updatedAt,
      work.detailSyncedAt?.toUtc().millisecondsSinceEpoch,
      updatedAt,
      updatedAt,
    ];
  }

  String _assignmentId(CourseOffering offering, ChaoxingWork work) {
    return _uuid.v5(
      Namespace.url.value,
      'chaoxing|$userId|${offering.sourceRef.sourceScope}|'
      '${offering.sourceRef.sourceId}|${work.id}',
    );
  }

  Future<List<ChaoxingWork>> _storedWorks(String courseOfferingId) async {
    final rows = await _database.query(
      'assignments',
      where: 'user_id = ? AND course_offering_id = ?',
      whereArgs: [userId, courseOfferingId],
    );
    return [
      for (final row in rows)
        ChaoxingWork(
          id: row['source_work_id'] as String,
          title: row['title'] as String,
          status:
              (row['source_status_text'] as String?) ??
              row['source_status'] as String,
          detailTiming: row['detail_observed_at_utc'] == null
              ? null
              : row['timing_text'] as String?,
          detailSyncedAt: row['detail_observed_at_utc'] == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  row['detail_observed_at_utc'] as int,
                  isUtc: true,
                ),
          readAt: _utcOrNull(row['read_at_utc']),
          mutedAt: _utcOrNull(row['muted_at_utc']),
        ),
    ];
  }

  Future<void> _recordFailure(String courseOfferingId, SourceFailure failure) {
    return snapshots.recordFailure(
      SourceKind.chaoxing,
      assignmentsResource,
      scopeKey: courseOfferingId,
      attemptedAt: _now().toUtc(),
      code: failure.code,
      message: failure.message,
    );
  }

  static const String _upsertAssignmentSql = '''
INSERT INTO assignments(
  id, user_id, course_offering_id, source_scope, source_course_id, source_work_id,
  title, source_status, source_status_text, due_kind, due_date, due_at_utc,
  timing_text, observed_at_utc, detail_observed_at_utc, created_at_utc, updated_at_utc
) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
ON CONFLICT(user_id, source_scope, source_course_id, source_work_id) DO UPDATE SET
  course_offering_id = excluded.course_offering_id,
  title = excluded.title,
  source_status = excluded.source_status,
  source_status_text = excluded.source_status_text,
  due_kind = excluded.due_kind,
  due_date = excluded.due_date,
  due_at_utc = excluded.due_at_utc,
  timing_text = excluded.timing_text,
  observed_at_utc = excluded.observed_at_utc,
  detail_observed_at_utc = excluded.detail_observed_at_utc,
  updated_at_utc = excluded.updated_at_utc
''';

  // ------------------------------------------------------------ source access

  @override
  Future<MaterialChildrenPage> listMaterialChildren({
    required String courseOfferingId,
    String? parentSourceId,
    int page = 1,
  }) async {
    final client = requireClient();
    _requireSessionForAccess();
    final offering = await _requireCourseForAccess(courseOfferingId);
    final source = ChaoxingSource(client);
    final course = await _resolveCourse(source, offering);
    final List<String> folderPath;
    if (parentSourceId == null || parentSourceId.isEmpty) {
      folderPath = const [];
    } else {
      final found = await _findMaterial(source, course, parentSourceId);
      if (found == null || found.entry.kind != ChaoxingMaterialKind.folder) {
        throw protocolException('资料目录不在已读取的学习通课程中');
      }
      folderPath = [...found.path, found.entry.id];
    }
    final entries = page == 1
        ? await source.fetchMaterialChildren(course, folderPath)
        : const <ChaoxingMaterial>[];
    return MaterialChildrenPage(
      entries: [
        for (final entry in entries)
          MaterialEntry(
            id: entry.id,
            name: entry.name,
            kind: entry.kind == ChaoxingMaterialKind.folder
                ? MaterialKind.folder
                : MaterialKind.file,
            parentId: parentSourceId,
            downloadable: entry.downloadable,
          ),
      ],
      page: page,
      totalPages: 1,
      observedAt: _now().toUtc(),
    );
  }

  @override
  Future<SourceAccess> accessMaterial({
    required String courseOfferingId,
    required String sourceId,
  }) async {
    final client = requireClient();
    _requireSessionForAccess();
    final offering = await _requireCourseForAccess(courseOfferingId);
    final source = ChaoxingSource(client);
    final course = await _resolveCourse(source, offering);
    final found = await _findMaterial(source, course, sourceId);
    final entry = found?.entry;
    final uri = entry?.downloadUri;
    if (entry == null || uri == null) {
      throw protocolException('文件不在已读取的资料目录中');
    }
    return SourceAccess(
      uri: uri,
      mode: SourceAccessMode.sourcePage,
      filename: entry.name,
      requiresSourceSession: true,
    );
  }

  @override
  Future<SourceAccess> openAssignment({required String assignmentId}) async {
    final client = requireClient();
    _requireSessionForAccess();
    final rows = await _database.query(
      'assignments',
      where: 'id = ? AND user_id = ?',
      whereArgs: [assignmentId, userId],
      limit: 1,
    );
    if (rows.isEmpty) throw protocolException('只能打开已映射到当前学习通的作业');
    final row = rows.first;
    final offering = await _requireCourseForAccess(
      row['course_offering_id'] as String,
    );
    final source = ChaoxingSource(client);
    final course = await _resolveCourse(source, offering);
    final uri = await source.fetchAssignmentUri(
      course,
      row['source_work_id'] as String,
    );
    return SourceAccess(
      uri: uri,
      mode: SourceAccessMode.sourcePage,
      requiresSourceSession: true,
    );
  }

  /// 在来源资料树中查找对象；不持久化签名 URL，最多下钻 4 层。
  Future<_MaterialLocation?> _findMaterial(
    ChaoxingSource source,
    ChaoxingCourse course,
    String sourceId,
  ) async {
    final root = await source.fetchMaterialChildren(course, const []);
    final queue = <({List<String> path, List<ChaoxingMaterial> entries})>[
      (path: const [], entries: root),
    ];
    var visited = 0;
    while (queue.isNotEmpty) {
      final item = queue.removeAt(0);
      for (final entry in item.entries) {
        if (entry.id == sourceId) {
          return _MaterialLocation(path: item.path, entry: entry);
        }
        if (entry.kind == ChaoxingMaterialKind.folder && item.path.length < 4) {
          if (++visited > 40) {
            throw protocolException('资料目录过大，暂不支持逐层检索');
          }
          final children = await source.fetchMaterialChildren(course, [
            ...item.path,
            entry.id,
          ]);
          queue.add((path: [...item.path, entry.id], entries: children));
        }
      }
    }
    return null;
  }

  void _requireSessionForAccess() {
    final registry = source?.sessions;
    if (registry != null && !registry.hasSession(SourceKind.chaoxing)) {
      throw SourceException(
        const SourceFailure(
          code: SourceErrorCodes.sourceAuthRequired,
          message: '学习通未连接，请先登录学习通',
          source: SourceKind.chaoxing,
        ),
      );
    }
  }

  SourceHttpClient requireClient() {
    final client = source?.http;
    if (client == null) {
      throw SourceException(unavailableFailure());
    }
    return client;
  }

  Future<ChaoxingCourse> _resolveCourse(
    ChaoxingSource source,
    CourseOffering offering,
  ) async {
    final pages = await source.fetchCourses();
    final course = findCourse(pages, offering.sourceRef.sourceId);
    if (course == null) throw protocolException('学习通课程列表中找不到该课程');
    return course;
  }

  Assignment _assignmentFromRow(Map<String, Object?> row) {
    final dueDate = row['due_date'] as String?;
    final dueAt = row['due_at_utc'] as int?;
    return Assignment(
      id: row['id'] as String,
      courseOfferingId: row['course_offering_id'] as String?,
      title: row['title'] as String,
      sourceStatus: row['source_status'] as String,
      sourceStatusText: row['source_status_text'] as String?,
      dueKind: _dueKindFromValue(row['due_kind'] as String),
      dueDate: dueDate == null ? null : LocalDate.parse(dueDate),
      dueAtUtc: dueAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(dueAt, isUtc: true),
      timingText: row['timing_text'] as String?,
      observedAtUtc: DateTime.fromMillisecondsSinceEpoch(
        row['observed_at_utc'] as int,
        isUtc: true,
      ),
      readAtUtc: _utcOrNull(row['read_at_utc']),
      mutedAtUtc: _utcOrNull(row['muted_at_utc']),
    );
  }
}

ChaoxingCourse? findCourse(List<ChaoxingCourse> courses, String sourceId) {
  for (final course in courses) {
    if (course.id == sourceId) return course;
  }
  return null;
}

SourceFailure unavailableFailure() {
  return const SourceFailure(
    code: SourceErrorCodes.sourceUnavailable,
    message: '来源网络客户端尚未接入',
    source: SourceKind.chaoxing,
  );
}

SourceFailure protocolFailure(String message) {
  return SourceFailure(
    code: SourceErrorCodes.sourceProtocol,
    message: message,
    source: SourceKind.chaoxing,
  );
}

SourceException protocolException(String message) {
  return SourceException(protocolFailure(message));
}

int _shanghaiMidnightMillis(LocalDate date) {
  return DateTime.parse(
    '${date.toIso8601String()}T00:00:00+08:00',
  ).toUtc().millisecondsSinceEpoch;
}

AssignmentDueKind _dueKindFromValue(String value) {
  return switch (value) {
    'exact' => AssignmentDueKind.exact,
    'date_only' => AssignmentDueKind.dateOnly,
    'relative' => AssignmentDueKind.relative,
    _ => AssignmentDueKind.unknown,
  };
}

String _dueKindValue(AssignmentDueKind kind) {
  return switch (kind) {
    AssignmentDueKind.exact => 'exact',
    AssignmentDueKind.dateOnly => 'date_only',
    AssignmentDueKind.relative => 'relative',
    AssignmentDueKind.unknown => 'unknown',
  };
}

DateTime? _utcOrNull(Object? value) {
  return value == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(value as int, isUtc: true);
}

class _MaterialLocation {
  const _MaterialLocation({required this.path, required this.entry});

  final List<String> path;
  final ChaoxingMaterial entry;
}

class ChaoxingCourseFailure {
  const ChaoxingCourseFailure({
    required this.courseOfferingId,
    required this.courseName,
    required this.failure,
  });

  final String courseOfferingId;
  final String courseName;
  final SourceFailure failure;
}

class ChaoxingRefreshReport {
  const ChaoxingRefreshReport({
    this.coursesFailure,
    this.courseFailures = const [],
    this.observedAt,
  });

  final SourceFailure? coursesFailure;
  final List<ChaoxingCourseFailure> courseFailures;
  final DateTime? observedAt;

  bool get isSuccess => coursesFailure == null && courseFailures.isEmpty;

  bool get requiresLogin =>
      coursesFailure?.code == SourceErrorCodes.sourceAuthRequired ||
      courseFailures.any(
        (failure) =>
            failure.failure.code == SourceErrorCodes.sourceAuthRequired,
      );
}
