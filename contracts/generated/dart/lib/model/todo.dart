//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class Todo {
  /// Returns a new [Todo] instance.
  Todo({
    required this.id,
    required this.title,
    required this.notes,
    required this.dueKind,
    required this.dueDate,
    required this.dueAt,
    required this.color,
    required this.completed,
    required this.showInCalendar,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
  });

  String id;

  /// Trimmed by the server, then validated as 1-200 characters.
  String title;

  String notes;

  /// Personal todos use these three only. `relative` and `unknown` describe assignment source uncertainty.
  TodoDueKindEnum dueKind;

  /// Set only when `due_kind=date_only`. A calendar day in Asia/Shanghai.
  DateTime? dueDate;

  /// Set only when `due_kind=exact`. UTC RFC 3339 with a `Z` suffix.
  DateTime? dueAt;

  /// Calendar colour key, matching the legacy `calendarEventColors`. Null renders as the default slate.
  TodoColorEnum? color;

  bool completed;

  /// Whether the todo appears in the calendar. Has no effect while `due_kind=none`.
  bool showInCalendar;

  /// Minimum value: 1
  int revision;

  DateTime createdAt;

  DateTime updatedAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is Todo &&
    other.id == id &&
    other.title == title &&
    other.notes == notes &&
    other.dueKind == dueKind &&
    other.dueDate == dueDate &&
    other.dueAt == dueAt &&
    other.color == color &&
    other.completed == completed &&
    other.showInCalendar == showInCalendar &&
    other.revision == revision &&
    other.createdAt == createdAt &&
    other.updatedAt == updatedAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (title.hashCode) +
    (notes.hashCode) +
    (dueKind.hashCode) +
    (dueDate == null ? 0 : dueDate!.hashCode) +
    (dueAt == null ? 0 : dueAt!.hashCode) +
    (color == null ? 0 : color!.hashCode) +
    (completed.hashCode) +
    (showInCalendar.hashCode) +
    (revision.hashCode) +
    (createdAt.hashCode) +
    (updatedAt.hashCode);

  @override
  String toString() => 'Todo[id=$id, title=$title, notes=$notes, dueKind=$dueKind, dueDate=$dueDate, dueAt=$dueAt, color=$color, completed=$completed, showInCalendar=$showInCalendar, revision=$revision, createdAt=$createdAt, updatedAt=$updatedAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'title'] = this.title;
      json[r'notes'] = this.notes;
      json[r'due_kind'] = this.dueKind;
    if (this.dueDate != null) {
      json[r'due_date'] = _dateFormatter.format(this.dueDate!);
    } else {
      json[r'due_date'] = null;
    }
    if (this.dueAt != null) {
      json[r'due_at'] = this.dueAt!.toUtc().toIso8601String();
    } else {
      json[r'due_at'] = null;
    }
    if (this.color != null) {
      json[r'color'] = this.color;
    } else {
      json[r'color'] = null;
    }
      json[r'completed'] = this.completed;
      json[r'show_in_calendar'] = this.showInCalendar;
      json[r'revision'] = this.revision;
      json[r'created_at'] = this.createdAt.toUtc().toIso8601String();
      json[r'updated_at'] = this.updatedAt.toUtc().toIso8601String();
    return json;
  }

  /// Returns a new [Todo] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static Todo? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'id'), 'Required key "Todo[id]" is missing from JSON.');
        assert(json[r'id'] != null, 'Required key "Todo[id]" has a null value in JSON.');
        assert(json.containsKey(r'title'), 'Required key "Todo[title]" is missing from JSON.');
        assert(json[r'title'] != null, 'Required key "Todo[title]" has a null value in JSON.');
        assert(json.containsKey(r'notes'), 'Required key "Todo[notes]" is missing from JSON.');
        assert(json[r'notes'] != null, 'Required key "Todo[notes]" has a null value in JSON.');
        assert(json.containsKey(r'due_kind'), 'Required key "Todo[due_kind]" is missing from JSON.');
        assert(json[r'due_kind'] != null, 'Required key "Todo[due_kind]" has a null value in JSON.');
        assert(json.containsKey(r'due_date'), 'Required key "Todo[due_date]" is missing from JSON.');
        assert(json.containsKey(r'due_at'), 'Required key "Todo[due_at]" is missing from JSON.');
        assert(json.containsKey(r'color'), 'Required key "Todo[color]" is missing from JSON.');
        assert(json.containsKey(r'completed'), 'Required key "Todo[completed]" is missing from JSON.');
        assert(json[r'completed'] != null, 'Required key "Todo[completed]" has a null value in JSON.');
        assert(json.containsKey(r'show_in_calendar'), 'Required key "Todo[show_in_calendar]" is missing from JSON.');
        assert(json[r'show_in_calendar'] != null, 'Required key "Todo[show_in_calendar]" has a null value in JSON.');
        assert(json.containsKey(r'revision'), 'Required key "Todo[revision]" is missing from JSON.');
        assert(json[r'revision'] != null, 'Required key "Todo[revision]" has a null value in JSON.');
        assert(json.containsKey(r'created_at'), 'Required key "Todo[created_at]" is missing from JSON.');
        assert(json[r'created_at'] != null, 'Required key "Todo[created_at]" has a null value in JSON.');
        assert(json.containsKey(r'updated_at'), 'Required key "Todo[updated_at]" is missing from JSON.');
        assert(json[r'updated_at'] != null, 'Required key "Todo[updated_at]" has a null value in JSON.');
        return true;
      }());

      return Todo(
        id: mapValueOfType<String>(json, r'id')!,
        title: mapValueOfType<String>(json, r'title')!,
        notes: mapValueOfType<String>(json, r'notes')!,
        dueKind: TodoDueKindEnum.fromJson(json[r'due_kind'])!,
        dueDate: mapDateTime(json, r'due_date', r''),
        dueAt: mapDateTime(json, r'due_at', r''),
        color: TodoColorEnum.fromJson(json[r'color']),
        completed: mapValueOfType<bool>(json, r'completed')!,
        showInCalendar: mapValueOfType<bool>(json, r'show_in_calendar')!,
        revision: mapValueOfType<int>(json, r'revision')!,
        createdAt: mapDateTime(json, r'created_at', r'')!,
        updatedAt: mapDateTime(json, r'updated_at', r'')!,
      );
    }
    return null;
  }

  static List<Todo> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <Todo>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Todo.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, Todo> mapFromJson(dynamic json) {
    final map = <String, Todo>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = Todo.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of Todo-objects as value to a dart map
  static Map<String, List<Todo>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<Todo>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = Todo.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'title',
    'notes',
    'due_kind',
    'due_date',
    'due_at',
    'color',
    'completed',
    'show_in_calendar',
    'revision',
    'created_at',
    'updated_at',
  };
}

