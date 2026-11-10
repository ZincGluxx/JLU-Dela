//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ServiceMeta {
  /// Returns a new [ServiceMeta] instance.
  ServiceMeta({
    required this.service,
    required this.version,
    required this.apiVersion,
    required this.buildId,
  });

  String service;

  /// Server release version.
  String version;

  String apiVersion;

  /// Deployment build or commit identifier.
  String buildId;

  @override
  bool operator ==(Object other) => identical(this, other) || other is ServiceMeta &&
    other.service == service &&
    other.version == version &&
    other.apiVersion == apiVersion &&
    other.buildId == buildId;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (service.hashCode) +
    (version.hashCode) +
    (apiVersion.hashCode) +
    (buildId.hashCode);

  @override
  String toString() => 'ServiceMeta[service=$service, version=$version, apiVersion=$apiVersion, buildId=$buildId]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'service'] = this.service;
      json[r'version'] = this.version;
      json[r'api_version'] = this.apiVersion;
      json[r'build_id'] = this.buildId;
    return json;
  }

  /// Returns a new [ServiceMeta] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ServiceMeta? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'service'), 'Required key "ServiceMeta[service]" is missing from JSON.');
        assert(json[r'service'] != null, 'Required key "ServiceMeta[service]" has a null value in JSON.');
        assert(json.containsKey(r'version'), 'Required key "ServiceMeta[version]" is missing from JSON.');
        assert(json[r'version'] != null, 'Required key "ServiceMeta[version]" has a null value in JSON.');
        assert(json.containsKey(r'api_version'), 'Required key "ServiceMeta[api_version]" is missing from JSON.');
        assert(json[r'api_version'] != null, 'Required key "ServiceMeta[api_version]" has a null value in JSON.');
        assert(json.containsKey(r'build_id'), 'Required key "ServiceMeta[build_id]" is missing from JSON.');
        assert(json[r'build_id'] != null, 'Required key "ServiceMeta[build_id]" has a null value in JSON.');
        return true;
      }());

      return ServiceMeta(
        service: mapValueOfType<String>(json, r'service')!,
        version: mapValueOfType<String>(json, r'version')!,
        apiVersion: mapValueOfType<String>(json, r'api_version')!,
        buildId: mapValueOfType<String>(json, r'build_id')!,
      );
    }
    return null;
  }

  static List<ServiceMeta> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <ServiceMeta>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ServiceMeta.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ServiceMeta> mapFromJson(dynamic json) {
    final map = <String, ServiceMeta>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ServiceMeta.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ServiceMeta-objects as value to a dart map
  static Map<String, List<ServiceMeta>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<ServiceMeta>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ServiceMeta.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'service',
    'version',
    'api_version',
    'build_id',
  };
}

