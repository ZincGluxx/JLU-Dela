import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/models/local_date.dart';
import 'package:jlu_dela/core/models/todo.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
import 'package:jlu_dela/core/storage/local_draft_store.dart';
import 'package:jlu_dela/core/storage/local_workspace.dart';

import 'support/local_database_test_support.dart';
import 'todo_test_support.dart';

void main() {
  late LocalDatabase database;
  late LocalWorkspace workspace;
  late bool databaseClosed;

  setUp(() async {
    databaseClosed = false;
    database = await openTestDatabase();
    workspace = buildTodoWorkspace(database: database);
  });

  tearDown(() async {
    workspace.dispose();
    if (!databaseClosed) {
      await database.close();
    }
  });

  Future<void> openCreateEditor(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('todo-create')));
    await tester.pumpAndSettle();
  }

  Future<void> openTodoEditor(WidgetTester tester, Todo todo) async {
    await tester.tap(find.byKey(Key('todo-item-${todo.id}')));
    await tester.pumpAndSettle();
  }

  Future<void> saveEditor(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('todo-save')));
    await tester.pumpAndSettle();
  }

  testWidgets('creates a todo without a due date and clears its draft', (
    tester,
  ) async {
    await pumpTodoPage(tester, workspace);
    await openCreateEditor(tester);

    await tester.enterText(
      find.byKey(const Key('todo-title-field')),
      '  准备小组展示  ',
    );
    await tester.enterText(find.byKey(const Key('todo-notes-field')), '带上电脑');
    await saveEditor(tester);

    expect(find.byKey(const Key('todo-title-field')), findsNothing);
    final todos = await tester.runAsync(() => workspace.todos.list());
    expect(todos, hasLength(1));
    final created = todos!.single;
    expect(created.title, '准备小组展示');
    expect(created.notes, '带上电脑');
    expect(created.dueKind, TodoDueKind.none);
    expect(created.dueDate, isNull);
    expect(created.dueAtUtc, isNull);
    expect(created.color, CalendarColor.slate);
    expect(created.showInCalendar, isFalse);
    expect(created.revision, 1);
    expect(find.text('已保存'), findsOneWidget);
    final draft = await tester.runAsync(
      () => workspace.drafts.read('todo', 'new'),
    );
    expect(draft, isNull);
  });

  testWidgets('cancel clears drafts after pending writes finish', (
    tester,
  ) async {
    final drafts = _DelayedDraftStore(database, 'user-a');
    final delayedWorkspace = buildTodoWorkspace(
      database: database,
      drafts: drafts,
    );
    addTearDown(delayedWorkspace.dispose);
    await pumpTodoPage(tester, delayedWorkspace);
    await openCreateEditor(tester);
    await tester.enterText(find.byKey(const Key('todo-title-field')), '草稿标题');
    await tester.enterText(find.byKey(const Key('todo-notes-field')), '草稿备注');
    await tester.pump();
    await tester.tap(find.byKey(const Key('todo-cancel')));
    await tester.pump();
    drafts.gate.complete();
    await tester.runAsync(() => drafts.finished.future);
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => drafts.read('todo', 'new')), isNull);
    expect(find.byKey(const Key('todo-title-field')), findsNothing);
  });
  testWidgets('creates a date-only todo without inventing a precise moment', (
    tester,
  ) async {
    await pumpTodoPage(tester, workspace);
    await openCreateEditor(tester);
    await tester.enterText(find.byKey(const Key('todo-title-field')), '周末整理');

    await tester.tap(find.byKey(const Key('todo-due-kind-date')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todo-due-hour-plus')), findsNothing);

    await tester.tap(find.byKey(const Key('todo-due-month-plus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-due-day-plus')));
    await tester.pumpAndSettle();
    await saveEditor(tester);

    final todos = await tester.runAsync(() => workspace.todos.list());
    final created = todos!.single;
    expect(created.dueKind, TodoDueKind.dateOnly);
    expect(created.dueDate, const LocalDate(2026, 12, 13));
    expect(created.dueAtUtc, isNull);
    expect(find.text('12月13日 · 全天'), findsOneWidget);
  });

  testWidgets('creates an exact due in Beijing time and stores it as UTC', (
    tester,
  ) async {
    await pumpTodoPage(tester, workspace);
    await openCreateEditor(tester);
    await tester.enterText(find.byKey(const Key('todo-title-field')), '开组会');

    await tester.tap(find.byKey(const Key('todo-due-kind-exact')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-due-hour-plus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-due-minute-plus')));
    await tester.pumpAndSettle();
    await saveEditor(tester);

    final todos = await tester.runAsync(() => workspace.todos.list());
    final created = todos!.single;
    expect(created.dueKind, TodoDueKind.exact);
    expect(created.dueDate, isNull);
    expect(created.dueAtUtc, DateTime.utc(2026, 11, 12, 5, 31));
    expect(find.text('今天 13:31'), findsOneWidget);
  });

  testWidgets('edits fields, color and the calendar switch', (tester) async {
    final created = await workspace.todos.create(
      title: '原标题',
      color: CalendarColor.blue,
    );
    await pumpTodoPage(tester, workspace);
    await openTodoEditor(tester, created);

    expect(todoTitleValue(tester), '原标题');
    await tester.enterText(find.byKey(const Key('todo-title-field')), '新标题');
    await tester.enterText(find.byKey(const Key('todo-notes-field')), '新的备注');
    await tester.tap(find.byKey(const Key('todo-color-rose')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-calendar-switch')));
    await tester.pumpAndSettle();
    await saveEditor(tester);

    final stored = await tester.runAsync(() => workspace.todos.get(created.id));
    expect(stored?.title, '新标题');
    expect(stored?.notes, '新的备注');
    expect(stored?.color, CalendarColor.rose);
    expect(stored?.showInCalendar, isTrue);
    expect(stored?.revision, 2);
    expect(find.byKey(Key('todo-calendar-${created.id}')), findsOneWidget);
  });

  testWidgets('keeps exact and date-only values stable when editing', (
    tester,
  ) async {
    final exact = await workspace.todos.create(
      title: '精确时刻',
      due: TodoDue.exact(DateTime.utc(2026, 11, 13, 10)),
    );
    final dateOnly = await workspace.todos.create(
      title: '只有日期',
      due: const TodoDue.dateOnly(LocalDate(2026, 11, 14)),
    );
    await pumpTodoPage(tester, workspace);

    await openTodoEditor(tester, exact);
    expect(find.text('18时'), findsOneWidget);
    expect(find.text('00分'), findsOneWidget);
    await saveEditor(tester);
    expect(
      (await tester.runAsync(() => workspace.todos.get(exact.id)))?.dueAtUtc,
      DateTime.utc(2026, 11, 13, 10),
    );

    await openTodoEditor(tester, dateOnly);
    expect(find.text('14日'), findsOneWidget);
    expect(find.byKey(const Key('todo-due-hour-plus')), findsNothing);
    await saveEditor(tester);
    final stored = await tester.runAsync(
      () => workspace.todos.get(dateOnly.id),
    );
    expect(stored?.dueKind, TodoDueKind.dateOnly);
    expect(stored?.dueDate, const LocalDate(2026, 11, 14));
    expect(stored?.dueAtUtc, isNull);
  });

  testWidgets('rejects empty and overlong titles and notes', (tester) async {
    await pumpTodoPage(tester, workspace);
    await openCreateEditor(tester);

    await saveEditor(tester);
    expect(find.text('请输入标题'), findsOneWidget);
    expect(await tester.runAsync(() => workspace.todos.list()), isEmpty);

    await tester.enterText(find.byKey(const Key('todo-title-field')), '   ');
    await saveEditor(tester);
    expect(find.text('请输入标题'), findsOneWidget);
    await tester.tap(find.byKey(const Key('todo-cancel')));
    await tester.pumpAndSettle();

    await workspace.drafts.write('todo', 'new', {
      'title': 'a' * 201,
      'notes': '',
      'dueKind': 'none',
      'dueDate': '2026-11-12',
      'hour': 12,
      'minute': 30,
      'color': 'slate',
      'showInCalendar': false,
    });
    await openCreateEditor(tester);
    expect(find.byKey(const Key('todo-draft-restored')), findsOneWidget);
    await saveEditor(tester);
    expect(find.text('标题不能超过 200 个字符'), findsOneWidget);
    expect(await tester.runAsync(() => workspace.todos.list()), isEmpty);
    await tester.tap(find.byKey(const Key('todo-cancel')));
    await tester.pumpAndSettle();

    await workspace.drafts.write('todo', 'new', {
      'title': '合法标题',
      'notes': 'a' * 20001,
      'dueKind': 'none',
      'dueDate': '2026-11-12',
      'hour': 12,
      'minute': 30,
      'color': 'slate',
      'showInCalendar': false,
    });
    await openCreateEditor(tester);
    await saveEditor(tester);
    expect(find.text('备注不能超过 20000 个字符'), findsOneWidget);
    expect(await tester.runAsync(() => workspace.todos.list()), isEmpty);
  });

  testWidgets('a failed SQLite write keeps the editor and its input open', (
    tester,
  ) async {
    await pumpTodoPage(tester, workspace);
    await openCreateEditor(tester);
    await tester.enterText(find.byKey(const Key('todo-title-field')), '未保存的标题');
    await tester.pumpAndSettle();

    await tester.runAsync(() => database.close());
    databaseClosed = true;

    await saveEditor(tester);

    expect(find.byKey(const Key('todo-editor-error')), findsOneWidget);
    expect(find.textContaining('未保存：'), findsOneWidget);
    expect(find.text('已保存'), findsNothing);
    expect(find.byKey(const Key('todo-title-field')), findsOneWidget);
    expect(todoTitleValue(tester), '未保存的标题');
  });

  testWidgets('a revision conflict can load the latest version', (
    tester,
  ) async {
    final created = await workspace.todos.create(title: '原始标题');
    await pumpTodoPage(tester, workspace);
    await openTodoEditor(tester, created);
    await tester.enterText(find.byKey(const Key('todo-title-field')), '我的修改');
    await tester.pumpAndSettle();
    await updateTodoExternally(tester, workspace, created.id, '别处更新');

    await saveEditor(tester);

    expect(find.byKey(const Key('todo-conflict')), findsOneWidget);
    expect(find.text('内容已在别处更新'), findsOneWidget);
    expect(todoTitleValue(tester), '我的修改');

    await tester.tap(find.byKey(const Key('todo-conflict-load')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todo-conflict')), findsNothing);
    expect(todoTitleValue(tester), '别处更新');

    await saveEditor(tester);
    final stored = await tester.runAsync(() => workspace.todos.get(created.id));
    expect(stored?.title, '别处更新');
    expect(stored?.revision, 3);
  });

  testWidgets('a revision conflict keeps my draft and warns before overwrite', (
    tester,
  ) async {
    final created = await workspace.todos.create(title: '原始标题');
    await pumpTodoPage(tester, workspace);
    await openTodoEditor(tester, created);
    await tester.enterText(find.byKey(const Key('todo-title-field')), '我的修改');
    await tester.pumpAndSettle();
    await updateTodoExternally(tester, workspace, created.id, '别处更新');

    await saveEditor(tester);
    expect(find.byKey(const Key('todo-conflict')), findsOneWidget);

    await tester.tap(find.byKey(const Key('todo-conflict-keep')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todo-conflict')), findsNothing);
    expect(find.byKey(const Key('todo-overwrite-warning')), findsOneWidget);
    expect(todoTitleValue(tester), '我的修改');

    await saveEditor(tester);
    final stored = await tester.runAsync(() => workspace.todos.get(created.id));
    expect(stored?.title, '我的修改');
    expect(stored?.revision, 3);
  });

  testWidgets(
    'a new editor draft survives a page rebuild and cancel clears it',
    (tester) async {
      await pumpTodoPage(tester, workspace);
      await openCreateEditor(tester);
      await tester.enterText(find.byKey(const Key('todo-title-field')), '草稿标题');
      await tester.enterText(find.byKey(const Key('todo-notes-field')), '草稿备注');
      await tester.pumpAndSettle();

      final draft = await readTodoDraftEventually(tester, workspace, 'new');
      expect(draft?['title'], '草稿标题');
      expect(draft?['notes'], '草稿备注');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await pumpTodoPage(tester, workspace);

      expect(find.byKey(const Key('todo-draft-banner')), findsOneWidget);
      await tester.tap(find.byKey(const Key('todo-draft-open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('todo-draft-restored')), findsOneWidget);
      expect(todoTitleValue(tester), '草稿标题');
      expect(todoNotesValue(tester), '草稿备注');

      await tester.tap(find.byKey(const Key('todo-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('todo-draft-banner')), findsNothing);
      final cleared = await tester.runAsync(
        () => workspace.drafts.read('todo', 'new'),
      );
      expect(cleared, isNull);
    },
  );

  testWidgets('a draft for an existing todo is restored when reopened', (
    tester,
  ) async {
    final created = await workspace.todos.create(title: '原始标题');
    await pumpTodoPage(tester, workspace);
    await openTodoEditor(tester, created);
    await tester.enterText(find.byKey(const Key('todo-title-field')), '编辑中的草稿');
    await tester.pumpAndSettle();

    final draft = await readTodoDraftEventually(tester, workspace, created.id);
    expect(draft?['title'], '编辑中的草稿');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpTodoPage(tester, workspace);
    expect(find.byKey(const Key('todo-draft-banner')), findsNothing);

    await openTodoEditor(tester, created);
    expect(find.byKey(const Key('todo-draft-restored')), findsOneWidget);
    expect(todoTitleValue(tester), '编辑中的草稿');

    await tester.tap(find.byKey(const Key('todo-cancel')));
    await tester.pumpAndSettle();
  });

  testWidgets('deleting a todo asks for confirmation first', (tester) async {
    final created = await workspace.todos.create(title: '删除我');
    await pumpTodoPage(tester, workspace);
    await openTodoEditor(tester, created);

    await tester.tap(find.byKey(const Key('todo-delete')));
    await tester.pumpAndSettle();
    expect(find.text('删除这条待办？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('todo-delete-cancel')));
    await tester.pumpAndSettle();
    expect(
      await tester.runAsync(() => workspace.todos.get(created.id)),
      isNotNull,
    );
    expect(find.byKey(const Key('todo-title-field')), findsOneWidget);

    await tester.tap(find.byKey(const Key('todo-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-delete-confirm')));
    await tester.pumpAndSettle();

    expect(
      await tester.runAsync(() => workspace.todos.get(created.id)),
      isNull,
    );
    expect(find.text('已删除'), findsOneWidget);
    expect(find.byKey(const Key('todo-empty')), findsOneWidget);
  });
}

Future<void> updateTodoExternally(
  WidgetTester tester,
  LocalWorkspace workspace,
  String id,
  String title,
) async {
  await tester.runAsync(() async {
    final current = await workspace.todos.get(id);
    current!
      ..title = title
      ..notes = current.notes;
    await workspace.todos.update(current);
  });
}

class _DelayedDraftStore extends LocalDraftStore {
  _DelayedDraftStore(super.database, super.userId);

  final gate = Completer<void>();
  final finished = Completer<void>();
  int writes = 0;

  @override
  Future<void> write(
    String scope,
    String key,
    Map<String, dynamic> payload,
  ) async {
    await gate.future;
    await super.write(scope, key, payload);
    if (++writes == 2) finished.complete();
  }
}
