import '../../core/models/assignment.dart';
import '../../core/models/local_date.dart';
import '../../core/source/chaoxing_access.dart';
import '../../core/storage/course_store.dart';
import '../../core/storage/local_database.dart';
import '../../core/storage/queries.dart';
import '../../core/storage/source_snapshot_store.dart';

class ChaoxingStore implements AssignmentQuery, ChaoxingAccess {
  ChaoxingStore(this.database, this.userId, this.snapshots, this.courses);

  static const _unavailableAccess = UnavailableChaoxingAccess();

  final LocalDatabase database;
  final String userId;
  final SourceSnapshotStore snapshots;
  final CourseStore courses;

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
  Future<List<MaterialEntry>> listMaterialChildren(String materialId) {
    return _unavailableAccess.listMaterialChildren(materialId);
  }

  @override
  Future<SourceAccess> accessMaterial(String materialId) {
    return _unavailableAccess.accessMaterial(materialId);
  }

  @override
  Future<SourceAccess> openAssignment(String assignmentId) {
    return _unavailableAccess.openAssignment(assignmentId);
  }
}
