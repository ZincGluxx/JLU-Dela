//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class RevisionConflictDetail {
  /// Returns a new [RevisionConflictDetail] instance.
  RevisionConflictDetail({
    required this.code,
    required this.message,
    required this.requestId,
    required this.retryable,
    this.fields = const [],
    required this.current,
  });

  /// Stable machine-readable error code. Clients must handle unknown values safely.
  String code;

  /// Human-readable technical message. Clients may localize by code.
  String message;

  String requestId;

  /// Whether a later retry may succeed without user action.
  bool retryable;

  List<ErrorField> fields;

  /// The server's current version, so the client can show it and let the user decide.
  Todo current;

  @override
  bool operator ==(Object other) => identical(this, other) || other is RevisionConflictDetail &&
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
    (current.hashCode);

  @override
  String toString() => 'RevisionConflictDetail[code=$code, message=$message, requestId=$requestId, retryable=$retryable, fields=$fields, current=$current]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'code'] = this.code;
      json[r'message'] = this.message;
      json[r'request_id'] = this.requestId;
      json[r'retryable'] = this.retryable;
      json[r'fields'] = this.fields;
      json[r'current'] = this.current;
    return json;
  }

  /// Returns a new [RevisionConflictDetail] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static RevisionConflictDetail? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'code'), 'Required key "RevisionConflictDetail[code]" is missing from JSON.');
        assert(json[r'code'] != null, 'Required key "RevisionConflictDetail[code]" has a null value in JSON.');
        assert(json.containsKey(r'message'), 'Required key "RevisionConflictDetail[message]" is missing from JSON.');
        assert(json[r'message'] != null, 'Required key "RevisionConflictDetail[message]" has a null value in JSON.');
        assert(json.containsKey(r'request_id'), 'Required key "RevisionConflictDetail[request_id]" is missing from JSON.');
        assert(json[r'request_id'] != null, 'Required key "RevisionConflictDetail[request_id]" has a null value in JSON.');
        assert(json.containsKey(r'retryable'), 'Required key "RevisionConflictDetail[retryable]" is missing from JSON.');
        assert(json[r'retryable'] != null, 'Required key "RevisionConflictDetail[retryable]" has a null value in JSON.');
        assert(json.containsKey(r'fields'), 'Required key "RevisionConflictDetail[fields]" is missing from JSON.');
        assert(json[r'fields'] != null, 'Required key "RevisionConflictDetail[fields]" has a null value in JSON.');
        assert(json.containsKey(r'current'), 'Required key "RevisionConflictDetail[current]" is missing from JSON.');
        assert(json[r'current'] != null, 'Required key "RevisionConflictDetail[current]" has a null value in JSON.');
        return true;
      }());

      return RevisionConflictDetail(
        code: mapValueOfType<String>(json, r'code')!,
        message: mapValueOfType<String>(json, r'message')!,
        requestId: mapValueOfType<String>(json, r'request_id')!,
        retryable: mapValueOfType<bool>(json, r'retryable')!,
        fields: ErrorField.listFromJson(json[r'fields']),
        current: Todo.fromJson(json[r'current'])!,
      );
    }
    return null;
  }

  static List<RevisionConflictDetail> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RevisionConflictDetail>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RevisionConflictDetail.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, RevisionConflictDetail> mapFromJson(dynamic json) {
    final map = <String, RevisionConflictDetail>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = RevisionConflictDetail.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of RevisionConflictDetail-objects as value to a dart map
  static Map<String, List<RevisionConflictDetail>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<RevisionConflictDetail>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = RevisionConflictDetail.listFromJson(entry.value, growable: growable,);
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
    'current',
  };
}

