import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/models/local_date.dart';
import 'package:jlu_dela/core/models/todo.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
import 'package:jlu_dela/core/storage/local_workspace.dart';

import 'support/local_database_test_support.dart';
import 'todo_test_support.dart';

void main() {
  test(
    'real sqlite keeps todos and drafts across reopen and isolates users',
    () async {
      final path = await createTempDatabasePath();
      LocalDatabase? firstDatabase;
      LocalDatabase? secondDatabase;
      final workspaces = <LocalWorkspace>[];
      addTearDown(() async {
        for (final workspace in workspaces) {
          workspace.dispose();
        }
        if (secondDatabase != null) {
          await secondDatabase.close();
        }
        if (firstDatabase != null) {
          await firstDatabase.close();
        }
      });

      firstDatabase = await openTempFileDatabase(path);
      final first = buildTodoWorkspace(database: firstDatabase);
      workspaces.add(first);
      final dateOnly = await first.todos.create(
        title: '重启后仍在',
        notes: '本地备注',
        due: const TodoDue.dateOnly(LocalDate(2026, 11, 30)),
        color: CalendarColor.sage,
        showInCalendar: true,
      );
      final exact = await first.todos.create(
        title: '精确时刻',
        due: TodoDue.exact(DateTime.utc(2026, 11, 13, 10)),
      );
      await first.drafts.write('todo', 'new', {'title': '未保存草稿'});
      await firstDatabase.close();
      firstDatabase = null;

      secondDatabase = await openTempFileDatabase(path);
      final userA = buildTodoWorkspace(database: secondDatabase);
      final userB = buildTodoWorkspace(
        database: secondDatabase,
        userId: 'user-b',
      );
      workspaces
        ..add(userA)
        ..add(userB);

      final restored = await userA.todos.list();
      expect(restored, hasLength(2));
      final restoredDateOnly = restored.singleWhere(
        (todo) => todo.id == dateOnly.id,
      );
      expect(restoredDateOnly.title, '重启后仍在');
      expect(restoredDateOnly.notes, '本地备注');
      expect(restoredDateOnly.dueKind, TodoDueKind.dateOnly);
      expect(restoredDateOnly.dueDate, const LocalDate(2026, 11, 30));
      expect(restoredDateOnly.dueAtUtc, isNull);
      expect(restoredDateOnly.color, CalendarColor.sage);
      expect(restoredDateOnly.showInCalendar, isTrue);
      expect(
        restored.singleWhere((todo) => todo.id == exact.id).dueAtUtc,
        DateTime.utc(2026, 11, 13, 10),
      );
      expect(await userA.drafts.read('todo', 'new'), {'title': '未保存草稿'});

      expect(await userB.todos.list(), isEmpty);
      expect(await userB.todos.get(dateOnly.id), isNull);
      expect(await userB.drafts.read('todo', 'new'), isNull);
    },
  );
}
