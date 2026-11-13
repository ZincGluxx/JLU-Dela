//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PhoneLoginRequest {
  /// Returns a new [PhoneLoginRequest] instance.
  PhoneLoginRequest({
    required this.phone,
    required this.smsCode,
  });

  /// Mainland China mobile number beginning 13-19, as 11 digits or with +86 prefix. The server trims surrounding whitespace and stores the +86 form.
  String phone;

  String smsCode;

  @override
  bool operator ==(Object other) => identical(this, other) || other is PhoneLoginRequest &&
    other.phone == phone &&
    other.smsCode == smsCode;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (phone.hashCode) +
    (smsCode.hashCode);

  @override
  String toString() => 'PhoneLoginRequest[phone=$phone, smsCode=$smsCode]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'phone'] = this.phone;
      json[r'sms_code'] = this.smsCode;
    return json;
  }

  /// Returns a new [PhoneLoginRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PhoneLoginRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'phone'), 'Required key "PhoneLoginRequest[phone]" is missing from JSON.');
        assert(json[r'phone'] != null, 'Required key "PhoneLoginRequest[phone]" has a null value in JSON.');
        assert(json.containsKey(r'sms_code'), 'Required key "PhoneLoginRequest[sms_code]" is missing from JSON.');
        assert(json[r'sms_code'] != null, 'Required key "PhoneLoginRequest[sms_code]" has a null value in JSON.');
        return true;
      }());

      return PhoneLoginRequest(
        phone: mapValueOfType<String>(json, r'phone')!,
        smsCode: mapValueOfType<String>(json, r'sms_code')!,
      );
    }
    return null;
  }

  static List<PhoneLoginRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <PhoneLoginRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PhoneLoginRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PhoneLoginRequest> mapFromJson(dynamic json) {
    final map = <String, PhoneLoginRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PhoneLoginRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PhoneLoginRequest-objects as value to a dart map
  static Map<String, List<PhoneLoginRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<PhoneLoginRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PhoneLoginRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'phone',
    'sms_code',
  };
}

