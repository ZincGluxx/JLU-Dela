//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class Me {
  /// Returns a new [Me] instance.
  Me({
    required this.id,
    required this.displayName,
    required this.timezone,
  });

  /// Workbench user id derived from the server-side session.
  String id;

  String displayName;

  /// IANA timezone used for campus display dates. Campus dates remain Asia/Shanghai in this contract.
  String timezone;

  @override
  bool operator ==(Object other) => identical(this, other) || other is Me &&
    other.id == id &&
    other.displayName == displayName &&
    other.timezone == timezone;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (displayName.hashCode) +
    (timezone.hashCode);

  @override
  String toString() => 'Me[id=$id, displayName=$displayName, timezone=$timezone]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
      json[r'display_name'] = this.displayName;
      json[r'timezone'] = this.timezone;
    return json;
  }

  /// Returns a new [Me] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static Me? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'id'), 'Required key "Me[id]" is missing from JSON.');
        assert(json[r'id'] != null, 'Required key "Me[id]" has a null value in JSON.');
        assert(json.containsKey(r'display_name'), 'Required key "Me[display_name]" is missing from JSON.');
        assert(json[r'display_name'] != null, 'Required key "Me[display_name]" has a null value in JSON.');
        assert(json.containsKey(r'timezone'), 'Required key "Me[timezone]" is missing from JSON.');
        assert(json[r'timezone'] != null, 'Required key "Me[timezone]" has a null value in JSON.');
        return true;
      }());

      return Me(
        id: mapValueOfType<String>(json, r'id')!,
        displayName: mapValueOfType<String>(json, r'display_name')!,
        timezone: mapValueOfType<String>(json, r'timezone')!,
      );
    }
    return null;
  }

  static List<Me> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <Me>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Me.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, Me> mapFromJson(dynamic json) {
    final map = <String, Me>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = Me.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of Me-objects as value to a dart map
  static Map<String, List<Me>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<Me>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = Me.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'id',
    'display_name',
    'timezone',
  };
}

