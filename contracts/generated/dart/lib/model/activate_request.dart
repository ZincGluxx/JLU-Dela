//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ActivateRequest {
  /// Returns a new [ActivateRequest] instance.
  ActivateRequest({
    required this.inviteToken,
    required this.password,
  });

  /// One-time invitation token supplied by the operator, prefixed `inv_`. It is not a session token and clients must not log it. 
  String inviteToken;

  /// New password, measured in Unicode code points. There is no character-class requirement, but it must differ from the invitation's login. The client and the server never log it. 
  String password;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ActivateRequest &&
    other.inviteToken == inviteToken &&
    other.password == password;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (inviteToken.hashCode) +
    (password.hashCode);

  @override
  String toString() => 'ActivateRequest[inviteToken=$inviteToken, password=$password]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'invite_token'] = this.inviteToken;
      json[r'password'] = this.password;
    return json;
  }

  /// Returns a new [ActivateRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ActivateRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'invite_token'), 'Required key "ActivateRequest[invite_token]" is missing from JSON.');
        assert(json[r'invite_token'] != null, 'Required key "ActivateRequest[invite_token]" has a null value in JSON.');
        assert(json.containsKey(r'password'), 'Required key "ActivateRequest[password]" is missing from JSON.');
        assert(json[r'password'] != null, 'Required key "ActivateRequest[password]" has a null value in JSON.');
        return true;
      }());

      return ActivateRequest(
        inviteToken: mapValueOfType<String>(json, r'invite_token')!,
        password: mapValueOfType<String>(json, r'password')!,
      );
    }
    return null;
  }

  static List<ActivateRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ActivateRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ActivateRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ActivateRequest> mapFromJson(dynamic json) {
    final map = <String, ActivateRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ActivateRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ActivateRequest-objects as value to a dart map
  static Map<String, List<ActivateRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ActivateRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ActivateRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'invite_token',
    'password',
  };
}

