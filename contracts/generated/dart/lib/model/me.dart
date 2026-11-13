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
    this.username = const Optional.absent(),
    this.passwordSet = const Optional.present(false),
    required this.displayName,
    required this.timezone,
    required this.studentVerified,
    required this.college,
  });

  /// Workbench user id derived from the server-side session.
  String id;

  /// Account username, or null before it is set. May be absent in older responses.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Optional<String?> username;

  /// Whether the account has a password. Older responses default to false.
  Optional<bool?> passwordSet;

  String displayName;

  /// IANA timezone used for campus display dates. Campus dates remain Asia/Shanghai in this contract.
  String timezone;

  /// Records that the server checked an official Jilin University student report. Not proof of current enrollment, report ownership or one student per account. No automatic expiry or enrollment restriction. Phone login and source connections do not grant this status; clients cannot submit a status value. Unrecognized report HTML fails closed.
  bool studentVerified;

  College? college;

  @override
  bool operator ==(Object other) => identical(this, other) || other is Me &&
    other.id == id &&
    other.username == username &&
    other.passwordSet == passwordSet &&
    other.displayName == displayName &&
    other.timezone == timezone &&
    other.studentVerified == studentVerified &&
    other.college == college;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (id.hashCode) +
    (username == null ? 0 : username!.hashCode) +
    (passwordSet.hashCode) +
    (displayName.hashCode) +
    (timezone.hashCode) +
    (studentVerified.hashCode) +
    (college == null ? 0 : college!.hashCode);

  @override
  String toString() => 'Me[id=$id, username=$username, passwordSet=$passwordSet, displayName=$displayName, timezone=$timezone, studentVerified=$studentVerified, college=$college]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'id'] = this.id;
    if (this.username.isPresent) {
      final value = this.username.value;
      json[r'username'] = value;
    }
    if (this.passwordSet.isPresent) {
      final value = this.passwordSet.value;
      json[r'password_set'] = value;
    }
      json[r'display_name'] = this.displayName;
      json[r'timezone'] = this.timezone;
      json[r'student_verified'] = this.studentVerified;
    if (this.college != null) {
      json[r'college'] = this.college;
    } else {
      json[r'college'] = null;
    }
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
        assert(json.containsKey(r'student_verified'), 'Required key "Me[student_verified]" is missing from JSON.');
        assert(json[r'student_verified'] != null, 'Required key "Me[student_verified]" has a null value in JSON.');
        assert(json.containsKey(r'college'), 'Required key "Me[college]" is missing from JSON.');
        return true;
      }());

      return Me(
        id: mapValueOfType<String>(json, r'id')!,
        username: json.containsKey(r'username') ? Optional.present(mapValueOfType<String>(json, r'username')) : const Optional.absent(),
        passwordSet: json.containsKey(r'password_set') ? Optional.present(mapValueOfType<bool>(json, r'password_set')) : const Optional.absent(),
        displayName: mapValueOfType<String>(json, r'display_name')!,
        timezone: mapValueOfType<String>(json, r'timezone')!,
        studentVerified: mapValueOfType<bool>(json, r'student_verified')!,
        college: College.fromJson(json[r'college']),
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
    'student_verified',
    'college',
  };
}

