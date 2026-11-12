import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../models/local_date.dart';
import '../models/school_time.dart';
import '../models/todo.dart';
import 'local_database.dart';

class TodoValidationException implements Exception {
  const TodoValidationException(this.message);

  final String message;

  @override
  String toString() => 'TodoValidationException: $message';
}

class TodoRevisionConflict implements Exception {
  const TodoRevisionConflict(this.current);

  final Todo current;

  @override
  String toString() =>
      'TodoRevisionConflict(current revision: ${current.revision})';
}

class TodoNotFoundException implements Exception {
  const TodoNotFoundException(this.id);

  final String id;

  @override
  String toString() => 'TodoNotFoundException($id)';
}

class TodoStore extends ChangeNotifier {
  TodoStore(LocalDatabase database, this.userId, {DateTime Function()? now})
    : _database = database.database,
      _now = now ?? DateTime.now;

  static const int maxTitleLength = 200;
  static const int maxNotesLength = 20000;
  static const _uuid = Uuid();

  final Database _database;
  final String userId;
  final DateTime Function() _now;

  Future<List<Todo>> list({bool includeCompleted = true}) async {
    final rows = await _database.query(
      'todos',
      where: includeCompleted ? 'user_id = ?' : 'user_id = ? AND completed = 0',
      whereArgs: [userId],
    );
    return rows.map(_todoFromRow).toList()..sort(_compareTodos);
  }

  Future<Todo?> get(String id) async {
    final rows = await _database.query(
      'todos',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
      limit: 1,
    );
    return rows.isEmpty ? null : _todoFromRow(rows.first);
  }

  Future<Todo> create({
    required String title,
    String notes = '',
    TodoDue due = const TodoDue.none(),
    CalendarColor? color,
    bool showInCalendar = false,
  }) async {
    final normalizedTitle = _validatedTitle(title);
    _validateNotes(notes);
    _validateDue(due.kind, due.date, due.atUtc);
    final timestamp = _now().toUtc();
    final todo = Todo(
      id: _uuid.v4(),
      userId: userId,
      title: normalizedTitle,
      notes: notes,
      dueKind: due.kind,
      dueDate: due.date,
      dueAtUtc: due.atUtc?.toUtc(),
      color: color,
      showInCalendar: showInCalendar,
      completed: false,
      completedAtUtc: null,
      revision: 1,
      createdAtUtc: timestamp,
      updatedAtUtc: timestamp,
    );
    await _database.insert('todos', _rowOf(todo));
    notifyListeners();
    return todo;
  }

  Future<Todo> update(Todo todo) async {
    if (todo.userId != userId) {
      throw const TodoValidationException('不能更新其他用户的待办');
    }
    final normalizedTitle = _validatedTitle(todo.title);
    _validateNotes(todo.notes);
    _validateDue(todo.dueKind, todo.dueDate, todo.dueAtUtc);
    final timestamp = _now().toUtc();
    final updated = Todo(
      id: todo.id,
      userId: userId,
      title: normalizedTitle,
      notes: todo.notes,
      dueKind: todo.dueKind,
      dueDate: todo.dueDate,
      dueAtUtc: todo.dueAtUtc?.toUtc(),
      color: todo.color,
      showInCalendar: todo.showInCalendar,
      completed: todo.completed,
      completedAtUtc: todo.completedAtUtc?.toUtc(),
      revision: todo.revision + 1,
      createdAtUtc: todo.createdAtUtc,
      updatedAtUtc: timestamp,
    );
    final changed = await _database.update(
      'todos',
      _rowOf(updated),
      where: 'id = ? AND user_id = ? AND revision = ?',
      whereArgs: [todo.id, userId, todo.revision],
    );
    if (changed == 0) {
      throw TodoRevisionConflict(await _currentOrThrow(todo.id));
    }
    notifyListeners();
    return updated;
  }

  Future<Todo> setCompleted(
    String id, {
    required int revision,
    required bool completed,
  }) async {
    final timestamp = _now().toUtc();
    final changed = await _database.update(
      'todos',
      {
        'completed': completed ? 1 : 0,
        'completed_at_utc': completed ? _millisecondsOf(timestamp) : null,
        'revision': revision + 1,
        'updated_at_utc': _millisecondsOf(timestamp),
      },
      where: 'id = ? AND user_id = ? AND revision = ?',
      whereArgs: [id, userId, revision],
    );
    if (changed == 0) {
      throw TodoRevisionConflict(await _currentOrThrow(id));
    }
    notifyListeners();
    return (await get(id))!;
  }

  Future<void> delete(String id, {required int revision}) async {
    final changed = await _database.delete(
      'todos',
      where: 'id = ? AND user_id = ? AND revision = ?',
      whereArgs: [id, userId, revision],
    );
    if (changed == 0) {
      throw TodoRevisionConflict(await _currentOrThrow(id));
    }
    notifyListeners();
  }

