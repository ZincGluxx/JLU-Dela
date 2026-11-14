//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class BackupConflictResponseError {
  /// Returns a new [BackupConflictResponseError] instance.
  BackupConflictResponseError({
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
  Optional<BackupSnapshot?> current;

  @override
  bool operator ==(Object other) => identical(this, other) || other is BackupConflictResponseError &&
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
  String toString() => 'BackupConflictResponseError[code=$code, message=$message, requestId=$requestId, retryable=$retryable, fields=$fields, current=$current]';

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

  /// Returns a new [BackupConflictResponseError] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static BackupConflictResponseError? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'code'), 'Required key "BackupConflictResponseError[code]" is missing from JSON.');
        assert(json[r'code'] != null, 'Required key "BackupConflictResponseError[code]" has a null value in JSON.');
        assert(json.containsKey(r'message'), 'Required key "BackupConflictResponseError[message]" is missing from JSON.');
        assert(json[r'message'] != null, 'Required key "BackupConflictResponseError[message]" has a null value in JSON.');
        assert(json.containsKey(r'request_id'), 'Required key "BackupConflictResponseError[request_id]" is missing from JSON.');
        assert(json[r'request_id'] != null, 'Required key "BackupConflictResponseError[request_id]" has a null value in JSON.');
        assert(json.containsKey(r'retryable'), 'Required key "BackupConflictResponseError[retryable]" is missing from JSON.');
        assert(json[r'retryable'] != null, 'Required key "BackupConflictResponseError[retryable]" has a null value in JSON.');
        assert(json.containsKey(r'fields'), 'Required key "BackupConflictResponseError[fields]" is missing from JSON.');
        assert(json[r'fields'] != null, 'Required key "BackupConflictResponseError[fields]" has a null value in JSON.');
        return true;
      }());

      return BackupConflictResponseError(
        code: mapValueOfType<String>(json, r'code')!,
        message: mapValueOfType<String>(json, r'message')!,
        requestId: mapValueOfType<String>(json, r'request_id')!,
        retryable: mapValueOfType<bool>(json, r'retryable')!,
        fields: ErrorField.listFromJson(json[r'fields']),
        current: json.containsKey(r'current') ? Optional.present(BackupSnapshot.fromJson(json[r'current'])) : const Optional.absent(),
      );
    }
    return null;
  }

  static List<BackupConflictResponseError> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <BackupConflictResponseError>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = BackupConflictResponseError.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, BackupConflictResponseError> mapFromJson(dynamic json) {
    final map = <String, BackupConflictResponseError>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = BackupConflictResponseError.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of BackupConflictResponseError-objects as value to a dart map
  static Map<String, List<BackupConflictResponseError>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<BackupConflictResponseError>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = BackupConflictResponseError.listFromJson(entry.value, growable: growable,);
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

