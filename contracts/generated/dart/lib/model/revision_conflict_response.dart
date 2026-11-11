//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class RevisionConflictResponse {
  /// Returns a new [RevisionConflictResponse] instance.
  RevisionConflictResponse({
    required this.error,
  });

  RevisionConflictDetail error;

  @override
  bool operator ==(Object other) => identical(this, other) || other is RevisionConflictResponse &&
    other.error == error;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (error.hashCode);

  @override
  String toString() => 'RevisionConflictResponse[error=$error]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'error'] = this.error;
    return json;
  }

  /// Returns a new [RevisionConflictResponse] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static RevisionConflictResponse? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'error'), 'Required key "RevisionConflictResponse[error]" is missing from JSON.');
        assert(json[r'error'] != null, 'Required key "RevisionConflictResponse[error]" has a null value in JSON.');
        return true;
      }());

      return RevisionConflictResponse(
        error: RevisionConflictDetail.fromJson(json[r'error'])!,
      );
    }
    return null;
  }

  static List<RevisionConflictResponse> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RevisionConflictResponse>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RevisionConflictResponse.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, RevisionConflictResponse> mapFromJson(dynamic json) {
    final map = <String, RevisionConflictResponse>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = RevisionConflictResponse.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of RevisionConflictResponse-objects as value to a dart map
  static Map<String, List<RevisionConflictResponse>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<RevisionConflictResponse>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = RevisionConflictResponse.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'error',
  };
}

