//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class UpdateTodoRequest {
  /// Returns a new [UpdateTodoRequest] instance.
  UpdateTodoRequest({
    required this.revision,
    this.title = const Optional.absent(),
    this.notes = const Optional.absent(),
    this.dueKind = const Optional.absent(),
    this.dueDate = const Optional.absent(),
    this.dueAt = const Optional.absent(),
    this.color = const Optional.absent(),
    this.completed = const Optional.absent(),
    this.showInCalendar = const Optional.absent(),
  });

  /// The revision the client last read.
  ///
  /// Minimum value: 1
  int revision;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Optional<String?> title;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Optional<String?> notes;

  Optional<UpdateTodoRequestDueKindEnum?> dueKind;

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

  Optional<UpdateTodoRequestColorEnum?> color;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Optional<bool?> completed;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Optional<bool?> showInCalendar;

  @override
  bool operator ==(Object other) => identical(this, other) || other is UpdateTodoRequest &&
    other.revision == revision &&
    other.title == title &&
    other.notes == notes &&
    other.dueKind == dueKind &&
    other.dueDate == dueDate &&
    other.dueAt == dueAt &&
    other.color == color &&
    other.completed == completed &&
    other.showInCalendar == showInCalendar;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (revision.hashCode) +
    (title == null ? 0 : title!.hashCode) +
    (notes == null ? 0 : notes!.hashCode) +
    (dueKind == null ? 0 : dueKind!.hashCode) +
    (dueDate == null ? 0 : dueDate!.hashCode) +
    (dueAt == null ? 0 : dueAt!.hashCode) +
    (color == null ? 0 : color!.hashCode) +
    (completed == null ? 0 : completed!.hashCode) +
    (showInCalendar == null ? 0 : showInCalendar!.hashCode);

  @override
  String toString() => 'UpdateTodoRequest[revision=$revision, title=$title, notes=$notes, dueKind=$dueKind, dueDate=$dueDate, dueAt=$dueAt, color=$color, completed=$completed, showInCalendar=$showInCalendar]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'revision'] = this.revision;
    if (this.title.isPresent) {
      final value = this.title.value;
      json[r'title'] = value;
    }
    if (this.notes.isPresent) {
      final value = this.notes.value;
      json[r'notes'] = value;
    }
    if (this.dueKind.isPresent) {
      final value = this.dueKind.value;
      json[r'due_kind'] = value;
    }
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
    if (this.completed.isPresent) {
      final value = this.completed.value;
      json[r'completed'] = value;
    }
    if (this.showInCalendar.isPresent) {
      final value = this.showInCalendar.value;
      json[r'show_in_calendar'] = value;
    }
    return json;
  }

  /// Returns a new [UpdateTodoRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static UpdateTodoRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'revision'), 'Required key "UpdateTodoRequest[revision]" is missing from JSON.');
        assert(json[r'revision'] != null, 'Required key "UpdateTodoRequest[revision]" has a null value in JSON.');
        return true;
      }());

      return UpdateTodoRequest(
        revision: mapValueOfType<int>(json, r'revision')!,
        title: json.containsKey(r'title') ? Optional.present(mapValueOfType<String>(json, r'title')) : const Optional.absent(),
        notes: json.containsKey(r'notes') ? Optional.present(mapValueOfType<String>(json, r'notes')) : const Optional.absent(),
        dueKind: json.containsKey(r'due_kind') ? Optional.present(UpdateTodoRequestDueKindEnum.fromJson(json[r'due_kind'])) : const Optional.absent(),
        dueDate: json.containsKey(r'due_date') ? Optional.present(mapDateTime(json, r'due_date', r'')) : const Optional.absent(),
        dueAt: json.containsKey(r'due_at') ? Optional.present(mapDateTime(json, r'due_at', r'')) : const Optional.absent(),
        color: json.containsKey(r'color') ? Optional.present(UpdateTodoRequestColorEnum.fromJson(json[r'color'])) : const Optional.absent(),
        completed: json.containsKey(r'completed') ? Optional.present(mapValueOfType<bool>(json, r'completed')) : const Optional.absent(),
        showInCalendar: json.containsKey(r'show_in_calendar') ? Optional.present(mapValueOfType<bool>(json, r'show_in_calendar')) : const Optional.absent(),
      );
    }
    return null;
  }

  static List<UpdateTodoRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UpdateTodoRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UpdateTodoRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, UpdateTodoRequest> mapFromJson(dynamic json) {
    final map = <String, UpdateTodoRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = UpdateTodoRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of UpdateTodoRequest-objects as value to a dart map
  static Map<String, List<UpdateTodoRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<UpdateTodoRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = UpdateTodoRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'revision',
  };
}


