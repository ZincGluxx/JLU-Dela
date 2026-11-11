//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TodoItem {
  /// Returns a new [TodoItem] instance.
  TodoItem({
    required this.kind,
    required this.id,
    required this.todoId,
    required this.title,
    required this.dueKind,
    this.dueDate = const Optional.absent(),
    this.dueAt = const Optional.absent(),
    this.color = const Optional.absent(),
    required this.showInCalendar,
    required this.completed,
  });

  TodoItemKindEnum kind;

  /// `todo:<todo_id>`
  String id;

  String todoId;

  String title;

  TodoItemDueKindEnum dueKind;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Optional<DateTime?> dueDate;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Optional<DateTime?> dueAt;

  /// Null renders as the default slate.
  Optional<TodoItemColorEnum?> color;

  bool showInCalendar;

  bool completed;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TodoItem &&
    other.kind == kind &&
    other.id == id &&
    other.todoId == todoId &&
    other.title == title &&
    other.dueKind == dueKind &&
    other.dueDate == dueDate &&
    other.dueAt == dueAt &&
    other.color == color &&
    other.showInCalendar == showInCalendar &&
    other.completed == completed;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (kind.hashCode) +
    (id.hashCode) +
    (todoId.hashCode) +
    (title.hashCode) +
    (dueKind.hashCode) +
    (dueDate == null ? 0 : dueDate!.hashCode) +
    (dueAt == null ? 0 : dueAt!.hashCode) +
    (color == null ? 0 : color!.hashCode) +
    (showInCalendar.hashCode) +
    (completed.hashCode);

  @override
  String toString() => 'TodoItem[kind=$kind, id=$id, todoId=$todoId, title=$title, dueKind=$dueKind, dueDate=$dueDate, dueAt=$dueAt, color=$color, showInCalendar=$showInCalendar, completed=$completed]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'kind'] = this.kind;
      json[r'id'] = this.id;
      json[r'todo_id'] = this.todoId;
      json[r'title'] = this.title;
      json[r'due_kind'] = this.dueKind;
    if (this.dueDate.isPresent) {
      final value = this.dueDate.value;
      json[r'due_date'] = value == null ? null : _dateFormatter.format(value);
    }
    if (this.dueAt.isPresent) {
      final value = this.dueAt.value;
      json[r'due_at'] = value == null ? null : value.toUtc().toIso8601String();
    }
    if (this.color.isPresent) {
      final value = this.color.value;
      json[r'color'] = value;
    }
      json[r'show_in_calendar'] = this.showInCalendar;
      json[r'completed'] = this.completed;
    return json;
  }

  /// Returns a new [TodoItem] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TodoItem? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'kind'), 'Required key "TodoItem[kind]" is missing from JSON.');
        assert(json[r'kind'] != null, 'Required key "TodoItem[kind]" has a null value in JSON.');
        assert(json.containsKey(r'id'), 'Required key "TodoItem[id]" is missing from JSON.');
        assert(json[r'id'] != null, 'Required key "TodoItem[id]" has a null value in JSON.');
        assert(json.containsKey(r'todo_id'), 'Required key "TodoItem[todo_id]" is missing from JSON.');
        assert(json[r'todo_id'] != null, 'Required key "TodoItem[todo_id]" has a null value in JSON.');
        assert(json.containsKey(r'title'), 'Required key "TodoItem[title]" is missing from JSON.');
        assert(json[r'title'] != null, 'Required key "TodoItem[title]" has a null value in JSON.');
        assert(json.containsKey(r'due_kind'), 'Required key "TodoItem[due_kind]" is missing from JSON.');
        assert(json[r'due_kind'] != null, 'Required key "TodoItem[due_kind]" has a null value in JSON.');
        assert(json.containsKey(r'show_in_calendar'), 'Required key "TodoItem[show_in_calendar]" is missing from JSON.');
        assert(json[r'show_in_calendar'] != null, 'Required key "TodoItem[show_in_calendar]" has a null value in JSON.');
        assert(json.containsKey(r'completed'), 'Required key "TodoItem[completed]" is missing from JSON.');
        assert(json[r'completed'] != null, 'Required key "TodoItem[completed]" has a null value in JSON.');
        return true;
      }());

      return TodoItem(
        kind: TodoItemKindEnum.fromJson(json[r'kind'])!,
        id: mapValueOfType<String>(json, r'id')!,
        todoId: mapValueOfType<String>(json, r'todo_id')!,
        title: mapValueOfType<String>(json, r'title')!,
        dueKind: TodoItemDueKindEnum.fromJson(json[r'due_kind'])!,
        dueDate: json.containsKey(r'due_date') ? Optional.present(mapDateTime(json, r'due_date', r'')) : const Optional.absent(),
        dueAt: json.containsKey(r'due_at') ? Optional.present(mapDateTime(json, r'due_at', r'')) : const Optional.absent(),
        color: json.containsKey(r'color') ? Optional.present(TodoItemColorEnum.fromJson(json[r'color'])) : const Optional.absent(),
        showInCalendar: mapValueOfType<bool>(json, r'show_in_calendar')!,
        completed: mapValueOfType<bool>(json, r'completed')!,
      );
    }
    return null;
  }

  static List<TodoItem> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TodoItem>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TodoItem.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TodoItem> mapFromJson(dynamic json) {
    final map = <String, TodoItem>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TodoItem.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TodoItem-objects as value to a dart map
  static Map<String, List<TodoItem>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TodoItem>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TodoItem.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'kind',
    'id',
    'todo_id',
    'title',
    'due_kind',
    'show_in_calendar',
    'completed',
  };
}


