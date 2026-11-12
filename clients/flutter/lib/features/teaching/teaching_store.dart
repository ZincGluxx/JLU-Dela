import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/models/lesson.dart';
import '../../core/models/local_date.dart';
import '../../core/models/school_time.dart';
import '../../core/models/source.dart';
import '../../core/source/source.dart';
import '../../core/source/source_context.dart';
import '../../core/source/source_executor.dart';
import '../../core/source/source_session.dart';
import '../../core/storage/course_store.dart';
import '../../core/storage/local_database.dart';
import '../../core/storage/queries.dart';
import '../../core/storage/source_snapshot_store.dart';
import 'jlu_lesson_occurrences.dart';
import 'jlu_timetable_parser.dart';
import 'jlu_timetable_source.dart';

const SourceKind teachingSource = SourceKind.jluIedu;
const String teachingTimetableResource = 'timetable';
const String teachingSemesterResource = 'semester';
const String teachingSemesterScope = 'semester';

class TeachingSemester {
  const TeachingSemester({
    required this.id,
    required this.code,
    required this.name,
    this.startsOn,
    this.totalWeeks,
    required this.isCurrent,
  });

  final String id;
  final String code;
  final String name;
  final LocalDate? startsOn;
  final int? totalWeeks;
  final bool isCurrent;

  LocalDate? get firstMonday {
    final startsOn = this.startsOn;
    return startsOn == null ? null : schoolMondayOf(startsOn);
  }
}

class TeachingLessonDetail {
  const TeachingLessonDetail({
    required this.lesson,
    this.teacher,
    this.note,
    this.weekNumber,
    this.weekday,
  });

  final Lesson lesson;
  final String? teacher;
  final String? note;
  final int? weekNumber;
  final int? weekday;
}

/// 教务来源的本地快照：学期、课次、节次与解析问题。
class TeachingStore implements LessonQuery {
  TeachingStore(
    this.database,
    this.userId,
    this.snapshots,
    this.courses, {
    this.source,
    DateTime Function()? now,
  }) : _database = database.database,
       _now = now ?? DateTime.now;

  final LocalDatabase database;
  final String userId;
  final SourceSnapshotStore snapshots;
  final CourseStore courses;
  final SourceContext? source;
  final Database _database;
  final DateTime Function() _now;

  Future<List<TeachingSemester>> listSemesters() async {
    final rows = await _database.rawQuery(
      '''
SELECT semesters.*, calendars.starts_on AS starts_on,
       calendars.total_weeks AS total_weeks
FROM teaching_semesters AS semesters
LEFT JOIN teaching_calendars AS calendars
  ON calendars.user_id = semesters.user_id
  AND calendars.semester_id = semesters.id
WHERE semesters.user_id = ?
ORDER BY semesters.is_current DESC, calendars.starts_on DESC,
         semesters.source_id DESC
''',
      [userId],
    );
    return rows.map(_semesterFromRow).toList();
  }

  Future<TeachingSemester?> semesterByCode(String code) async {
    final rows = await _database.rawQuery(
      '''
SELECT semesters.*, calendars.starts_on AS starts_on,
       calendars.total_weeks AS total_weeks
FROM teaching_semesters AS semesters
LEFT JOIN teaching_calendars AS calendars
  ON calendars.user_id = semesters.user_id
  AND calendars.semester_id = semesters.id
WHERE semesters.user_id = ? AND semesters.source_id = ?
LIMIT 1
''',
      [userId, code],
    );
    return rows.isEmpty ? null : _semesterFromRow(rows.first);
  }

  Future<SourceSnapshot> snapshotForSemester(String semesterCode) {
    return snapshots.read(
      teachingSource,
      teachingTimetableResource,
      scopeKey: semesterCode,
    );
  }

  Future<SourceSnapshot> semesterSnapshot() {
    return snapshots.read(teachingSource, teachingSemesterResource);
  }

  Future<List<String>> warningsForSemester(String semesterId) async {
    final rows = await _database.query(
      'teaching_parse_issues',
      where: 'user_id = ? AND semester_id = ?',
      whereArgs: [userId, semesterId],
      orderBy: 'observed_at_utc DESC, message',
    );
    return rows.map((row) => row['message'] as String).toList();
  }

  Future<List<JluPeriodTime>> periodTimes() async {
    final rows = await _database.query(
      'teaching_period_times',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'campus, period',
    );
    return rows
        .map(
          (row) => JluPeriodTime(
            period: row['period'] as int,
            campus: row['campus'] as String,
            startMinute: row['start_minute'] as int,
            endMinute: row['end_minute'] as int,
          ),
        )
        .toList();
  }

  @override
  Future<List<Lesson>> lessonsBetween(LocalDate from, LocalDate to) async {
    final rows = await _database.query(
      'teaching_lessons',
      where: 'user_id = ? AND starts_at_utc < ? AND ends_at_utc > ?',
      whereArgs: [
        userId,
        schoolDayStartUtc(to).millisecondsSinceEpoch,
        schoolDayStartUtc(from).millisecondsSinceEpoch,
      ],
      orderBy: 'starts_at_utc',
    );
    return rows.map(_lessonFromRow).toList();
  }