enum UpdateTodoRequestDueKindEnum {
  none._(r'none'),
  dateOnly._(r'date_only'),
  exact._(r'exact'),
  ;

  /// Instantiate a new enum with the provided value.
  const UpdateTodoRequestDueKindEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [UpdateTodoRequestDueKindEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static UpdateTodoRequestDueKindEnum? fromJson(dynamic value) => UpdateTodoRequestDueKindEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [UpdateTodoRequestDueKindEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<UpdateTodoRequestDueKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UpdateTodoRequestDueKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UpdateTodoRequestDueKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [UpdateTodoRequestDueKindEnum] to Optional<String?>,
/// and [decode] dynamic data back to [UpdateTodoRequestDueKindEnum].
class UpdateTodoRequestDueKindEnumTypeTransformer {
  factory UpdateTodoRequestDueKindEnumTypeTransformer() => _instance ??= const UpdateTodoRequestDueKindEnumTypeTransformer._();

  const UpdateTodoRequestDueKindEnumTypeTransformer._();

  String encode(UpdateTodoRequestDueKindEnum data) => data._value;

  /// Returns the instance of [UpdateTodoRequestDueKindEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  UpdateTodoRequestDueKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is UpdateTodoRequestDueKindEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'none': return UpdateTodoRequestDueKindEnum.none;
        case r'date_only': return UpdateTodoRequestDueKindEnum.dateOnly;
        case r'exact': return UpdateTodoRequestDueKindEnum.exact;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static UpdateTodoRequestDueKindEnumTypeTransformer? _instance;
}



enum UpdateTodoRequestColorEnum {
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
  const UpdateTodoRequestColorEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [UpdateTodoRequestColorEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static UpdateTodoRequestColorEnum? fromJson(dynamic value) => UpdateTodoRequestColorEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [UpdateTodoRequestColorEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<UpdateTodoRequestColorEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UpdateTodoRequestColorEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UpdateTodoRequestColorEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [UpdateTodoRequestColorEnum] to Optional<String?>,
/// and [decode] dynamic data back to [UpdateTodoRequestColorEnum].
class UpdateTodoRequestColorEnumTypeTransformer {
  factory UpdateTodoRequestColorEnumTypeTransformer() => _instance ??= const UpdateTodoRequestColorEnumTypeTransformer._();

  const UpdateTodoRequestColorEnumTypeTransformer._();

  String encode(UpdateTodoRequestColorEnum data) => data._value;

  /// Returns the instance of [UpdateTodoRequestColorEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  UpdateTodoRequestColorEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is UpdateTodoRequestColorEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'rose': return UpdateTodoRequestColorEnum.rose;
        case r'peach': return UpdateTodoRequestColorEnum.peach;
        case r'sand': return UpdateTodoRequestColorEnum.sand;
        case r'sage': return UpdateTodoRequestColorEnum.sage;
        case r'teal': return UpdateTodoRequestColorEnum.teal;
        case r'blue': return UpdateTodoRequestColorEnum.blue;
        case r'lilac': return UpdateTodoRequestColorEnum.lilac;
        case r'slate': return UpdateTodoRequestColorEnum.slate;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static UpdateTodoRequestColorEnumTypeTransformer? _instance;
}


