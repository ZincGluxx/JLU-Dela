import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/models/local_date.dart';
import 'package:jlu_dela/core/models/todo.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
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

  testWidgets('loading, empty and error states are distinguishable', (
    tester,
  ) async {
    final delayedStore = DelayedTodoStore(database, 'user-a');
    final delayedWorkspace = buildTodoWorkspace(
      database: database,
      todos: delayedStore,
    );
    addTearDown(delayedWorkspace.dispose);

    await pumpTodoPage(tester, delayedWorkspace, settle: false);
    expect(find.byKey(const Key('todo-loading')), findsOneWidget);

    delayedStore.gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todo-loading')), findsNothing);
    expect(find.byKey(const Key('todo-empty')), findsOneWidget);

    await database.close();
    databaseClosed = true;
    await pumpTodoPage(tester, workspace);
    expect(find.byKey(const Key('todo-error')), findsOneWidget);
    expect(find.byKey(const Key('todo-empty')), findsNothing);
    expect(find.text('读取待办失败'), findsOneWidget);

    await tester.tap(find.byKey(const Key('todo-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('todo-error')), findsOneWidget);
  });

  testWidgets('empty state opens the editor from the empty action', (
    tester,
  ) async {
    await pumpTodoPage(tester, workspace);
    expect(find.byKey(const Key('todo-empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('todo-create-empty')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('todo-title-field')), findsOneWidget);
    expect(find.text('新建待办'), findsWidgets);
  });

  testWidgets('lists unfinished todos first with the three due labels', (
    tester,
  ) async {
    final completed = await workspace.todos.create(title: '已经做完');
    await workspace.todos.setCompleted(
      completed.id,
      revision: completed.revision,
      completed: true,
    );
    final lateExact = await workspace.todos.create(
      title: '后天会议',
      due: TodoDue.exact(DateTime.utc(2026, 11, 14, 10)),
    );
    final soonExact = await workspace.todos.create(
      title: '明天下午',
      due: TodoDue.exact(DateTime.utc(2026, 11, 13, 10)),
      color: CalendarColor.rose,
      showInCalendar: true,
    );
    final dateOnly = await workspace.todos.create(
      title: '周末整理',
      due: const TodoDue.dateOnly(LocalDate(2026, 11, 14)),
    );
    final undated = await workspace.todos.create(title: '随手记');

    await pumpTodoPage(tester, workspace);

    double topOf(Todo todo) =>
        tester.getTopLeft(find.byKey(Key('todo-item-${todo.id}'))).dy;

    expect(topOf(soonExact), lessThan(topOf(dateOnly)));
    expect(topOf(dateOnly), lessThan(topOf(lateExact)));
    expect(topOf(lateExact), lessThan(topOf(undated)));
    expect(topOf(undated), lessThan(topOf(completed)));

    expect(find.text('明天 18:00'), findsOneWidget);
    expect(find.text('11月14日 · 全天'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(Key('todo-item-${undated.id}')),
        matching: find.text('无截止'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(Key('todo-calendar-${soonExact.id}')), findsOneWidget);
    expect(find.byKey(Key('todo-calendar-${dateOnly.id}')), findsNothing);
    expect(find.byKey(Key('todo-color-${soonExact.id}')), findsOneWidget);
  });

  testWidgets('marks only active past due todos as overdue', (tester) async {
    await workspace.todos.create(
      title: '逾期的时刻',
      due: TodoDue.exact(DateTime.utc(2026, 11, 11, 10)),
    );
    await workspace.todos.create(
      title: '逾期的日期',
      due: const TodoDue.dateOnly(LocalDate(2026, 11, 11)),
    );
    final completed = await workspace.todos.create(
      title: '完成但过期',
      due: const TodoDue.dateOnly(LocalDate(2026, 11, 11)),
    );
    await workspace.todos.setCompleted(
      completed.id,
      revision: completed.revision,
      completed: true,
    );
    await workspace.todos.create(
      title: '明天的日期',
      due: const TodoDue.dateOnly(LocalDate(2026, 11, 13)),
    );

    await pumpTodoPage(tester, workspace);

    expect(find.text('已逾期'), findsNWidgets(2));
    final completedItem = find.byKey(Key('todo-item-${completed.id}'));
    expect(
      find.descendant(of: completedItem, matching: find.text('已逾期')),
      findsNothing,
    );
  });

  testWidgets('checkbox toggles completion and moves the todo down', (
    tester,
  ) async {
    final first = await workspace.todos.create(
      title: '第一件',
      due: TodoDue.exact(DateTime.utc(2026, 11, 13, 10)),
    );
    final second = await workspace.todos.create(
      title: '第二件',
      due: TodoDue.exact(DateTime.utc(2026, 11, 14, 10)),
    );

    await pumpTodoPage(tester, workspace);
    await tester.tap(find.byKey(Key('todo-checkbox-${first.id}')));
    await tester.pumpAndSettle();

    final stored = await tester.runAsync(() => workspace.todos.get(first.id));
    expect(stored?.completed, isTrue);
    expect(
      tester.getTopLeft(find.byKey(Key('todo-item-${first.id}'))).dy,
      greaterThan(
        tester.getTopLeft(find.byKey(Key('todo-item-${second.id}'))).dy,
      ),
    );
    expect(find.text('1 项未完成 · 1 项已完成'), findsOneWidget);
  });

  testWidgets('a page for another user never shows the previous user data', (
    tester,
  ) async {
    final otherWorkspace = buildTodoWorkspace(
      database: database,
      userId: 'user-b',
    );
    addTearDown(otherWorkspace.dispose);
    await workspace.todos.create(title: '甲的待办');
    await otherWorkspace.todos.create(title: '乙的待办');

    await pumpTodoPage(tester, workspace);
    expect(find.text('甲的待办'), findsOneWidget);
    expect(find.text('乙的待办'), findsNothing);

    await pumpTodoPage(tester, otherWorkspace);
    expect(find.text('乙的待办'), findsOneWidget);
    expect(find.text('甲的待办'), findsNothing);
  });

  testWidgets('narrow screens keep the list and editor usable', (tester) async {
    await workspace.todos.create(
      title: '很长的待办标题' * 8,
      notes: '很长的备注' * 120,
      due: TodoDue.exact(DateTime.utc(2026, 11, 13, 10)),
      color: CalendarColor.sage,
      showInCalendar: true,
    );
    await workspace.todos.create(title: '第二条', notes: '短备注');

    await pumpTodoPage(tester, workspace, size: const Size(390, 844));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('todo-create')), findsOneWidget);

    await tester.tap(find.byKey(const Key('todo-create')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('todo-due-kind-exact')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('todo-due-hour-plus')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('todo-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-cancel')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