  Future<List<TeachingLessonDetail>> lessonDetailsBetween(
    String semesterId,
    LocalDate from,
    LocalDate to,
  ) async {
    final rows = await _database.rawQuery(
      '''
SELECT lessons.*, offerings.teacher AS teacher
FROM teaching_lessons AS lessons
JOIN course_offerings AS offerings
  ON offerings.id = lessons.course_offering_id
  AND offerings.user_id = lessons.user_id
WHERE lessons.user_id = ?
  AND lessons.semester_id = ?
  AND lessons.starts_at_utc < ?
  AND lessons.ends_at_utc > ?
ORDER BY lessons.starts_at_utc
''',
      [
        userId,
        semesterId,
        schoolDayStartUtc(to).millisecondsSinceEpoch,
        schoolDayStartUtc(from).millisecondsSinceEpoch,
      ],
    );
    return rows
        .map(
          (row) => TeachingLessonDetail(
            lesson: _lessonFromRow(row),
            teacher: row['teacher'] as String?,
            note: row['note'] as String?,
            weekNumber: row['week_number'] as int?,
            weekday: row['weekday'] as int?,
          ),
        )
        .toList();
  }

  Future<SourceResult<String>> syncCurrentSemester({SourceHttpClient? http}) {
    final client = _httpClient(http);
    final executor = SourceExecutor(snapshots: snapshots, now: _now);
    return executor.run<String>(
      source: teachingSource,
      resource: teachingSemesterResource,
      fetch: () => JluTimetableSource(http: client).currentSemester(),
      persist: _persistCurrentSemester,
    );
  }

  Future<SourceResult<JluTimetableFetch>> refreshSemester({
    SourceHttpClient? http,
    required String semesterCode,
  }) {
    if (!isJluSemesterCode(semesterCode)) {
      throw JluParseException('教务学期格式无法识别：$semesterCode');
    }
    final client = _httpClient(http);
    final executor = SourceExecutor(snapshots: snapshots, now: _now);
    return executor.run<JluTimetableFetch>(
      source: teachingSource,
      resource: teachingTimetableResource,
      scopeKey: semesterCode,
      fetch: () =>
          JluTimetableSource(http: client).fetch(semesterCode: semesterCode),
      persist: _persistSemester,
    );
  }

