import '../../core/models/lesson.dart';
import '../../core/models/local_date.dart';
import '../../core/storage/course_store.dart';
import '../../core/storage/local_database.dart';
import '../../core/storage/queries.dart';
import '../../core/storage/source_snapshot_store.dart';

class TeachingStore implements LessonQuery {
  TeachingStore(this.database, this.userId, this.snapshots, this.courses);

  final LocalDatabase database;
  final String userId;
  final SourceSnapshotStore snapshots;
  final CourseStore courses;

  @override
  Future<List<Lesson>> lessonsBetween(LocalDate from, LocalDate to) async {
    return const [];
  }
}
