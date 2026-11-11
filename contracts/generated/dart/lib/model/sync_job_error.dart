//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SyncJobError {
  /// Returns a new [SyncJobError] instance.
  SyncJobError({
    required this.code,
    required this.retryable,
  });

  /// Stable source or worker error code. Never upstream error text.
  String code;

  bool retryable;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SyncJobError &&
    other.code == code &&
    other.retryable == retryable;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (code.hashCode) +
    (retryable.hashCode);

  @override
  String toString() => 'SyncJobError[code=$code, retryable=$retryable]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'code'] = this.code;
      json[r'retryable'] = this.retryable;
    return json;
  }

  /// Returns a new [SyncJobError] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SyncJobError? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'code'), 'Required key "SyncJobError[code]" is missing from JSON.');
        assert(json[r'code'] != null, 'Required key "SyncJobError[code]" has a null value in JSON.');
        assert(json.containsKey(r'retryable'), 'Required key "SyncJobError[retryable]" is missing from JSON.');
        assert(json[r'retryable'] != null, 'Required key "SyncJobError[retryable]" has a null value in JSON.');
        return true;
      }());

      return SyncJobError(
        code: mapValueOfType<String>(json, r'code')!,
        retryable: mapValueOfType<bool>(json, r'retryable')!,
      );
    }
    return null;
  }

  static List<SyncJobError> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SyncJobError>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SyncJobError.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SyncJobError> mapFromJson(dynamic json) {
    final map = <String, SyncJobError>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SyncJobError.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SyncJobError-objects as value to a dart map
  static Map<String, List<SyncJobError>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SyncJobError>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SyncJobError.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'code',
    'retryable',
  };
}

