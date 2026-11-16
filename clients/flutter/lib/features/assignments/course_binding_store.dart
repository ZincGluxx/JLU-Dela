import '../../core/models/course.dart';
import '../../core/models/source.dart';
import '../../core/storage/course_store.dart';
import '../../core/storage/local_database.dart';

class PlatformCourseBinding {
  const PlatformCourseBinding({
    required this.platformCourse,
    required this.teachingCourseOfferingId,
    required this.teachingCourse,
    required this.semesterId,
    required this.updatedAtUtc,
  });

  final SourceRef platformCourse;
  final String teachingCourseOfferingId;
  final SourceRef teachingCourse;
  final String semesterId;
  final DateTime updatedAtUtc;

  bool matchesPlatform(CourseOffering course) =>
      course.sourceRef.source == platformCourse.source &&
      course.sourceRef.sourceScope == platformCourse.sourceScope &&
      course.sourceRef.sourceId == platformCourse.sourceId;

  bool matchesTeaching(CourseOffering course) =>
      course.sourceRef.source == teachingCourse.source &&
      course.sourceRef.sourceScope == teachingCourse.sourceScope &&
      course.sourceRef.sourceId == teachingCourse.sourceId &&
      course.semesterId == semesterId;
}

class CourseBindingStore {
  CourseBindingStore(
    this.database,
    this.userId,
    this.courses, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final LocalDatabase database;
  final String userId;
  final CourseStore courses;
  final DateTime Function() _now;

  Future<List<PlatformCourseBinding>> list() async {
    final rows = await database.database.query(
      'platform_course_bindings',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'platform_scope, platform_course_id',
    );
    return [
      for (final row in rows)
        PlatformCourseBinding(
          platformCourse: SourceRef(
            source: SourceKind.fromDatabaseValue(row['platform'] as String),
            sourceScope: row['platform_scope'] as String,
            sourceId: row['platform_course_id'] as String,
          ),
          teachingCourseOfferingId:
              row['teaching_course_offering_id'] as String,
          teachingCourse: SourceRef(
            source: SourceKind.jluIedu,
            sourceScope: row['teaching_scope'] as String,
            sourceId: row['teaching_course_id'] as String,
          ),
          semesterId: row['semester_id'] as String,
          updatedAtUtc: DateTime.fromMillisecondsSinceEpoch(
            row['updated_at_utc'] as int,
            isUtc: true,
          ),
        ),
    ];
  }

  Future<void> bind({
    required String platformCourseId,
    required String teachingCourseId,
  }) async {
    final platform = await courses.byId(platformCourseId);
    final teaching = await courses.byId(teachingCourseId);
    if (platform == null ||
        platform.userId != userId ||
        platform.sourceRef.source != SourceKind.chaoxing) {
      throw StateError('请选择当前账号的学习通课程');
    }
    if (teaching == null ||
        teaching.userId != userId ||
        teaching.sourceRef.source != SourceKind.jluIedu ||
        teaching.semesterId == null ||
        teaching.semesterId!.isEmpty) {
      throw StateError('请选择当前账号已获取且带有学期的教务课程');
    }
    final timestamp = _now().toUtc().millisecondsSinceEpoch;
    await database.database.rawInsert(
      '''
INSERT INTO platform_course_bindings(
  user_id, platform, platform_scope, platform_course_id,
  teaching_course_offering_id, teaching_scope, teaching_course_id, semester_id,
  created_at_utc, updated_at_utc
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(user_id, platform, platform_scope, platform_course_id) DO UPDATE SET
  teaching_course_offering_id = excluded.teaching_course_offering_id,
  teaching_scope = excluded.teaching_scope,
  teaching_course_id = excluded.teaching_course_id,
  semester_id = excluded.semester_id,
  updated_at_utc = excluded.updated_at_utc
''',
      [
        userId,
        platform.sourceRef.source.databaseValue,
        platform.sourceRef.sourceScope,
        platform.sourceRef.sourceId,
        teaching.id,
        teaching.sourceRef.sourceScope,
        teaching.sourceRef.sourceId,
        teaching.semesterId,
        timestamp,
        timestamp,
      ],
    );
  }

  Future<void> unbind(SourceRef platformCourse) async {
    await database.database.delete(
      'platform_course_bindings',
      where:
          'user_id = ? AND platform = ? AND platform_scope = ? AND platform_course_id = ?',
      whereArgs: [
        userId,
        platformCourse.source.databaseValue,
        platformCourse.sourceScope,
        platformCourse.sourceId,
      ],
    );
  }
}
