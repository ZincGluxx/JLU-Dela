//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TodoListResponse {
  /// Returns a new [TodoListResponse] instance.
  TodoListResponse({
    this.data = const [],
    required this.meta,
  });

  List<Todo> data;

  ListMeta meta;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TodoListResponse &&
    _deepEquality.equals(other.data, data) &&
    other.meta == meta;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (data.hashCode) +
    (meta.hashCode);

  @override
  String toString() => 'TodoListResponse[data=$data, meta=$meta]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'data'] = this.data;
      json[r'meta'] = this.meta;
    return json;
  }

  /// Returns a new [TodoListResponse] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TodoListResponse? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'data'), 'Required key "TodoListResponse[data]" is missing from JSON.');
        assert(json[r'data'] != null, 'Required key "TodoListResponse[data]" has a null value in JSON.');
        assert(json.containsKey(r'meta'), 'Required key "TodoListResponse[meta]" is missing from JSON.');
        assert(json[r'meta'] != null, 'Required key "TodoListResponse[meta]" has a null value in JSON.');
        return true;
      }());

      return TodoListResponse(
        data: Todo.listFromJson(json[r'data']),
        meta: ListMeta.fromJson(json[r'meta'])!,
      );
    }
    return null;
  }

  static List<TodoListResponse> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TodoListResponse>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TodoListResponse.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TodoListResponse> mapFromJson(dynamic json) {
    final map = <String, TodoListResponse>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TodoListResponse.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TodoListResponse-objects as value to a dart map
  static Map<String, List<TodoListResponse>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TodoListResponse>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TodoListResponse.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'data',
    'meta',
  };
}

