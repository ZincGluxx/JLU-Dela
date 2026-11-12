import '../../core/models/assignment.dart';
import '../../core/models/local_date.dart';
import '../../core/source/chaoxing_access.dart';
import '../../core/source/source_context.dart';
import '../../core/storage/course_store.dart';
import '../../core/storage/local_database.dart';
import '../../core/storage/queries.dart';
import '../../core/storage/source_snapshot_store.dart';

class ChaoxingStore implements AssignmentQuery, ChaoxingAccess {
  ChaoxingStore(
    this.database,
    this.userId,
    this.snapshots,
    this.courses, {
    this.source,
  });

  static const _unavailableAccess = UnavailableChaoxingAccess();

  final LocalDatabase database;
  final String userId;
  final SourceSnapshotStore snapshots;
  final CourseStore courses;
  final SourceContext? source;

  @override
  Future<List<Assignment>> list({
    String? courseId,
    bool includeUndated = true,
    LocalDate? from,
    LocalDate? to,
  }) async {
    return const [];
  }

  @override
  Future<MaterialChildrenPage> listMaterialChildren({
    required String courseOfferingId,
    String? parentSourceId,
    int page = 1,
  }) {
    return _unavailableAccess.listMaterialChildren(
      courseOfferingId: courseOfferingId,
      parentSourceId: parentSourceId,
      page: page,
    );
  }

  @override
  Future<SourceAccess> accessMaterial({
    required String courseOfferingId,
    required String sourceId,
  }) {
    return _unavailableAccess.accessMaterial(
      courseOfferingId: courseOfferingId,
      sourceId: sourceId,
    );
  }

  @override
  Future<SourceAccess> openAssignment({required String assignmentId}) {
    return _unavailableAccess.openAssignment(assignmentId: assignmentId);
  }
}
