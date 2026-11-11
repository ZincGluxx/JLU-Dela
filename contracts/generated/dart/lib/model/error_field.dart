//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ErrorField {
  /// Returns a new [ErrorField] instance.
  ErrorField({
    required this.path,
    required this.code,
  });

  /// JSON path or field name that failed validation.
  String path;

  /// Stable field-level error code.
  String code;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ErrorField &&
    other.path == path &&
    other.code == code;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (path.hashCode) +
    (code.hashCode);

  @override
  String toString() => 'ErrorField[path=$path, code=$code]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'path'] = this.path;
      json[r'code'] = this.code;
    return json;
  }

  /// Returns a new [ErrorField] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ErrorField? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'path'), 'Required key "ErrorField[path]" is missing from JSON.');
        assert(json[r'path'] != null, 'Required key "ErrorField[path]" has a null value in JSON.');
        assert(json.containsKey(r'code'), 'Required key "ErrorField[code]" is missing from JSON.');
        assert(json[r'code'] != null, 'Required key "ErrorField[code]" has a null value in JSON.');
        return true;
      }());

      return ErrorField(
        path: mapValueOfType<String>(json, r'path')!,
        code: mapValueOfType<String>(json, r'code')!,
      );
    }
    return null;
  }

  static List<ErrorField> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ErrorField>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ErrorField.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ErrorField> mapFromJson(dynamic json) {
    final map = <String, ErrorField>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ErrorField.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ErrorField-objects as value to a dart map
  static Map<String, List<ErrorField>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ErrorField>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ErrorField.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'path',
    'code',
  };
}

