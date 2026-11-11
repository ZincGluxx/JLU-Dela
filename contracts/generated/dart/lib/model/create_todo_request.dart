//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CreateTodoRequest {
  /// Returns a new [CreateTodoRequest] instance.
  CreateTodoRequest({
    required this.title,
    this.notes = const Optional.present(''),
    this.dueKind = const Optional.absent(),
    this.dueDate = const Optional.absent(),
    this.dueAt = const Optional.absent(),
    this.color = const Optional.absent(),
    this.showInCalendar = const Optional.present(true),
  });

  String title;

  Optional<String?> notes;

  /// Omitting this field means `none`, which is what the server stores. The default is documented rather than declared because openapi-generator emits an illegal `const XEnum._('none')` for an enum with a schema default, and Dart enhanced enums cannot be instantiated. 
  Optional<CreateTodoRequestDueKindEnum?> dueKind;

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

  Optional<CreateTodoRequestColorEnum?> color;

  Optional<bool?> showInCalendar;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CreateTodoRequest &&
    other.title == title &&
    other.notes == notes &&
    other.dueKind == dueKind &&
    other.dueDate == dueDate &&
    other.dueAt == dueAt &&
    other.color == color &&
    other.showInCalendar == showInCalendar;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (title.hashCode) +
    (notes.hashCode) +
    (dueKind == null ? 0 : dueKind!.hashCode) +
    (dueDate == null ? 0 : dueDate!.hashCode) +
    (dueAt == null ? 0 : dueAt!.hashCode) +
    (color == null ? 0 : color!.hashCode) +
    (showInCalendar.hashCode);

  @override
  String toString() => 'CreateTodoRequest[title=$title, notes=$notes, dueKind=$dueKind, dueDate=$dueDate, dueAt=$dueAt, color=$color, showInCalendar=$showInCalendar]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'title'] = this.title;
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
    if (this.showInCalendar.isPresent) {
      final value = this.showInCalendar.value;
      json[r'show_in_calendar'] = value;
    }
    return json;
  }

  /// Returns a new [CreateTodoRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CreateTodoRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'title'), 'Required key "CreateTodoRequest[title]" is missing from JSON.');
        assert(json[r'title'] != null, 'Required key "CreateTodoRequest[title]" has a null value in JSON.');
        return true;
      }());

      return CreateTodoRequest(
        title: mapValueOfType<String>(json, r'title')!,
        notes: json.containsKey(r'notes') ? Optional.present(mapValueOfType<String>(json, r'notes')) : const Optional.absent(),
        dueKind: json.containsKey(r'due_kind') ? Optional.present(CreateTodoRequestDueKindEnum.fromJson(json[r'due_kind'])) : const Optional.absent(),
        dueDate: json.containsKey(r'due_date') ? Optional.present(mapDateTime(json, r'due_date', r'')) : const Optional.absent(),
        dueAt: json.containsKey(r'due_at') ? Optional.present(mapDateTime(json, r'due_at', r'')) : const Optional.absent(),
        color: json.containsKey(r'color') ? Optional.present(CreateTodoRequestColorEnum.fromJson(json[r'color'])) : const Optional.absent(),
        showInCalendar: json.containsKey(r'show_in_calendar') ? Optional.present(mapValueOfType<bool>(json, r'show_in_calendar')) : const Optional.absent(),
      );
    }
    return null;
  }

  static List<CreateTodoRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CreateTodoRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CreateTodoRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CreateTodoRequest> mapFromJson(dynamic json) {
    final map = <String, CreateTodoRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CreateTodoRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CreateTodoRequest-objects as value to a dart map
  static Map<String, List<CreateTodoRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CreateTodoRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CreateTodoRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'title',
  };
}

/// Omitting this field means `none`, which is what the server stores. The default is documented rather than declared because openapi-generator emits an illegal `const XEnum._('none')` for an enum with a schema default, and Dart enhanced enums cannot be instantiated. 
enum CreateTodoRequestDueKindEnum {
  none._(r'none'),
  dateOnly._(r'date_only'),
  exact._(r'exact'),
  ;

  /// Instantiate a new enum with the provided value.
  const CreateTodoRequestDueKindEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [CreateTodoRequestDueKindEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static CreateTodoRequestDueKindEnum? fromJson(dynamic value) => CreateTodoRequestDueKindEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [CreateTodoRequestDueKindEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<CreateTodoRequestDueKindEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CreateTodoRequestDueKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CreateTodoRequestDueKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CreateTodoRequestDueKindEnum] to Optional<String?>,
/// and [decode] dynamic data back to [CreateTodoRequestDueKindEnum].
class CreateTodoRequestDueKindEnumTypeTransformer {
  factory CreateTodoRequestDueKindEnumTypeTransformer() => _instance ??= const CreateTodoRequestDueKindEnumTypeTransformer._();

  const CreateTodoRequestDueKindEnumTypeTransformer._();

  String encode(CreateTodoRequestDueKindEnum data) => data._value;

  /// Returns the instance of [CreateTodoRequestDueKindEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CreateTodoRequestDueKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is CreateTodoRequestDueKindEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'none': return CreateTodoRequestDueKindEnum.none;
        case r'date_only': return CreateTodoRequestDueKindEnum.dateOnly;
        case r'exact': return CreateTodoRequestDueKindEnum.exact;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static CreateTodoRequestDueKindEnumTypeTransformer? _instance;
}



enum CreateTodoRequestColorEnum {
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
  const CreateTodoRequestColorEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [CreateTodoRequestColorEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static CreateTodoRequestColorEnum? fromJson(dynamic value) => CreateTodoRequestColorEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [CreateTodoRequestColorEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<CreateTodoRequestColorEnum> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CreateTodoRequestColorEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CreateTodoRequestColorEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CreateTodoRequestColorEnum] to Optional<String?>,
/// and [decode] dynamic data back to [CreateTodoRequestColorEnum].
class CreateTodoRequestColorEnumTypeTransformer {
  factory CreateTodoRequestColorEnumTypeTransformer() => _instance ??= const CreateTodoRequestColorEnumTypeTransformer._();

  const CreateTodoRequestColorEnumTypeTransformer._();

  String encode(CreateTodoRequestColorEnum data) => data._value;

  /// Returns the instance of [CreateTodoRequestColorEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CreateTodoRequestColorEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is CreateTodoRequestColorEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'rose': return CreateTodoRequestColorEnum.rose;
        case r'peach': return CreateTodoRequestColorEnum.peach;
        case r'sand': return CreateTodoRequestColorEnum.sand;
        case r'sage': return CreateTodoRequestColorEnum.sage;
        case r'teal': return CreateTodoRequestColorEnum.teal;
        case r'blue': return CreateTodoRequestColorEnum.blue;
        case r'lilac': return CreateTodoRequestColorEnum.lilac;
        case r'slate': return CreateTodoRequestColorEnum.slate;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static CreateTodoRequestColorEnumTypeTransformer? _instance;
}


