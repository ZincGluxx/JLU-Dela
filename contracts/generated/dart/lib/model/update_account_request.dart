//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class UpdateAccountRequest {
  /// Returns a new [UpdateAccountRequest] instance.
  UpdateAccountRequest({
    this.username = const Optional.absent(),
    this.displayName = const Optional.absent(),
    this.password = const Optional.absent(),
  });

  /// No trimming, lowercasing or other normalization.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Optional<String?> username;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Optional<String?> displayName;

  /// 8-16 Unicode scalar values including ASCII lowercase, uppercase and a digit. This rule applies only when setting a new account password.
  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  Optional<String?> password;

  @override
  bool operator ==(Object other) => identical(this, other) || other is UpdateAccountRequest &&
    other.username == username &&
    other.displayName == displayName &&
    other.password == password;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (username == null ? 0 : username!.hashCode) +
    (displayName == null ? 0 : displayName!.hashCode) +
    (password == null ? 0 : password!.hashCode);

  @override
  String toString() => 'UpdateAccountRequest[username=$username, displayName=$displayName, password=$password]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.username.isPresent) {
      final value = this.username.value;
      json[r'username'] = value;
    }
    if (this.displayName.isPresent) {
      final value = this.displayName.value;
      json[r'display_name'] = value;
    }
    if (this.password.isPresent) {
      final value = this.password.value;
      json[r'password'] = value;
    }
    return json;
  }

  /// Returns a new [UpdateAccountRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static UpdateAccountRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        return true;
      }());

      return UpdateAccountRequest(
        username: json.containsKey(r'username') ? Optional.present(mapValueOfType<String>(json, r'username')) : const Optional.absent(),
        displayName: json.containsKey(r'display_name') ? Optional.present(mapValueOfType<String>(json, r'display_name')) : const Optional.absent(),
        password: json.containsKey(r'password') ? Optional.present(mapValueOfType<String>(json, r'password')) : const Optional.absent(),
      );
    }
    return null;
  }

  static List<UpdateAccountRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <UpdateAccountRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = UpdateAccountRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, UpdateAccountRequest> mapFromJson(dynamic json) {
    final map = <String, UpdateAccountRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = UpdateAccountRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of UpdateAccountRequest-objects as value to a dart map
  static Map<String, List<UpdateAccountRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<UpdateAccountRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = UpdateAccountRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
  };
}