  String _validatedTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw const TodoValidationException('标题不能为空');
    }
    if (trimmed.runes.length > maxTitleLength) {
      throw const TodoValidationException('标题不能超过 200 个字符');
    }
    return trimmed;
  }

  void _validateNotes(String notes) {
    if (notes.runes.length > maxNotesLength) {
      throw const TodoValidationException('备注不能超过 20000 个字符');
    }
  }

  void _validateDue(TodoDueKind kind, LocalDate? date, DateTime? atUtc) {
    final consistent = switch (kind) {
      TodoDueKind.none => date == null && atUtc == null,
      TodoDueKind.dateOnly => date != null && atUtc == null,
      TodoDueKind.exact => date == null && atUtc != null,
    };
    if (!consistent) {
      throw const TodoValidationException('截止时间与截止类型不一致');
    }
  }

  int? _dueSortKey(Todo todo) {
    return switch (todo.dueKind) {
      TodoDueKind.exact => todo.dueAtUtc?.millisecondsSinceEpoch,
      TodoDueKind.dateOnly =>
        todo.dueDate == null
            ? null
            : schoolDayStartUtc(todo.dueDate!).millisecondsSinceEpoch,
      TodoDueKind.none => null,
    };
  }

  int _compareTodos(Todo left, Todo right) {
    final leftKey = _dueSortKey(left);
    final rightKey = _dueSortKey(right);
    if (leftKey != rightKey) {
      if (leftKey == null) {
        return 1;
      }
      if (rightKey == null) {
        return -1;
      }
      return leftKey.compareTo(rightKey);
    }
    final titleOrder = left.title.compareTo(right.title);
    if (titleOrder != 0) {
      return titleOrder;
    }
    return left.id.compareTo(right.id);
  }

  Future<Todo> _currentOrThrow(String id) async {
    final current = await get(id);
    if (current == null) {
      throw TodoNotFoundException(id);
    }
    return current;
  }

  Map<String, Object?> _rowOf(Todo todo) {
    return {
      'id': todo.id,
      'user_id': todo.userId,
      'title': todo.title,
      'notes': todo.notes,
      'due_kind': _dueKindValue(todo.dueKind),
      'due_date': todo.dueDate?.toIso8601String(),
      'due_at_utc': todo.dueAtUtc == null
          ? null
          : _millisecondsOf(todo.dueAtUtc!),
      'color': todo.color?.name,
      'show_in_calendar': todo.showInCalendar ? 1 : 0,
      'completed': todo.completed ? 1 : 0,
      'completed_at_utc': todo.completedAtUtc == null
          ? null
          : _millisecondsOf(todo.completedAtUtc!),
      'revision': todo.revision,
      'created_at_utc': _millisecondsOf(todo.createdAtUtc),
      'updated_at_utc': _millisecondsOf(todo.updatedAtUtc),
    };
  }

  Todo _todoFromRow(Map<String, Object?> row) {
    final dueDate = row['due_date'] as String?;
    final dueAtUtc = row['due_at_utc'] as int?;
    final color = row['color'] as String?;
    final completedAtUtc = row['completed_at_utc'] as int?;
    return Todo(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      title: row['title'] as String,
      notes: row['notes'] as String,
      dueKind: _dueKindFromValue(row['due_kind'] as String),
      dueDate: dueDate == null ? null : LocalDate.parse(dueDate),
      dueAtUtc: dueAtUtc == null ? null : _utcFromMilliseconds(dueAtUtc),
      color: color == null ? null : CalendarColor.values.byName(color),
      showInCalendar: (row['show_in_calendar'] as int) == 1,
      completed: (row['completed'] as int) == 1,
      completedAtUtc: completedAtUtc == null
          ? null
          : _utcFromMilliseconds(completedAtUtc),
      revision: row['revision'] as int,
      createdAtUtc: _utcFromMilliseconds(row['created_at_utc'] as int),
      updatedAtUtc: _utcFromMilliseconds(row['updated_at_utc'] as int),
    );
  }

  String _dueKindValue(TodoDueKind kind) {
    return switch (kind) {
      TodoDueKind.none => 'none',
      TodoDueKind.dateOnly => 'date_only',
      TodoDueKind.exact => 'exact',
    };
  }

  TodoDueKind _dueKindFromValue(String value) {
    return switch (value) {
      'none' => TodoDueKind.none,
      'date_only' => TodoDueKind.dateOnly,
      'exact' => TodoDueKind.exact,
      _ => throw FormatException('Unknown todo due kind: $value'),
    };
  }

  DateTime _utcFromMilliseconds(int value) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }

  int _millisecondsOf(DateTime value) {
    return value.toUtc().millisecondsSinceEpoch;
  }
}
