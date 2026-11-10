//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class RequestIdMeta {
  /// Returns a new [RequestIdMeta] instance.
  RequestIdMeta({
    required this.requestId,
  });

  /// Identifier shared by the response body and the server log entry.
  String requestId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is RequestIdMeta &&
    other.requestId == requestId;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (requestId.hashCode);

  @override
  String toString() => 'RequestIdMeta[requestId=$requestId]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'request_id'] = this.requestId;
    return json;
  }

  /// Returns a new [RequestIdMeta] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static RequestIdMeta? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'request_id'), 'Required key "RequestIdMeta[request_id]" is missing from JSON.');
        assert(json[r'request_id'] != null, 'Required key "RequestIdMeta[request_id]" has a null value in JSON.');
        return true;
      }());

      return RequestIdMeta(
        requestId: mapValueOfType<String>(json, r'request_id')!,
      );
    }
    return null;
  }

  static List<RequestIdMeta> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <RequestIdMeta>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = RequestIdMeta.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, RequestIdMeta> mapFromJson(dynamic json) {
    final map = <String, RequestIdMeta>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = RequestIdMeta.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of RequestIdMeta-objects as value to a dart map
  static Map<String, List<RequestIdMeta>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<RequestIdMeta>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = RequestIdMeta.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'request_id',
  };
}

