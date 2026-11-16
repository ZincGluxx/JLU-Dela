//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PutTeachingBackupRequest {
  /// Returns a new [PutTeachingBackupRequest] instance.
  PutTeachingBackupRequest({
    required this.expectedRevision,
    required this.payload,
  });

  /// Minimum value: 0
  /// Maximum value: 2147483646
  int expectedRevision;

  TeachingBackupPayload payload;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PutTeachingBackupRequest &&
    other.expectedRevision == expectedRevision &&
    other.payload == payload;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (expectedRevision.hashCode) +
    (payload.hashCode);

  @override
  String toString() => 'PutTeachingBackupRequest[expectedRevision=$expectedRevision, payload=$payload]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'expected_revision'] = this.expectedRevision;
      json[r'payload'] = this.payload;
    return json;
  }

  /// Returns a new [PutTeachingBackupRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PutTeachingBackupRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'expected_revision'), 'Required key "PutTeachingBackupRequest[expected_revision]" is missing from JSON.');
        assert(json[r'expected_revision'] != null, 'Required key "PutTeachingBackupRequest[expected_revision]" has a null value in JSON.');
        assert(json.containsKey(r'payload'), 'Required key "PutTeachingBackupRequest[payload]" is missing from JSON.');
        assert(json[r'payload'] != null, 'Required key "PutTeachingBackupRequest[payload]" has a null value in JSON.');
        return true;
      }());

      return PutTeachingBackupRequest(
        expectedRevision: mapValueOfType<int>(json, r'expected_revision')!,
        payload: TeachingBackupPayload.fromJson(json[r'payload'])!,
      );
    }
    return null;
  }

  static List<PutTeachingBackupRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PutTeachingBackupRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PutTeachingBackupRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PutTeachingBackupRequest> mapFromJson(dynamic json) {
    final map = <String, PutTeachingBackupRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PutTeachingBackupRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PutTeachingBackupRequest-objects as value to a dart map
  static Map<String, List<PutTeachingBackupRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PutTeachingBackupRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PutTeachingBackupRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'expected_revision',
    'payload',
  };
}