/// Personal todos use these three only. `relative` and `unknown` describe assignment source uncertainty.
enum TodoDueKindEnum {
  none._(r'none'),
  dateOnly._(r'date_only'),
  exact._(r'exact'),
  ;

  /// Instantiate a new enum with the provided value.
  const TodoDueKindEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [TodoDueKindEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static TodoDueKindEnum? fromJson(dynamic value) => TodoDueKindEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [TodoDueKindEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<TodoDueKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TodoDueKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TodoDueKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [TodoDueKindEnum] to String,
/// and [decode] dynamic data back to [TodoDueKindEnum].
class TodoDueKindEnumTypeTransformer {
  factory TodoDueKindEnumTypeTransformer() => _instance ??= const TodoDueKindEnumTypeTransformer._();

  const TodoDueKindEnumTypeTransformer._();

  String encode(TodoDueKindEnum data) => data._value;

  /// Returns the instance of [TodoDueKindEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  TodoDueKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is TodoDueKindEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'none': return TodoDueKindEnum.none;
        case r'date_only': return TodoDueKindEnum.dateOnly;
        case r'exact': return TodoDueKindEnum.exact;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static TodoDueKindEnumTypeTransformer? _instance;
}


/// Calendar colour key, matching the legacy `calendarEventColors`. Null renders as the default slate.
enum TodoColorEnum {
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
  const TodoColorEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [TodoColorEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static TodoColorEnum? fromJson(dynamic value) => TodoColorEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [TodoColorEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<TodoColorEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TodoColorEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TodoColorEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [TodoColorEnum] to String,
/// and [decode] dynamic data back to [TodoColorEnum].
class TodoColorEnumTypeTransformer {
  factory TodoColorEnumTypeTransformer() => _instance ??= const TodoColorEnumTypeTransformer._();

  const TodoColorEnumTypeTransformer._();

  String encode(TodoColorEnum data) => data._value;

  /// Returns the instance of [TodoColorEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  TodoColorEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is TodoColorEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'rose': return TodoColorEnum.rose;
        case r'peach': return TodoColorEnum.peach;
        case r'sand': return TodoColorEnum.sand;
        case r'sage': return TodoColorEnum.sage;
        case r'teal': return TodoColorEnum.teal;
        case r'blue': return TodoColorEnum.blue;
        case r'lilac': return TodoColorEnum.lilac;
        case r'slate': return TodoColorEnum.slate;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static TodoColorEnumTypeTransformer? _instance;
}


