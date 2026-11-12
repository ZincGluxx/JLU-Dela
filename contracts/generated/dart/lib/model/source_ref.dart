//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SourceRef {
  /// Returns a new [SourceRef] instance.
  SourceRef({
    required this.source_,
    required this.sourceId,
    required this.sourceScope,
  });

  TeachingSource source_;

  /// Original source identifier preserved as a string.
  String sourceId;

  /// Source-defined scope that disambiguates the original identifier; draft string representation pending source review.
  String sourceScope;

  @override
  bool operator ==(Object other) => identical(this, other) || other is SourceRef &&
    other.source_ == source_ &&
    other.sourceId == sourceId &&
    other.sourceScope == sourceScope;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (source_.hashCode) +
    (sourceId.hashCode) +
    (sourceScope.hashCode);

  @override
  String toString() => 'SourceRef[source_=$source_, sourceId=$sourceId, sourceScope=$sourceScope]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'source'] = this.source_;
      json[r'source_id'] = this.sourceId;
      json[r'source_scope'] = this.sourceScope;
    return json;
  }

  /// Returns a new [SourceRef] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SourceRef? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'source'), 'Required key "SourceRef[source]" is missing from JSON.');
        assert(json[r'source'] != null, 'Required key "SourceRef[source]" has a null value in JSON.');
        assert(json.containsKey(r'source_id'), 'Required key "SourceRef[source_id]" is missing from JSON.');
        assert(json[r'source_id'] != null, 'Required key "SourceRef[source_id]" has a null value in JSON.');
        assert(json.containsKey(r'source_scope'), 'Required key "SourceRef[source_scope]" is missing from JSON.');
        assert(json[r'source_scope'] != null, 'Required key "SourceRef[source_scope]" has a null value in JSON.');
        return true;
      }());

      return SourceRef(
        source_: TeachingSource.fromJson(json[r'source'])!,
        sourceId: mapValueOfType<String>(json, r'source_id')!,
        sourceScope: mapValueOfType<String>(json, r'source_scope')!,
      );
    }
    return null;
  }

  static List<SourceRef> listFromJson(dynamic json, {bool growable = false,}) {
    final result = <SourceRef>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SourceRef.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SourceRef> mapFromJson(dynamic json) {
    final map = <String, SourceRef>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SourceRef.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SourceRef-objects as value to a dart map
  static Map<String, List<SourceRef>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<SourceRef>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SourceRef.listFromJson(entry.value, growable: growable,);
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'source',
    'source_id',
    'source_scope',
  };
}

