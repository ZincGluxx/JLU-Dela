//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TeachingBackupConflictResponse {
  /// Returns a new [TeachingBackupConflictResponse] instance.
  TeachingBackupConflictResponse({
    required this.error,
  });

  TeachingBackupConflictResponseError error;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TeachingBackupConflictResponse &&
    other.error == error;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (error.hashCode);

  @override
  String toString() => 'TeachingBackupConflictResponse[error=$error]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'error'] = this.error;
    return json;
  }

  /// Returns a new [TeachingBackupConflictResponse] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TeachingBackupConflictResponse? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'error'), 'Required key "TeachingBackupConflictResponse[error]" is missing from JSON.');
        assert(json[r'error'] != null, 'Required key "TeachingBackupConflictResponse[error]" has a null value in JSON.');
        return true;
      }());

      return TeachingBackupConflictResponse(
        error: TeachingBackupConflictResponseError.fromJson(json[r'error'])!,
      );
    }
    return null;
  }

  static List<TeachingBackupConflictResponse> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TeachingBackupConflictResponse>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TeachingBackupConflictResponse.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TeachingBackupConflictResponse> mapFromJson(dynamic json) {
    final map = <String, TeachingBackupConflictResponse>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TeachingBackupConflictResponse.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TeachingBackupConflictResponse-objects as value to a dart map
  static Map<String, List<TeachingBackupConflictResponse>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TeachingBackupConflictResponse>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TeachingBackupConflictResponse.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'error',
  };
}

