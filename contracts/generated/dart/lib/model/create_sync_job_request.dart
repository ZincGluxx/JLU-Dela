//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CreateSyncJobRequest {
  /// Returns a new [CreateSyncJobRequest] instance.
  CreateSyncJobRequest({
    required this.source_,
    required this.resource,
    this.scope = const {},
  });

  String source_;

  String resource;

  /// Source-defined cache dataset. At most 4096 bytes when serialized. It must identify a snapshot (for example a semester id), not a client query window; do not put from/to paging values here. 
  Map<String, Object> scope;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CreateSyncJobRequest &&
    other.source_ == source_ &&
    other.resource == resource &&
    _deepEquality.equals(other.scope, scope);

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (source_.hashCode) +
    (resource.hashCode) +
    (scope.hashCode);

  @override
  String toString() => 'CreateSyncJobRequest[source_=$source_, resource=$resource, scope=$scope]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'source'] = this.source_;
      json[r'resource'] = this.resource;
      json[r'scope'] = this.scope;
    return json;
  }

  /// Returns a new [CreateSyncJobRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CreateSyncJobRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'source'), 'Required key "CreateSyncJobRequest[source]" is missing from JSON.');
        assert(json[r'source'] != null, 'Required key "CreateSyncJobRequest[source]" has a null value in JSON.');
        assert(json.containsKey(r'resource'), 'Required key "CreateSyncJobRequest[resource]" is missing from JSON.');
        assert(json[r'resource'] != null, 'Required key "CreateSyncJobRequest[resource]" has a null value in JSON.');
        assert(json.containsKey(r'scope'), 'Required key "CreateSyncJobRequest[scope]" is missing from JSON.');
        assert(json[r'scope'] != null, 'Required key "CreateSyncJobRequest[scope]" has a null value in JSON.');
        return true;
      }());

      return CreateSyncJobRequest(
        source_: mapValueOfType<String>(json, r'source')!,
        resource: mapValueOfType<String>(json, r'resource')!,
        scope: mapCastOfType<String, Object>(json, r'scope')!,
      );
    }
    return null;
  }

  static List<CreateSyncJobRequest> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CreateSyncJobRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CreateSyncJobRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CreateSyncJobRequest> mapFromJson(dynamic json) {
    final map = <String, CreateSyncJobRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CreateSyncJobRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CreateSyncJobRequest-objects as value to a dart map
  static Map<String, List<CreateSyncJobRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CreateSyncJobRequest>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CreateSyncJobRequest.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'source',
    'resource',
    'scope',
  };
}

