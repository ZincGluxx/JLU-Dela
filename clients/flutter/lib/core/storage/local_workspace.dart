import '../source/campus_login.dart';
import '../source/chaoxing_access.dart';
import '../source/source_session.dart';
import 'course_store.dart';
import 'local_database.dart';
import 'local_draft_store.dart';
import 'queries.dart';
import 'source_snapshot_store.dart';
import 'todo_store.dart';

class LocalWorkspace {
  LocalWorkspace({
    required this.userId,
    required this.database,
    required this.now,
    required this.todos,
    required this.drafts,
    required this.courses,
    required this.sources,
    required this.lessons,
    required this.assignments,
    required this.chaoxing,
    required this.sessions,
    required this.http,
    required this.campusLogin,
  });

  final String userId;
  final LocalDatabase database;
  final DateTime Function() now;
  final TodoStore todos;
  final LocalDraftStore drafts;
  final CourseStore courses;
  final SourceSnapshotStore sources;
  final LessonQuery lessons;
  final AssignmentQuery assignments;
  final ChaoxingAccess chaoxing;
  final SourceSessionRegistry sessions;
  final SourceHttpClient http;
  final CampusLogin campusLogin;

  void dispose() {
    todos.dispose();
  }
}
