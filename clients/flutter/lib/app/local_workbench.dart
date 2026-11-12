import '../core/academic/academic_calendar_service.dart';
import '../core/source/campus_login.dart';
import '../core/source/source_context.dart';
import '../core/source/source_portal.dart';
import '../core/source/source_session.dart';
import '../core/storage/course_store.dart';
import '../core/storage/local_database.dart';
import '../core/storage/local_draft_store.dart';
import '../core/storage/local_workspace.dart';
import '../core/storage/source_snapshot_store.dart';
import '../core/storage/todo_store.dart';
import '../features/assignments/chaoxing_store.dart';
import '../features/content/content_store.dart';
import '../features/teaching/teaching_store.dart';

class WorkbenchData {
  const WorkbenchData({
    required this.workspace,
    required this.teachingStore,
    required this.chaoxingStore,
    required this.contentStore,
  });

  final LocalWorkspace workspace;
  final TeachingStore teachingStore;
  final ChaoxingStore chaoxingStore;
  final ContentStore contentStore;

  void dispose() {
    workspace.dispose();
  }
}

WorkbenchData buildWorkbenchData({
  required LocalDatabase database,
  required String userId,
  required SourceSessionRegistry sessions,
  required SourceHttpClient http,
  required CampusLogin campusLogin,
  required SourcePageOpener browser,
  DateTime Function() now = DateTime.now,
  AcademicCalendarService? academicCalendar,
}) {
  final source = SourceContext(
    sessions: sessions,
    http: http,
    campusLogin: campusLogin,
    browser: browser,
  );
  final snapshots = SourceSnapshotStore(database, userId);
  final courses = CourseStore(database, userId, now: now);
  final teachingStore = TeachingStore(
    database,
    userId,
    snapshots,
    courses,
    source: source,
  );
  final chaoxingStore = ChaoxingStore(
    database,
    userId,
    snapshots,
    courses,
    source: source,
  );
  final contentStore = ContentStore(database, userId, source: source);
  final workspace = LocalWorkspace(
    userId: userId,
    database: database,
    now: now,
    todos: TodoStore(database, userId, now: now),
    drafts: LocalDraftStore(database, userId),
    courses: courses,
    sources: snapshots,
    lessons: teachingStore,
    assignments: chaoxingStore,
    chaoxing: chaoxingStore,
    sessions: sessions,
    http: http,
    campusLogin: campusLogin,
    browser: browser,
    source: source,
    academicCalendar: academicCalendar,
  );
  return WorkbenchData(
    workspace: workspace,
    teachingStore: teachingStore,
    chaoxingStore: chaoxingStore,
    contentStore: contentStore,
  );
}