  Future<void> _persistCurrentSemester(String code, DateTime observedAt) async {
    final timestamp = observedAt.toUtc().millisecondsSinceEpoch;
    await _database.transaction((transaction) async {
      await transaction.update(
        'teaching_semesters',
        <String, Object?>{'is_current': 0},
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      await transaction.rawInsert(
        '''
INSERT INTO teaching_semesters(
  id, user_id, source, source_scope, source_id, name, is_current,
  last_observed_at_utc, created_at_utc, updated_at_utc
) VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  name = excluded.name,
  is_current = 1,
  last_observed_at_utc = excluded.last_observed_at_utc,
  updated_at_utc = excluded.updated_at_utc
''',
        [
          _semesterId(code),
          userId,
          teachingSource.databaseValue,
          teachingSemesterScope,
          code,
          jluSemesterName(code),
          timestamp,
          timestamp,
          timestamp,
        ],
      );
    });
  }

  Future<void> _persistSemester(
    JluTimetableFetch value,
    DateTime observedAt,
  ) async {
    final timestamp = observedAt.toUtc().millisecondsSinceEpoch;
    final semesterId = _semesterId(value.semesterCode);
    final timetable = value.timetable;
    final sourceCourses = <String, SourceCourse>{};
    for (final lesson in timetable.lessons) {
      final sourceId = _courseSourceId(lesson);
      final existing = sourceCourses[sourceId];
      if (existing == null) {
        sourceCourses[sourceId] = _sourceCourse(value.semesterCode, lesson);
      } else if (existing.teacher == null && lesson.teacher != null) {
        sourceCourses[sourceId] = _sourceCourse(value.semesterCode, lesson);
      }
    }
    await courses.applySnapshot(
      source: teachingSource,
      scope: value.semesterCode,
      courses: sourceCourses.values.toList(growable: false),
      complete: true,
    );
    final offeringIds = <String, String>{
      for (final offering in await courses.list(source: teachingSource))
        if (offering.sourceRef.sourceScope == value.semesterCode)
          offering.sourceRef.sourceId: offering.id,
    };
    final courseSourceByLesson = <String, String>{
      for (final lesson in timetable.lessons)
        lesson.sourceId: _courseSourceId(lesson),
    };
    final occurrences = expandJluLessonOccurrences(timetable);
    await _database.transaction((transaction) async {
      await transaction.rawInsert(
        '''
INSERT INTO teaching_semesters(
  id, user_id, source, source_scope, source_id, name, is_current,
  last_observed_at_utc, created_at_utc, updated_at_utc
) VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  name = excluded.name,
  last_observed_at_utc = excluded.last_observed_at_utc,
  updated_at_utc = excluded.updated_at_utc
''',
        [
          semesterId,
          userId,
          teachingSource.databaseValue,
          teachingSemesterScope,
          value.semesterCode,
          jluSemesterName(value.semesterCode),
          timestamp,
          timestamp,
          timestamp,
        ],
      );
      await transaction.rawInsert(
        '''
INSERT INTO teaching_calendars(
  user_id, semester_id, starts_on, total_weeks, observed_at_utc
) VALUES (?, ?, ?, ?, ?)
ON CONFLICT(user_id, semester_id) DO UPDATE SET
  starts_on = excluded.starts_on,
  total_weeks = excluded.total_weeks,
  observed_at_utc = excluded.observed_at_utc
''',
        [
          userId,
          semesterId,
          timetable.semesterStart,
          timetable.totalWeeks,
          timestamp,
        ],
      );
      await transaction.delete(
        'teaching_period_times',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      for (final period in timetable.periodTimes) {
        await transaction.insert('teaching_period_times', <String, Object?>{
          'user_id': userId,
          'campus': period.campus,
          'period': period.period,
          'start_minute': period.startMinute,
          'end_minute': period.endMinute,
          'updated_at_utc': timestamp,
        });
      }
      await transaction.delete(
        'teaching_lessons',
        where: 'user_id = ? AND semester_id = ?',
        whereArgs: [userId, semesterId],
      );
      for (final occurrence in occurrences) {
        final courseSourceId = courseSourceByLesson[occurrence.lessonSourceId]!;
        final offeringId = offeringIds[courseSourceId]!;
        await transaction.insert('teaching_lessons', <String, Object?>{
          'id': occurrence.id,
          'user_id': userId,
          'semester_id': semesterId,
          'course_offering_id': offeringId,
          'title': occurrence.title,
          'starts_at_utc': occurrence.startsAtUtc.millisecondsSinceEpoch,
          'ends_at_utc': occurrence.endsAtUtc.millisecondsSinceEpoch,
          'location': occurrence.location,
          'period_start': occurrence.periodStart,
          'period_end': occurrence.periodEnd,
          'weekday': occurrence.weekday,
          'week_number': occurrence.weekNumber,
          'source_lesson_id': occurrence.lessonSourceId,
          'note': occurrence.note,
          'created_at_utc': timestamp,
          'updated_at_utc': timestamp,
        });
      }
      await transaction.delete(
        'teaching_parse_issues',
        where: 'user_id = ? AND semester_id = ?',
        whereArgs: [userId, semesterId],
      );
      for (final warning in value.warnings.toSet()) {
        await transaction.insert('teaching_parse_issues', <String, Object?>{
          'user_id': userId,
          'semester_id': semesterId,
          'message': warning,
          'observed_at_utc': timestamp,
        });
      }
    });
  }

  SourceCourse _sourceCourse(String semesterCode, JluLesson lesson) {
    return SourceCourse(
      source: teachingSource,
      sourceScope: semesterCode,
      sourceId: _courseSourceId(lesson),
      name: lesson.courseName,
      teacher: lesson.teacher,
      semesterId: _semesterId(semesterCode),
    );
  }

  SourceHttpClient _httpClient(SourceHttpClient? http) {
    final client = http ?? source?.http;
    if (client == null) {
      throw StateError('TeachingStore needs a SourceHttpClient');
    }
    return client;
  }

  String _semesterId(String code) => 'teaching:$userId:$code';

  TeachingSemester _semesterFromRow(Map<String, Object?> row) {
    final startsOn = row['starts_on'] as String?;
    return TeachingSemester(
      id: row['id'] as String,
      code: row['source_id'] as String,
      name: row['name'] as String,
      startsOn: startsOn == null ? null : LocalDate.parse(startsOn),
      totalWeeks: row['total_weeks'] as int?,
      isCurrent: (row['is_current'] as int) == 1,
    );
  }

  Lesson _lessonFromRow(Map<String, Object?> row) {
    return Lesson(
      id: row['id'] as String,
      courseOfferingId: row['course_offering_id'] as String,
      title: row['title'] as String,
      startsAtUtc: DateTime.fromMillisecondsSinceEpoch(
        row['starts_at_utc'] as int,
        isUtc: true,
      ),
      endsAtUtc: DateTime.fromMillisecondsSinceEpoch(
        row['ends_at_utc'] as int,
        isUtc: true,
      ),
      location: row['location'] as String?,
      periodStart: row['period_start'] as int?,
      periodEnd: row['period_end'] as int?,
    );
  }
}

String jluSemesterName(String code) {
  final term = code.substring(10);
  final label = switch (term) {
    '1' => '秋季学期',
    '2' => '春季学期',
    '3' => '夏季学期',
    _ => '第 $term 学期',
  };
  return '${code.substring(0, 9)} $label';
}

String _courseSourceId(JluLesson lesson) {
  if (lesson.kbId.isNotEmpty) return lesson.kbId;
  if (lesson.courseCode.isNotEmpty) return lesson.courseCode;
  return lesson.sourceId;
}
