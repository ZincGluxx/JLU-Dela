//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PhoneCode {
  /// Returns a new [PhoneCode] instance.
  PhoneCode({
    required this.expiresIn,
    required this.retryAfter,
    this.devMode = const Optional.present(false),
  });

  /// Minimum value: 1
  int expiresIn;

  /// Minimum value: 1
  int retryAfter;

  /// True only for explicit local debug fixed-code mode. No SMS was sent. Missing in older responses means false.
  Optional<bool?> devMode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PhoneCode &&
    other.expiresIn == expiresIn &&
    other.retryAfter == retryAfter &&
    other.devMode == devMode;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (expiresIn.hashCode) +
    (retryAfter.hashCode) +
    (devMode.hashCode);

  @override
  String toString() => 'PhoneCode[expiresIn=$expiresIn, retryAfter=$retryAfter, devMode=$devMode]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'expires_in'] = this.expiresIn;
      json[r'retry_after'] = this.retryAfter;
    if (this.devMode.isPresent) {
      final value = this.devMode.value;
      json[r'dev_mode'] = value;
    }
    return json;
  }

  /// Returns a new [PhoneCode] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PhoneCode? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'expires_in'), 'Required key "PhoneCode[expires_in]" is missing from JSON.');
        assert(json[r'expires_in'] != null, 'Required key "PhoneCode[expires_in]" has a null value in JSON.');
        assert(json.containsKey(r'retry_after'), 'Required key "PhoneCode[retry_after]" is missing from JSON.');
        assert(json[r'retry_after'] != null, 'Required key "PhoneCode[retry_after]" has a null value in JSON.');
        return true;
      }());

      return PhoneCode(
        expiresIn: mapValueOfType<int>(json, r'expires_in')!,
        retryAfter: mapValueOfType<int>(json, r'retry_after')!,
        devMode: json.containsKey(r'dev_mode') ? Optional.present(mapValueOfType<bool>(json, r'dev_mode')) : const Optional.absent(),
      );
    }
    return null;
  }

  static List<PhoneCode> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PhoneCode>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PhoneCode.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PhoneCode> mapFromJson(dynamic json) {
    final map = <String, PhoneCode>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PhoneCode.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PhoneCode-objects as value to a dart map
  static Map<String, List<PhoneCode>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PhoneCode>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PhoneCode.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'expires_in',
    'retry_after',
  };
}

