//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class BackupReceipt {
  /// Returns a new [BackupReceipt] instance.
  BackupReceipt({
    required this.revision,
    required this.deleted,
    required this.updatedAt,
  });

  /// Minimum value: 1
  int revision;

  bool deleted;

  DateTime updatedAt;

  @override
  bool operator ==(Object other) => identical(this, other) || other is BackupReceipt &&
    other.revision == revision &&
    other.deleted == deleted &&
    other.updatedAt == updatedAt;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (revision.hashCode) +
    (deleted.hashCode) +
    (updatedAt.hashCode);

  @override
  String toString() => 'BackupReceipt[revision=$revision, deleted=$deleted, updatedAt=$updatedAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'revision'] = this.revision;
      json[r'deleted'] = this.deleted;
      json[r'updated_at'] = this.updatedAt.toUtc().toIso8601String();
    return json;
  }

  /// Returns a new [BackupReceipt] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static BackupReceipt? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'revision'), 'Required key "BackupReceipt[revision]" is missing from JSON.');
        assert(json[r'revision'] != null, 'Required key "BackupReceipt[revision]" has a null value in JSON.');
        assert(json.containsKey(r'deleted'), 'Required key "BackupReceipt[deleted]" is missing from JSON.');
        assert(json[r'deleted'] != null, 'Required key "BackupReceipt[deleted]" has a null value in JSON.');
        assert(json.containsKey(r'updated_at'), 'Required key "BackupReceipt[updated_at]" is missing from JSON.');
        assert(json[r'updated_at'] != null, 'Required key "BackupReceipt[updated_at]" has a null value in JSON.');
        return true;
      }());

      return BackupReceipt(
        revision: mapValueOfType<int>(json, r'revision')!,
        deleted: mapValueOfType<bool>(json, r'deleted')!,
        updatedAt: mapDateTime(json, r'updated_at', r'')!,
      );
    }
    return null;
  }

  static List<BackupReceipt> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <BackupReceipt>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = BackupReceipt.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, BackupReceipt> mapFromJson(dynamic json) {
    final map = <String, BackupReceipt>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = BackupReceipt.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of BackupReceipt-objects as value to a dart map
  static Map<String, List<BackupReceipt>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<BackupReceipt>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = BackupReceipt.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'revision',
    'deleted',
    'updated_at',
  };
}

