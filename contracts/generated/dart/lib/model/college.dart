//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class College {
  /// Returns a new [College] instance.
  College({
    required this.id,
    required this.name,
  });

  /// Stable college identifier assigned by the trusted server-side identity source, not a display name.
  String id;

  /// College display name from the trusted identity source.
  String name;

  @override
  bool operator ==(Object other) => identical(this, other) || other is College &&
    other.id == id &&
    other.name == name;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (name.hashCode);

  @override
  String toString() => 'College[id=$id, name=$name]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'name'] = this.name;
    return json;
  }

  /// Returns a new [College] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static College? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'id'), 'Required key "College[id]" is missing from JSON.');
        assert(json[r'id'] != null, 'Required key "College[id]" has a null value in JSON.');
        assert(json.containsKey(r'name'), 'Required key "College[name]" is missing from JSON.');
        assert(json[r'name'] != null, 'Required key "College[name]" has a null value in JSON.');
        return true;
      }());

      return College(
        id: mapValueOfType<String>(json, r'id')!,
        name: mapValueOfType<String>(json, r'name')!,
      );
    }
    return null;
  }

  static List<College> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <College>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = College.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, College> mapFromJson(dynamic json) {
    final map = <String, College>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = College.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of College-objects as value to a dart map
  static Map<String, List<College>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<College>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = College.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'name',
  };
}

