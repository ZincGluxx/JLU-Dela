import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/app/theme.dart';
import 'package:jlu_dela/core/models/todo.dart';
import 'package:jlu_dela/core/source/campus_login.dart';
import 'package:jlu_dela/core/source/source_context.dart';
import 'package:jlu_dela/core/source/source_portal.dart';
import 'package:jlu_dela/core/source/source_session.dart';
import 'package:jlu_dela/core/storage/course_store.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
import 'package:jlu_dela/core/storage/local_draft_store.dart';
import 'package:jlu_dela/core/storage/local_workspace.dart';
import 'package:jlu_dela/core/storage/source_snapshot_store.dart';
import 'package:jlu_dela/core/storage/todo_store.dart';
import 'package:jlu_dela/features/assignments/chaoxing_store.dart';
import 'package:jlu_dela/features/planner/todo_draft.dart';
import 'package:jlu_dela/features/planner/todo_page.dart';
import 'package:jlu_dela/features/teaching/teaching_store.dart';

DateTime fixedTodoNow() => DateTime.utc(2026, 11, 12, 4, 30);

LocalWorkspace buildTodoWorkspace({
  required LocalDatabase database,
  String userId = 'user-a',
  DateTime Function()? now,
  TodoStore? todos,
  LocalDraftStore? drafts,
}) {
  final clock = now ?? fixedTodoNow;
  final snapshots = SourceSnapshotStore(database, userId);
  final courses = CourseStore(database, userId, now: clock);
  final teaching = TeachingStore(database, userId, snapshots, courses);
  final chaoxing = ChaoxingStore(database, userId, snapshots, courses);
  final sessions = SourceSessionRegistry();
  final http = UnavailableSourceHttpClient(sessions: sessions);
  const campusLogin = UnsupportedCampusLogin();
  const browser = UnsupportedSourcePageOpener();
  final source = SourceContext(
    sessions: sessions,
    http: http,
    campusLogin: campusLogin,
    browser: browser,
  );
  return LocalWorkspace(
    userId: userId,
    database: database,
    now: clock,
    todos: todos ?? TodoStore(database, userId, now: clock),
    drafts: drafts ?? LocalDraftStore(database, userId),
    courses: courses,
    sources: snapshots,
    lessons: teaching,
    assignments: chaoxing,
    chaoxing: chaoxing,
    sessions: sessions,
    http: http,
    campusLogin: campusLogin,
    browser: browser,
    source: source,
  );
}

Future<void> pumpTodoPage(
  WidgetTester tester,
  LocalWorkspace workspace, {
  Size size = const Size(1280, 900),
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: TodoPage(workspace: workspace)),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
}

Future<Map<String, dynamic>?> readTodoDraftEventually(
  WidgetTester tester,
  LocalWorkspace workspace,
  String key,
) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    final draft = await tester.runAsync(
      () => workspace.drafts.read(todoDraftScope, key),
    );
    if (draft != null) {
      return draft;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  return null;
}

String todoTitleValue(WidgetTester tester) {
  final field = tester.widget<TextField>(
    find.byKey(const Key('todo-title-field')),
  );
  return field.controller!.text;
}

String todoNotesValue(WidgetTester tester) {
  final field = tester.widget<TextField>(
    find.byKey(const Key('todo-notes-field')),
  );
  return field.controller!.text;
}

class DelayedTodoStore extends TodoStore {
  DelayedTodoStore(super.database, super.userId);

  final Completer<void> gate = Completer<void>();

  @override
  Future<List<Todo>> list({bool includeCompleted = true}) async {
    await gate.future;
    return super.list(includeCompleted: includeCompleted);
  }
}