enum TodoItemKindEnum {
  todo._(r'todo'),
  ;

  /// Instantiate a new enum with the provided value.
  const TodoItemKindEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [TodoItemKindEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static TodoItemKindEnum? fromJson(dynamic value) => TodoItemKindEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [TodoItemKindEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<TodoItemKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TodoItemKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TodoItemKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [TodoItemKindEnum] to String,
/// and [decode] dynamic data back to [TodoItemKindEnum].
class TodoItemKindEnumTypeTransformer {
  factory TodoItemKindEnumTypeTransformer() => _instance ??= const TodoItemKindEnumTypeTransformer._();

  const TodoItemKindEnumTypeTransformer._();

  String encode(TodoItemKindEnum data) => data._value;

  /// Returns the instance of [TodoItemKindEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  TodoItemKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is TodoItemKindEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'todo': return TodoItemKindEnum.todo;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static TodoItemKindEnumTypeTransformer? _instance;
}



enum TodoItemDueKindEnum {
  dateOnly._(r'date_only'),
  exact._(r'exact'),
  ;

  /// Instantiate a new enum with the provided value.
  const TodoItemDueKindEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [TodoItemDueKindEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static TodoItemDueKindEnum? fromJson(dynamic value) => TodoItemDueKindEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [TodoItemDueKindEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<TodoItemDueKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TodoItemDueKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TodoItemDueKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [TodoItemDueKindEnum] to String,
/// and [decode] dynamic data back to [TodoItemDueKindEnum].
class TodoItemDueKindEnumTypeTransformer {
  factory TodoItemDueKindEnumTypeTransformer() => _instance ??= const TodoItemDueKindEnumTypeTransformer._();

  const TodoItemDueKindEnumTypeTransformer._();

  String encode(TodoItemDueKindEnum data) => data._value;

  /// Returns the instance of [TodoItemDueKindEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  TodoItemDueKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is TodoItemDueKindEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'date_only': return TodoItemDueKindEnum.dateOnly;
        case r'exact': return TodoItemDueKindEnum.exact;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static TodoItemDueKindEnumTypeTransformer? _instance;
}


/// Null renders as the default slate.
enum TodoItemColorEnum {
  rose._(r'rose'),
  peach._(r'peach'),
  sand._(r'sand'),
  sage._(r'sage'),
  teal._(r'teal'),
  blue._(r'blue'),
  lilac._(r'lilac'),
  slate._(r'slate'),
  ;

  /// Instantiate a new enum with the provided value.
  const TodoItemColorEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [TodoItemColorEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static TodoItemColorEnum? fromJson(dynamic value) => TodoItemColorEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [TodoItemColorEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<TodoItemColorEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TodoItemColorEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TodoItemColorEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [TodoItemColorEnum] to Optional<String?>,
/// and [decode] dynamic data back to [TodoItemColorEnum].
class TodoItemColorEnumTypeTransformer {
  factory TodoItemColorEnumTypeTransformer() => _instance ??= const TodoItemColorEnumTypeTransformer._();

  const TodoItemColorEnumTypeTransformer._();

  String encode(TodoItemColorEnum data) => data._value;

  /// Returns the instance of [TodoItemColorEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  TodoItemColorEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is TodoItemColorEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'rose': return TodoItemColorEnum.rose;
        case r'peach': return TodoItemColorEnum.peach;
        case r'sand': return TodoItemColorEnum.sand;
        case r'sage': return TodoItemColorEnum.sage;
        case r'teal': return TodoItemColorEnum.teal;
        case r'blue': return TodoItemColorEnum.blue;
        case r'lilac': return TodoItemColorEnum.lilac;
        case r'slate': return TodoItemColorEnum.slate;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static TodoItemColorEnumTypeTransformer? _instance;
}


