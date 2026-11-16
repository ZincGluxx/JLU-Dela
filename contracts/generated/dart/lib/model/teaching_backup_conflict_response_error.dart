//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TeachingBackupConflictResponseError {
  /// Returns a new [TeachingBackupConflictResponseError] instance.
  TeachingBackupConflictResponseError({
    required this.code,
    required this.message,
    required this.requestId,
    required this.retryable,
    this.fields = const [],
    this.current = const Optional.absent(),
  });

  String code;

  String message;

  String requestId;

  bool retryable;

  List<ErrorField> fields;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Optional<TeachingBackupSnapshot?> current;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TeachingBackupConflictResponseError &&
    other.code == code &&
    other.message == message &&
    other.requestId == requestId &&
    other.retryable == retryable &&
    _deepEquality.equals(other.fields, fields) &&
    other.current == current;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (code.hashCode) +
    (message.hashCode) +
    (requestId.hashCode) +
    (retryable.hashCode) +
    (fields.hashCode) +
    (current == null ? 0 : current!.hashCode);

  @override
  String toString() => 'TeachingBackupConflictResponseError[code=$code, message=$message, requestId=$requestId, retryable=$retryable, fields=$fields, current=$current]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'code'] = this.code;
      json[r'message'] = this.message;
      json[r'request_id'] = this.requestId;
      json[r'retryable'] = this.retryable;
      json[r'fields'] = this.fields;
    if (this.current.isPresent) {
      final value = this.current.value;
      json[r'current'] = value;
    }
    return json;
  }

  /// Returns a new [TeachingBackupConflictResponseError] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TeachingBackupConflictResponseError? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'code'), 'Required key "TeachingBackupConflictResponseError[code]" is missing from JSON.');
        assert(json[r'code'] != null, 'Required key "TeachingBackupConflictResponseError[code]" has a null value in JSON.');
        assert(json.containsKey(r'message'), 'Required key "TeachingBackupConflictResponseError[message]" is missing from JSON.');
        assert(json[r'message'] != null, 'Required key "TeachingBackupConflictResponseError[message]" has a null value in JSON.');
        assert(json.containsKey(r'request_id'), 'Required key "TeachingBackupConflictResponseError[request_id]" is missing from JSON.');
        assert(json[r'request_id'] != null, 'Required key "TeachingBackupConflictResponseError[request_id]" has a null value in JSON.');
        assert(json.containsKey(r'retryable'), 'Required key "TeachingBackupConflictResponseError[retryable]" is missing from JSON.');
        assert(json[r'retryable'] != null, 'Required key "TeachingBackupConflictResponseError[retryable]" has a null value in JSON.');
        assert(json.containsKey(r'fields'), 'Required key "TeachingBackupConflictResponseError[fields]" is missing from JSON.');
        assert(json[r'fields'] != null, 'Required key "TeachingBackupConflictResponseError[fields]" has a null value in JSON.');
        return true;
      }());

      return TeachingBackupConflictResponseError(
        code: mapValueOfType<String>(json, r'code')!,
        message: mapValueOfType<String>(json, r'message')!,
        requestId: mapValueOfType<String>(json, r'request_id')!,
        retryable: mapValueOfType<bool>(json, r'retryable')!,
        fields: ErrorField.listFromJson(json[r'fields']),
        current: json.containsKey(r'current') ? Optional.present(TeachingBackupSnapshot.fromJson(json[r'current'])) : const Optional.absent(),
      );
    }
    return null;
  }

  static List<TeachingBackupConflictResponseError> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TeachingBackupConflictResponseError>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TeachingBackupConflictResponseError.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TeachingBackupConflictResponseError> mapFromJson(dynamic json) {
    final map = <String, TeachingBackupConflictResponseError>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TeachingBackupConflictResponseError.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TeachingBackupConflictResponseError-objects as value to a dart map
  static Map<String, List<TeachingBackupConflictResponseError>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TeachingBackupConflictResponseError>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TeachingBackupConflictResponseError.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'code',
    'message',
    'request_id',
    'retryable',
    'fields',
  };
}

