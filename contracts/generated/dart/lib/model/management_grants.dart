//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ManagementGrants {
  /// Returns a new [ManagementGrants] instance.
  ManagementGrants({
    required this.campus,
    this.collegeIds = const {},
  });

  /// Whether the maintainer assigned campus-wide management.
  bool campus;

  /// Exact trusted college IDs explicitly assigned by a maintainer, even when campus is true.
  Set<String> collegeIds;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ManagementGrants &&
    other.campus == campus &&
    _deepEquality.equals(other.collegeIds, collegeIds);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (campus.hashCode) +
    (collegeIds.hashCode);

  @override
  String toString() => 'ManagementGrants[campus=$campus, collegeIds=$collegeIds]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'campus'] = this.campus;
      json[r'college_ids'] = this.collegeIds.toList(growable: false);
    return json;
  }

  /// Returns a new [ManagementGrants] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ManagementGrants? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'campus'), 'Required key "ManagementGrants[campus]" is missing from JSON.');
        assert(json[r'campus'] != null, 'Required key "ManagementGrants[campus]" has a null value in JSON.');
        assert(json.containsKey(r'college_ids'), 'Required key "ManagementGrants[college_ids]" is missing from JSON.');
        assert(json[r'college_ids'] != null, 'Required key "ManagementGrants[college_ids]" has a null value in JSON.');
        return true;
      }());

      return ManagementGrants(
        campus: mapValueOfType<bool>(json, r'campus')!,
        collegeIds: json[r'college_ids'] is Iterable
            ? (json[r'college_ids'] as Iterable).cast<String>().toSet()
            : const {},
      );
    }
    return null;
  }

  static List<ManagementGrants> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ManagementGrants>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ManagementGrants.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ManagementGrants> mapFromJson(dynamic json) {
    final map = <String, ManagementGrants>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ManagementGrants.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ManagementGrants-objects as value to a dart map
  static Map<String, List<ManagementGrants>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ManagementGrants>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ManagementGrants.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'campus',
    'college_ids',
  };
}

