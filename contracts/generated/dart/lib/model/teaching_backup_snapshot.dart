//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TeachingBackupSnapshot {
  /// Returns a new [TeachingBackupSnapshot] instance.
  TeachingBackupSnapshot({
    required this.revision,
    required this.deleted,
    required this.payload,
    required this.updatedAt,
  });

  /// Minimum value: 0
  int revision;

  bool deleted;

  /// Null if absent or deleted; omitted partitions stay omitted in a stored payload.
  TeachingBackupPayload? payload;

  DateTime? updatedAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TeachingBackupSnapshot &&
    other.revision == revision &&
    other.deleted == deleted &&
    other.payload == payload &&
    other.updatedAt == updatedAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (revision.hashCode) +
    (deleted.hashCode) +
    (payload == null ? 0 : payload!.hashCode) +
    (updatedAt == null ? 0 : updatedAt!.hashCode);

  @override
  String toString() => 'TeachingBackupSnapshot[revision=$revision, deleted=$deleted, payload=$payload, updatedAt=$updatedAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'revision'] = this.revision;
      json[r'deleted'] = this.deleted;
    if (this.payload != null) {
      json[r'payload'] = this.payload;
    } else {
      json[r'payload'] = null;
    }
    if (this.updatedAt != null) {
      json[r'updated_at'] = this.updatedAt!.toUtc().toIso8601String();
    } else {
      json[r'updated_at'] = null;
    }
    return json;
  }

  /// Returns a new [TeachingBackupSnapshot] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TeachingBackupSnapshot? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'revision'), 'Required key "TeachingBackupSnapshot[revision]" is missing from JSON.');
        assert(json[r'revision'] != null, 'Required key "TeachingBackupSnapshot[revision]" has a null value in JSON.');
        assert(json.containsKey(r'deleted'), 'Required key "TeachingBackupSnapshot[deleted]" is missing from JSON.');
        assert(json[r'deleted'] != null, 'Required key "TeachingBackupSnapshot[deleted]" has a null value in JSON.');
        assert(json.containsKey(r'payload'), 'Required key "TeachingBackupSnapshot[payload]" is missing from JSON.');
        assert(json.containsKey(r'updated_at'), 'Required key "TeachingBackupSnapshot[updated_at]" is missing from JSON.');
        return true;
      }());

      return TeachingBackupSnapshot(
        revision: mapValueOfType<int>(json, r'revision')!,
        deleted: mapValueOfType<bool>(json, r'deleted')!,
        payload: TeachingBackupPayload.fromJson(json[r'payload']),
        updatedAt: mapDateTime(json, r'updated_at', r''),
      );
    }
    return null;
  }

  static List<TeachingBackupSnapshot> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <TeachingBackupSnapshot>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TeachingBackupSnapshot.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TeachingBackupSnapshot> mapFromJson(dynamic json) {
    final map = <String, TeachingBackupSnapshot>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TeachingBackupSnapshot.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TeachingBackupSnapshot-objects as value to a dart map
  static Map<String, List<TeachingBackupSnapshot>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<TeachingBackupSnapshot>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TeachingBackupSnapshot.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'revision',
    'deleted',
    'payload',
    'updated_at',
  };
}

