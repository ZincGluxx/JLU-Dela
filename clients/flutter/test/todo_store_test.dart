import 'package:flutter_test/flutter_test.dart';
import 'package:jlu_dela/core/models/local_date.dart';
import 'package:jlu_dela/core/models/todo.dart';
import 'package:jlu_dela/core/storage/local_database.dart';
import 'package:jlu_dela/core/storage/todo_store.dart';

import 'support/local_database_test_support.dart';

void main() {
  late LocalDatabase database;
  late TodoStore store;
  late DateTime clock;

  setUp(() async {
    database = await openTestDatabase();
    clock = DateTime.utc(2026, 11, 12, 4, 30);
    store = TodoStore(database, 'user-a', now: () => clock);
  });

  tearDown(() async {
    store.dispose();
    await database.close();
  });

  test('supports the three due kinds and sorts dated todos first', () async {
    final undated = await store.create(title: '无日期');
    final dateOnly = await store.create(
      title: '只有日期',
      due: const TodoDue.dateOnly(LocalDate(2026, 11, 14)),
    );
    final exact = await store.create(
      title: '精确时刻',
      due: TodoDue.exact(DateTime.utc(2026, 11, 13, 10)),
      color: CalendarColor.teal,
      showInCalendar: true,
    );

    expect(undated.dueKind, TodoDueKind.none);
    expect(undated.dueDate, isNull);
    expect(undated.dueAtUtc, isNull);
    expect(undated.showInCalendar, isFalse);
    expect(dateOnly.dueKind, TodoDueKind.dateOnly);
    expect(dateOnly.dueDate, const LocalDate(2026, 11, 14));
    expect(exact.dueKind, TodoDueKind.exact);
    expect(exact.dueAtUtc, DateTime.utc(2026, 11, 13, 10));
    expect(exact.color, CalendarColor.teal);
    expect(exact.showInCalendar, isTrue);

    final listed = await store.list();
    expect(listed.map((todo) => todo.id), [exact.id, dateOnly.id, undated.id]);
  });

  test('update replaces fields and advances the revision', () async {
    final created = await store.create(title: '原标题');
    created
      ..title = '  新标题  '
      ..notes = '新的备注'
      ..color = CalendarColor.rose
      ..showInCalendar = true;

    final updated = await store.update(created);

    expect(updated.title, '新标题');
    expect(updated.notes, '新的备注');
    expect(updated.color, CalendarColor.rose);
    expect(updated.showInCalendar, isTrue);
    expect(updated.revision, 2);
    final stored = await store.get(created.id);
    expect(stored?.title, '新标题');
    expect(stored?.revision, 2);
  });

  test('completed todos can be hidden and the flag is reversible', () async {
    final created = await store.create(title: '完成我');

    final completed = await store.setCompleted(
      created.id,
      revision: created.revision,
      completed: true,
    );
    expect(completed.completed, isTrue);
    expect(completed.completedAtUtc, DateTime.utc(2026, 11, 12, 4, 30));
    expect(completed.revision, 2);
    expect(await store.list(includeCompleted: false), isEmpty);

    final reopened = await store.setCompleted(
      created.id,
      revision: completed.revision,
      completed: false,
    );
    expect(reopened.completed, isFalse);
    expect(reopened.completedAtUtc, isNull);
    expect(await store.list(includeCompleted: false), hasLength(1));
  });

  test('stale revisions raise a conflict carrying the current row', () async {
    final created = await store.create(title: '并发');
    await store.update(created);

    await expectLater(
      store.update(created),
      throwsA(
        isA<TodoRevisionConflict>().having(
          (conflict) => conflict.current.revision,
          'current revision',
          2,
        ),
      ),
    );

    await expectLater(
      store.setCompleted(created.id, revision: 1, completed: true),
      throwsA(isA<TodoRevisionConflict>()),
    );

    await expectLater(
      store.delete(created.id, revision: 1),
      throwsA(isA<TodoRevisionConflict>()),
    );
    expect(await store.get(created.id), isNotNull);
  });

  test('delete removes the todo', () async {
    final created = await store.create(title: '删除我');

    await store.delete(created.id, revision: created.revision);

    expect(await store.get(created.id), isNull);
    expect(await store.list(), isEmpty);
    await expectLater(
      store.delete(created.id, revision: created.revision),
      throwsA(isA<TodoNotFoundException>()),
    );
  });

  test('invalid input is rejected without writing', () async {
    await expectLater(
      store.create(title: '   '),
      throwsA(isA<TodoValidationException>()),
    );
    await expectLater(
      store.create(title: 'a' * 201),
      throwsA(isA<TodoValidationException>()),
    );
    await expectLater(
      store.create(title: 'ok', notes: 'a' * 20001),
      throwsA(isA<TodoValidationException>()),
    );
    expect(await store.list(), isEmpty);

    final created = await store.create(title: '合法');
    created.title = '';
    await expectLater(
      store.update(created),
      throwsA(isA<TodoValidationException>()),
    );
    expect((await store.get(created.id))?.title, '合法');
  });

  test('notifies listeners only after a write succeeds', () async {
    var notifications = 0;
    store.addListener(() => notifications++);

    final created = await store.create(title: '通知');
    expect(notifications, 1);

    created.title = '';
    await expectLater(
      store.update(created),
      throwsA(isA<TodoValidationException>()),
    );
    expect(notifications, 1);

    await store.delete(created.id, revision: created.revision);
    expect(notifications, 2);
  });

  test('reopening the database keeps todos', () async {
    final path = await createTempDatabasePath();
    final firstDatabase = await openTempFileDatabase(path);
    final firstStore = TodoStore(firstDatabase, 'user-a', now: () => clock);
    final created = await firstStore.create(
      title: '重启后仍在',
      due: TodoDue.exact(DateTime.utc(2026, 11, 20, 9)),
      color: CalendarColor.sage,
    );
    firstStore.dispose();
    await firstDatabase.close();

    final secondDatabase = await openTempFileDatabase(path);
    final secondStore = TodoStore(secondDatabase, 'user-a');
    addTearDown(() async {
      secondStore.dispose();
      await secondDatabase.close();
    });

    final restored = await secondStore.list();
    expect(restored, hasLength(1));
    expect(restored.single.id, created.id);
    expect(restored.single.title, '重启后仍在');
    expect(restored.single.color, CalendarColor.sage);
    expect(restored.single.dueAtUtc, DateTime.utc(2026, 11, 20, 9));
  });
}
