//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class BackupSnapshot {
  /// Returns a new [BackupSnapshot] instance.
  BackupSnapshot({
    required this.revision,
    required this.deleted,
    this.notes = const [],
    required this.updatedAt,
  });

  /// Minimum value: 0
  int revision;

  bool deleted;

  List<BackupNote> notes;

  DateTime? updatedAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is BackupSnapshot &&
    other.revision == revision &&
    other.deleted == deleted &&
    _deepEquality.equals(other.notes, notes) &&
    other.updatedAt == updatedAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (revision.hashCode) +
    (deleted.hashCode) +
    (notes.hashCode) +
    (updatedAt == null ? 0 : updatedAt!.hashCode);

  @override
  String toString() => 'BackupSnapshot[revision=$revision, deleted=$deleted, notes=$notes, updatedAt=$updatedAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'revision'] = this.revision;
      json[r'deleted'] = this.deleted;
      json[r'notes'] = this.notes;
    if (this.updatedAt != null) {
      json[r'updated_at'] = this.updatedAt!.toUtc().toIso8601String();
    } else {
      json[r'updated_at'] = null;
    }
    return json;
  }

  /// Returns a new [BackupSnapshot] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static BackupSnapshot? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'revision'), 'Required key "BackupSnapshot[revision]" is missing from JSON.');
        assert(json[r'revision'] != null, 'Required key "BackupSnapshot[revision]" has a null value in JSON.');
        assert(json.containsKey(r'deleted'), 'Required key "BackupSnapshot[deleted]" is missing from JSON.');
        assert(json[r'deleted'] != null, 'Required key "BackupSnapshot[deleted]" has a null value in JSON.');
        assert(json.containsKey(r'notes'), 'Required key "BackupSnapshot[notes]" is missing from JSON.');
        assert(json[r'notes'] != null, 'Required key "BackupSnapshot[notes]" has a null value in JSON.');
        assert(json.containsKey(r'updated_at'), 'Required key "BackupSnapshot[updated_at]" is missing from JSON.');
        return true;
      }());

      return BackupSnapshot(
        revision: mapValueOfType<int>(json, r'revision')!,
        deleted: mapValueOfType<bool>(json, r'deleted')!,
        notes: BackupNote.listFromJson(json[r'notes']),
        updatedAt: mapDateTime(json, r'updated_at', r''),
      );
    }
    return null;
  }

  static List<BackupSnapshot> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <BackupSnapshot>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = BackupSnapshot.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, BackupSnapshot> mapFromJson(dynamic json) {
    final map = <String, BackupSnapshot>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = BackupSnapshot.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of BackupSnapshot-objects as value to a dart map
  static Map<String, List<BackupSnapshot>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<BackupSnapshot>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = BackupSnapshot.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'revision',
    'deleted',
    'notes',
    'updated_at',
  };
}

