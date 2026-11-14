//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PutNotesBackupRequest {
  /// Returns a new [PutNotesBackupRequest] instance.
  PutNotesBackupRequest({
    required this.expectedRevision,
    this.notes = const [],
  });

  /// Minimum value: 0
  int expectedRevision;

  List<BackupNote> notes;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PutNotesBackupRequest &&
    other.expectedRevision == expectedRevision &&
    _deepEquality.equals(other.notes, notes);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (expectedRevision.hashCode) +
    (notes.hashCode);

  @override
  String toString() => 'PutNotesBackupRequest[expectedRevision=$expectedRevision, notes=$notes]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'expected_revision'] = this.expectedRevision;
      json[r'notes'] = this.notes;
    return json;
  }

  /// Returns a new [PutNotesBackupRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PutNotesBackupRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'expected_revision'), 'Required key "PutNotesBackupRequest[expected_revision]" is missing from JSON.');
        assert(json[r'expected_revision'] != null, 'Required key "PutNotesBackupRequest[expected_revision]" has a null value in JSON.');
        assert(json.containsKey(r'notes'), 'Required key "PutNotesBackupRequest[notes]" is missing from JSON.');
        assert(json[r'notes'] != null, 'Required key "PutNotesBackupRequest[notes]" has a null value in JSON.');
        return true;
      }());

      return PutNotesBackupRequest(
        expectedRevision: mapValueOfType<int>(json, r'expected_revision')!,
        notes: BackupNote.listFromJson(json[r'notes']),
      );
    }
    return null;
  }

  static List<PutNotesBackupRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PutNotesBackupRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PutNotesBackupRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PutNotesBackupRequest> mapFromJson(dynamic json) {
    final map = <String, PutNotesBackupRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PutNotesBackupRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PutNotesBackupRequest-objects as value to a dart map
  static Map<String, List<PutNotesBackupRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PutNotesBackupRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PutNotesBackupRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'expected_revision',
    'notes',
  };
}

